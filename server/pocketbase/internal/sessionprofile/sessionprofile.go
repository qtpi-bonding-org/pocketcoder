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

package sessionprofile

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"log"
	"path/filepath"
	"strings"
	"time"

	acpsdk "github.com/coder/acp-go-sdk"
	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/agent/coordinator"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/agent/pocoprompt"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/dockerapi"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/harnessaccount"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/hooks"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/ollama"
)

// ErrProvisioning is returned by Build when no
// harness_instances row exists yet for the resolved (harness, launch_key)
// pair — provisioning has just been kicked off in the background (§5.1),
// and the caller should surface "harness starting, try again shortly"
// rather than blocking on an image pull or proceeding with an empty
// dial target.
var ErrProvisioning = errors.New("harness is being provisioned — retry shortly")

// ErrHarnessFailed is the sentinel wrapped into the error returned when a
// resolved harness_instances row's status is "error" — lets callers tell
// "harness failed to start" apart from any other Build
// failure via errors.Is, without matching on the (last_error-dependent)
// error string.
var ErrHarnessFailed = errors.New("harness failed to start")

// stdioMcp is the stored acp_mcp_servers JSON shape (spec §5.1). Only stdio is
// supported today; http/sse/acp entries are skipped + logged.
type stdioMcp struct {
	Type    string            `json:"type"`
	Name    string            `json:"name"`
	Command string            `json:"command"`
	Args    []string          `json:"args"`
	Env     map[string]string `json:"env"`
}

// workspaceRoot is the mount point every catalog harness is required to
// share (§6.3) — the same value the coordinator falls back to.
const workspaceRoot = "/workspace"

func supportsOllamaHarness(harness *core.Record) bool {
	return harness.GetBool("supports_ollama")
}

// validateWorkspacePath validates that a path is within the workspace root.
func validateWorkspacePath(p string) error {
	clean := filepath.Clean(p)
	if clean != workspaceRoot && !strings.HasPrefix(clean, workspaceRoot+"/") {
		return fmt.Errorf("workspace path %q is outside %s", p, workspaceRoot)
	}
	return nil
}

// Build resolves a chat's agent definition (agent_profile, or the
// default per §5.2) into a coordinator.SessionProfile: model/provider,
// system prompt, workspace cwd/additional directories, per-chat MCP servers
// (stdio only), and mode. It also resolves the harness identity and
// harness_instances row, and validates workspace paths.
func Build(app core.App, chatID string, ctx context.Context, ollamaBaseURL string) (coordinator.SessionProfile, error) {
	p := coordinator.SessionProfile{Instructions: pocoprompt.Default}

	chat, err := app.FindRecordById("chats", chatID)
	if err != nil {
		return p, err
	}
	userID := chat.GetString("user")
	if userID == "" {
		return p, fmt.Errorf("chat %s has no user", chatID)
	}

	// Chat-level fields are read FIRST, unconditionally — this is the fix
	// for the early-return bug: they must not depend on an agent_profile
	// existing at all.
	hmID := chat.GetString("harness_model_override")
	harnessID := chat.GetString("harness")
	ollamaModel := chat.GetString("ollama_model_override")

	var chatFolders []string
	_ = chat.UnmarshalJSONField("workspace_override", &chatFolders)
	if len(chatFolders) > 0 {
		if err := validateWorkspacePath(chatFolders[0]); err != nil {
			return p, err
		}
		p.Cwd = chatFolders[0]
	}

	// Resolve the agent definition: chat's agent_profile, else the default (§5.2).
	pocoID := chat.GetString("agent_profile")
	var poco *core.Record
	if pocoID != "" {
		if poco, err = app.FindRecordById("agent_profiles", pocoID); err != nil {
			return p, err
		}
		if ownerID := poco.GetString("user"); ownerID != "" && ownerID != userID && !poco.GetBool("is_system") {
			return p, fmt.Errorf("agent_profile %s does not belong to chat user", pocoID)
		}
	} else if poco, err = defaultPocoConfigAPI(app, userID); err != nil {
		return p, err
	}
	if poco == nil {
		return p, fmt.Errorf("no default Poco agent profile is configured")
	}
	p.AccountID = userID
	p.AgentProfileID = poco.Id
	p.AgentName = strings.TrimSpace(poco.GetString("name"))
	if p.AgentName == "" {
		return p, fmt.Errorf("agent_profile %s has no name", poco.Id)
	}

	// Default mode if no agent_profile
	p.Mode = acpsdk.SessionModeId("approve")
	if poco != nil {
		if spID := poco.GetString("system_prompt"); spID != "" {
			if sp, err := app.FindRecordById("prompts", spID); err == nil {
				if ownerID := sp.GetString("user"); ownerID != "" && ownerID != userID && !sp.GetBool("is_system") {
					return p, fmt.Errorf("prompt %s does not belong to chat user", spID)
				}
				if body := strings.TrimSpace(sp.GetString("body")); body != "" {
					p.Instructions = body
				}
			}
		}
		if modeID := poco.GetString("permission_mode"); modeID != "" {
			mode, modeErr := app.FindRecordById("permission_modes", modeID)
			if modeErr != nil {
				return p, fmt.Errorf("resolve agent_profiles.permission_mode=%s: %w", modeID, modeErr)
			}
			if baseMode := mode.GetString("base_session_mode"); baseMode != "" {
				p.Mode = acpsdk.SessionModeId(baseMode)
			}
		}

		// workspace_folders (JSON array) -> Cwd (first) + AdditionalDirectories (§5.7).
		var pocoFolders []string
		_ = poco.UnmarshalJSONField("workspace_folders", &pocoFolders)
		if p.Cwd == "" && len(pocoFolders) > 0 {
			p.Cwd = pocoFolders[0]
		}
		if len(pocoFolders) > 1 {
			p.AdditionalDirectories = pocoFolders[1:] // §5.7: always unioned in, regardless of a chat-level cwd override
		}

		// acp_mcp_servers (JSON array) -> []acpsdk.McpServer, stdio only (§5.1).
		var raw []stdioMcp
		_ = poco.UnmarshalJSONField("acp_mcp_servers", &raw)
		for _, m := range raw {
			if m.Type != "" && m.Type != "stdio" {
				log.Printf("[Profile] skipping non-stdio MCP server %q (type=%s) — unsupported today", m.Name, m.Type)
				continue
			}
			env := make([]acpsdk.EnvVariable, 0, len(m.Env))
			for k, v := range m.Env {
				env = append(env, acpsdk.EnvVariable{Name: k, Value: v})
			}
			p.McpServers = append(p.McpServers, acpsdk.McpServer{
				Stdio: &acpsdk.McpServerStdio{Name: m.Name, Command: m.Command, Args: m.Args, Env: env},
			})
		}
	}

	// Permission policy is loaded into the session profile and enforced by the
	// coordinator's ACP RequestPermission callback. It is intentionally not
	// pushed into any harness-specific API: all four harnesses must pass the
	// same PocketBase gate.
	permissionModeID := ""
	if poco != nil {
		permissionModeID = poco.GetString("permission_mode")
	}
	if permissionModeID == "" {
		if mode, modeErr := app.FindFirstRecordByFilter("permission_modes", "is_default = true", nil); modeErr == nil && mode != nil {
			permissionModeID = mode.Id
		}
	}
	if permissionModeID != "" {
		rows, rowsErr := app.FindRecordsByFilter("permission_mode_tools", "active = true && permission_mode = {:mode}", "", 0, 0, map[string]any{"mode": permissionModeID})
		if rowsErr != nil {
			return p, fmt.Errorf("resolve permission_mode_tools: %w", rowsErr)
		}
		p.PermissionRules = make([]coordinator.ToolPermissionRule, 0, len(rows))
		for _, row := range rows {
			p.PermissionRules = append(p.PermissionRules, coordinator.ToolPermissionRule{
				Tool: row.GetString("tool"), Pattern: row.GetString("pattern"),
				Action: coordinator.ToolPermissionAction(row.GetString("action")),
			})
		}
	}

	// Resolve harness: chat.harness wins; else the model's harness; else
	// the seeded default (§5.6.1).
	var harnessRec *core.Record
	if harnessID != "" {
		if harnessRec, err = app.FindRecordById("harnesses", harnessID); err != nil {
			return p, err
		}
	}
	if ollamaModel == "" && hmID != "" {
		hm, err := app.FindRecordById("harness_models", hmID)
		if err == nil {
			p.Model = hm.GetString("harness_model_id")
			if m, err := app.FindRecordById("models", hm.GetString("model")); err == nil {
				p.Provider = m.GetString("provider")
			}
			if harnessRec == nil {
				if hr, err := app.FindRecordById("harnesses", hm.GetString("harness")); err == nil {
					harnessRec = hr
				}
			}
		}
	}
	if harnessRec == nil {
		if harnessRec, err = app.FindFirstRecordByFilter("harnesses", "cli_id = 'goose'", nil); err != nil {
			return p, err
		}
	}
	if ollamaModel != "" {
		if !ollama.ModelNameValid(ollamaModel) {
			return p, fmt.Errorf("invalid Ollama model name %q", ollamaModel)
		}
		if !supportsOllamaHarness(harnessRec) {
			return p, fmt.Errorf("harness %q does not support local Ollama models", harnessRec.GetString("cli_id"))
		}
		installed, err := ollama.ModelInstalled(ctx, ollama.HTTPClient(), ollamaBaseURL, ollamaModel)
		if err != nil {
			return p, fmt.Errorf("check local Ollama model: %w", err)
		}
		if !installed {
			return p, fmt.Errorf("local Ollama model %q is not installed", ollamaModel)
		}
		p.Provider = "ollama"
		p.Model = ollamaModel
	}

	p.SupportsLiveConfig = harnessRec.GetBool("supports_live_config")
	p.SupportsSessionDelete = harnessRec.GetBool("supports_session_delete")
	p.SupportsAdditionalDirectories = harnessRec.GetBool("supports_additional_directories")

	// All harnesses receive PocketBase-owned MCP services through the standard
	// ACP session/new request. This keeps the harness boundary identical and
	// allows Goose to be provisioned lazily like its peers.
	if gw := hooks.McpGatewayHttpServer(); gw != nil {
		p.McpServers = append(p.McpServers, *gw)
	}
	memory, err := hooks.MemoryMcpServer(p.AccountID, p.AgentProfileID, p.AgentName)
	if err != nil {
		return p, err
	}
	p.McpServers = append(p.McpServers, *memory)

	launchKey := ""
	if !p.SupportsLiveConfig && hmID != "" && ollamaModel == "" {
		launchKey = hmID
	}
	account, err := harnessaccount.EnsureDefaultPersonal(app, userID, harnessRec.Id)
	if err != nil {
		return p, fmt.Errorf("resolve harness account: %w", err)
	}
	p.AccountLogin = account.GetString("credential_mode") == harnessaccount.ModeAccount
	p.HarnessName = harnessRec.GetString("name")

	// Shared with hooks.ProvisionHarnessInstance's own lookup — see
	// hooks.FindHarnessInstance's doc comment for why this can't be a
	// single `harness = {:h} && launch_key = {:k}` filter.
	instance, err := hooks.FindHarnessInstance(app, harnessRec.Id, launchKey, userID, account.Id)
	if err != nil {
		return p, err
	}
	if instance != nil {
		if instance.GetBool("managed") {
			instance.Set("last_used", time.Now().UTC().Format(time.RFC3339))
			if err := app.Save(instance); err != nil {
				log.Printf("[Profile] save last_used: %v", err)
			}
		}
		p.ResolvedInstanceID = instance.Id
		p.Target = coordinator.Target{URL: instance.GetString("acp_endpoint"), Secret: instance.GetString("secret")}
		switch instance.GetString("status") {
		case "pending":
			return p, ErrProvisioning
		case "error":
			return p, fmt.Errorf("%w: %s", ErrHarnessFailed, instance.GetString("last_error"))
		}
	} else {
		// No harness_instances row yet for this (harness, launch_key) pair —
		// kick off provisioning (Task 6) in the background rather than
		// blocking this request on an image pull, and tell the caller to
		// retry shortly instead of silently proceeding with an empty
		// dial target.
		harnessIDCopy, launchKeyCopy := harnessRec.Id, launchKey
		go func() {
			if _, perr := hooks.ProvisionHarnessInstance(context.Background(), app, dockerapi.New(), harnessIDCopy, launchKeyCopy, userID); perr != nil {
				log.Printf("[Profile] background provisioning failed for harness %s: %v", harnessIDCopy, perr)
			}
		}()
		return p, ErrProvisioning
	}

	if gs, err := app.FindFirstRecordByFilter("agent_sessions", "chat = {:c}", map[string]any{"c": chatID}); err == nil && gs != nil {
		p.PinnedInstanceID = gs.GetString("harness_instance")
	}

	return p, nil
}

// defaultPocoConfigAPI mirrors the hook's §5.2 tie-break (is_default=true,
// deterministic first on multiple, nil on none). Kept separate from the hooks
// package to avoid a hooks→api import; the logic is small and identical.
// agent_profiles has no created/updated autodate field, so the stable,
// unique-indexed `name` column is the sort key (matches defaultPocoConfig).
func defaultPocoConfigAPI(app core.App, userID string) (*core.Record, error) {
	recs, err := app.FindRecordsByFilter("agent_profiles", "is_default = true && user = {:user}", "name", 0, 0, map[string]any{"user": userID})
	if err != nil {
		return nil, err
	}
	if len(recs) == 0 {
		recs, err = app.FindRecordsByFilter("agent_profiles", "is_default = true && is_system = true", "name", 0, 0)
		if err != nil {
			return nil, err
		}
	}
	if len(recs) == 0 {
		return nil, nil
	}
	if len(recs) > 1 {
		log.Printf("[Profile] %d agent_profiles marked is_default; using first by name %q", len(recs), recs[0].GetString("name"))
	}
	return recs[0], nil
}

// SessionForChat resolves an existing ACP session for a chat owned by userID.
func SessionForChat(app core.App, chatID, userID string) (string, error) {
	record, err := app.FindFirstRecordByFilter("agent_sessions", "chat = {:chat} && user = {:user}", map[string]any{"chat": chatID, "user": userID})
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return "", nil
		}
		return "", err
	}
	return record.GetString("acp_session_id"), nil
}

func SaveSession(ctx context.Context, app core.App, chatID, userID, sessionID, harnessInstanceID string) error {
	collection, err := app.FindCollectionByNameOrId("agent_sessions")
	if err != nil {
		return err
	}
	record := core.NewRecord(collection)
	record.Set("chat", chatID)
	record.Set("user", userID)
	record.Set("acp_session_id", sessionID)
	record.Set("harness_instance", harnessInstanceID)
	if err := app.Save(record); err != nil {
		return fmt.Errorf("save Agent session: %w", err)
	}
	return nil
}
