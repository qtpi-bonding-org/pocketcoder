/*
PocketCoder: An accessible, secure, and user-friendly open-source coding assistant platform.
Copyright (C) 2026 Qtpi Bonding LLC

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

// @pocketcoder-core: Skills API. Pure ACP passthrough for Goose's
// _goose/unstable/sources/* (type: "skill") — see
// docs/superpowers/specs/2026-07-23-skills-ui-design.md. No PocketBase
// schema; PocketBase never stores a skill, only proxies requests to Goose.
package api

import (
	"context"
	"encoding/json"
	"fmt"
	"sort"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/acp"

	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/coordinator"
)

// sourceScopeParam mirrors Goose's SourceScope discriminated union
// (acp-schema.json) — {"scope":"global"} or
// {"scope":"projectDir","projectDir":"<path>"}. Sent by Flutter verbatim
// (see the design spec's Component 1) and passed through as-is into
// CreateSourceRequest_unstable.target.
type sourceScopeParam struct {
	Scope      string `json:"scope"`
	ProjectDir string `json:"projectDir,omitempty"`
}

// createSourceParams mirrors CreateSourceRequest_unstable (acp-schema.json),
// required ["type","name","description","content","target"].
type createSourceParams struct {
	Type        string           `json:"type"`
	Name        string           `json:"name"`
	Description string           `json:"description"`
	Content     string           `json:"content"`
	Target      sourceScopeParam `json:"target"`
}

// updateSourceParams mirrors UpdateSourceRequest_unstable, required
// ["type","path","name","description","content"] — path-identified, no
// scope-change field (Goose has no "move a skill between scopes" op).
type updateSourceParams struct {
	Type        string `json:"type"`
	Path        string `json:"path"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Content     string `json:"content"`
}

// deleteSourceParams mirrors DeleteSourceRequest_unstable, required
// ["type","path"].
type deleteSourceParams struct {
	Type string `json:"type"`
	Path string `json:"path"`
}

// listSourcesParams mirrors ListSourcesRequest_unstable's fields this
// design actually uses. projectDir (not includeProjectSources) is what
// surfaces project-scoped skills — see Task 2.
type listSourcesParams struct {
	Type       string `json:"type"`
	ProjectDir string `json:"projectDir,omitempty"`
}

// sourceEntryResp mirrors the subset of SourceEntry (acp-schema.json) this
// design uses: name/description/content/path/global. properties,
// supportingFiles, and writable are deliberately not modeled — see the
// design spec's Component 4 for why each is dropped.
type sourceEntryResp struct {
	Name        string `json:"name"`
	Description string `json:"description"`
	Content     string `json:"content"`
	Path        string `json:"path"`
	Global      bool   `json:"global"`
}

type createSourceResponse struct {
	Source sourceEntryResp `json:"source"`
}

type updateSourceResponse struct {
	Source sourceEntryResp `json:"source"`
}

type listSourcesResponse struct {
	Sources []sourceEntryResp `json:"sources"`
}

// createSkillRequest is the HTTP body shape for POST
// /api/pocketcoder/skills/create.
type createSkillRequest struct {
	Name        string           `json:"name"`
	Description string           `json:"description"`
	Content     string           `json:"content"`
	Scope       sourceScopeParam `json:"scope"`
}

// buildCreateSkillParams validates a createSkillRequest and maps it onto
// createSourceParams (type always "skill"). Returns an error describing
// the first missing/invalid field, suitable for a 400 response.
func buildCreateSkillParams(in createSkillRequest) (createSourceParams, error) {
	if in.Name == "" {
		return createSourceParams{}, fmt.Errorf("name is required")
	}
	if in.Description == "" {
		return createSourceParams{}, fmt.Errorf("description is required")
	}
	if in.Content == "" {
		return createSourceParams{}, fmt.Errorf("content is required")
	}
	switch in.Scope.Scope {
	case "global":
	case "projectDir":
		if in.Scope.ProjectDir == "" {
			return createSourceParams{}, fmt.Errorf("scope.projectDir is required when scope.scope is \"projectDir\"")
		}
	default:
		return createSourceParams{}, fmt.Errorf("scope.scope must be \"global\" or \"projectDir\", got %q", in.Scope.Scope)
	}
	return createSourceParams{
		Type:        "skill",
		Name:        in.Name,
		Description: in.Description,
		Content:     in.Content,
		Target:      in.Scope,
	}, nil
}

// requireAdmin checks that the request is authenticated with the admin
// role. Unlike every other role-gated route in this codebase (mcp.go,
// ssh.go, cron.go — all agent-or-admin, since Goose itself calls those),
// this is the first admin-only route: nothing here is ever invoked by
// Goose, only by a human through Flutter.
func requireAdmin(re *core.RequestEvent) error {
	if re.Auth == nil {
		return re.JSON(401, map[string]string{"error": "Authentication required"})
	}
	if re.Auth.GetString("role") != "admin" {
		return re.JSON(403, map[string]string{"error": "Insufficient permissions"})
	}
	return nil
}

// RegisterSkillsApi registers the skills CRUD endpoints. Every handler
// opens a fresh AdminConn per request (dial, call, close — never a
// standing connection, matching AdminConn's documented lifetime) and
// forwards to Goose's _goose/unstable/sources/* methods. PocketBase never
// stores a skill; it only proxies.
//
// The `list` route is deliberately not registered here — it depends on
// `handleSkillsList`/`listSkills`, added in Task 2 along with the rest of
// this function's body. Task 1 alone must compile and pass its own tests,
// so it only wires up create/update/delete.
func RegisterSkillsApi(app *pocketbase.PocketBase, e *core.ServeEvent, coord func() *coordinator.Coordinator) {
	e.Router.POST("/api/pocketcoder/skills/list", func(re *core.RequestEvent) error {
		if err := requireAdmin(re); err != nil {
			return err
		}
		return handleSkillsList(re, app, coord)
	}).Bind(apis.RequireAuth())

	e.Router.POST("/api/pocketcoder/skills/create", func(re *core.RequestEvent) error {
		if err := requireAdmin(re); err != nil {
			return err
		}
		var input createSkillRequest
		if err := re.BindBody(&input); err != nil {
			return re.JSON(400, map[string]string{"error": "Invalid request body"})
		}
		params, err := buildCreateSkillParams(input)
		if err != nil {
			return re.JSON(400, map[string]string{"error": err.Error()})
		}

		conn, err := dialAdmin(re, coord)
		if err != nil {
			return err
		}
		defer conn.Close()

		raw, err := conn.CallExtension(re.Request.Context(), "_goose/unstable/sources/create", params)
		if err != nil {
			return re.JSON(502, map[string]string{"error": fmt.Sprintf("goose sources/create failed: %v", err)})
		}
		var resp createSourceResponse
		if err := json.Unmarshal(raw, &resp); err != nil {
			return re.JSON(502, map[string]string{"error": "failed to parse goose response"})
		}
		return re.JSON(200, resp.Source)
	}).Bind(apis.RequireAuth())

	e.Router.POST("/api/pocketcoder/skills/update", func(re *core.RequestEvent) error {
		if err := requireAdmin(re); err != nil {
			return err
		}
		var input struct {
			Path        string `json:"path"`
			Name        string `json:"name"`
			Description string `json:"description"`
			Content     string `json:"content"`
		}
		if err := re.BindBody(&input); err != nil {
			return re.JSON(400, map[string]string{"error": "Invalid request body"})
		}
		if input.Path == "" || input.Name == "" || input.Description == "" || input.Content == "" {
			return re.JSON(400, map[string]string{"error": "path, name, description, and content are required"})
		}

		conn, err := dialAdmin(re, coord)
		if err != nil {
			return err
		}
		defer conn.Close()

		params := updateSourceParams{
			Type: "skill", Path: input.Path, Name: input.Name,
			Description: input.Description, Content: input.Content,
		}
		raw, err := conn.CallExtension(re.Request.Context(), "_goose/unstable/sources/update", params)
		if err != nil {
			return re.JSON(502, map[string]string{"error": fmt.Sprintf("goose sources/update failed: %v", err)})
		}
		var resp updateSourceResponse
		if err := json.Unmarshal(raw, &resp); err != nil {
			return re.JSON(502, map[string]string{"error": "failed to parse goose response"})
		}
		return re.JSON(200, resp.Source)
	}).Bind(apis.RequireAuth())

	e.Router.POST("/api/pocketcoder/skills/delete", func(re *core.RequestEvent) error {
		if err := requireAdmin(re); err != nil {
			return err
		}
		var input struct {
			Path string `json:"path"`
		}
		if err := re.BindBody(&input); err != nil {
			return re.JSON(400, map[string]string{"error": "Invalid request body"})
		}
		if input.Path == "" {
			return re.JSON(400, map[string]string{"error": "path is required"})
		}

		conn, err := dialAdmin(re, coord)
		if err != nil {
			return err
		}
		defer conn.Close()

		if _, err := conn.CallExtension(re.Request.Context(), "_goose/unstable/sources/delete", deleteSourceParams{Type: "skill", Path: input.Path}); err != nil {
			return re.JSON(502, map[string]string{"error": fmt.Sprintf("goose sources/delete failed: %v", err)})
		}
		return re.JSON(200, map[string]bool{"deleted": true})
	}).Bind(apis.RequireAuth())
}

// dialAdmin opens an AdminConn for the current request, or writes a 502
// response and returns a non-nil error if the agent profile isn't
// configured/reachable. Every handler above must `defer conn.Close()` on
// success.
func dialAdmin(re *core.RequestEvent, coord func() *coordinator.Coordinator) (acp.Conn, error) {
	c := coord()
	if c == nil {
		return nil, fmt.Errorf("agent profile not configured")
	}
	conn, err := c.AdminConn(re.Request.Context())
	if err != nil {
		return nil, re.JSON(502, map[string]string{"error": fmt.Sprintf("failed to connect to goose: %v", err)})
	}
	return conn, nil
}

// listSkills fans out over Goose's real project-scoping mechanism
// (projectDir, not includeProjectSources — see this plan's Global
// Constraints) and merges the results, deduplicated by path:
//  1. One sources/list call with no projectDir — global skills only.
//  2. One additional call per distinct agent_profiles.workspace_folders[0]
//     — each such call returns that directory's project skills *plus*
//     the same global skills again (Goose always scans global dirs
//     regardless of projectDir), which the path-based dedup collapses.
func listSkills(ctx context.Context, app core.App, coord func() *coordinator.Coordinator) ([]sourceEntryResp, error) {
	c := coord()
	if c == nil {
		return nil, fmt.Errorf("agent profile not configured")
	}
	conn, err := c.AdminConn(ctx)
	if err != nil {
		return nil, fmt.Errorf("AdminConn: %w", err)
	}
	defer conn.Close()

	merged := map[string]sourceEntryResp{}

	if err := fetchSkillsInto(ctx, conn, "", merged); err != nil {
		return nil, fmt.Errorf("list global skills: %w", err)
	}

	pocoRecs, err := app.FindRecordsByFilter("agent_profiles", "1=1", "", 0, 0)
	if err != nil {
		return nil, fmt.Errorf("query agent_profiles: %w", err)
	}
	seenDirs := map[string]bool{}
	for _, poco := range pocoRecs {
		var folders []string
		_ = poco.UnmarshalJSONField("workspace_folders", &folders)
		if len(folders) == 0 {
			continue
		}
		dir := folders[0]
		if dir == "" || seenDirs[dir] {
			continue
		}
		seenDirs[dir] = true
		if err := fetchSkillsInto(ctx, conn, dir, merged); err != nil {
			return nil, fmt.Errorf("list project skills for %q: %w", dir, err)
		}
	}

	out := make([]sourceEntryResp, 0, len(merged))
	for _, s := range merged {
		out = append(out, s)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Path < out[j].Path })
	return out, nil
}

// fetchSkillsInto calls sources/list for the given projectDir ("" for
// global-only) and merges every returned entry into dst, keyed by path.
func fetchSkillsInto(ctx context.Context, conn acp.Conn, projectDir string, dst map[string]sourceEntryResp) error {
	raw, err := conn.CallExtension(ctx, "_goose/unstable/sources/list", listSourcesParams{Type: "skill", ProjectDir: projectDir})
	if err != nil {
		return err
	}
	var resp listSourcesResponse
	if err := json.Unmarshal(raw, &resp); err != nil {
		return fmt.Errorf("parse sources/list response: %w", err)
	}
	for _, s := range resp.Sources {
		dst[s.Path] = s
	}
	return nil
}

func handleSkillsList(re *core.RequestEvent, app core.App, coord func() *coordinator.Coordinator) error {
	entries, err := listSkills(re.Request.Context(), app, coord)
	if err != nil {
		return re.JSON(502, map[string]string{"error": err.Error()})
	}
	return re.JSON(200, map[string]any{"skills": entries})
}
