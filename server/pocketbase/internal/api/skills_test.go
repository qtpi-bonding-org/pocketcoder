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

package api

import (
	"context"
	"encoding/json"
	"fmt"
	"testing"

	acpsdk "github.com/coder/acp-go-sdk"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/acp"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/coordinator"
	_ "github.com/qtpi-automaton/pocketcoder/backend/pb_migrations"
)

// fakeAdminConn is a minimal acp.Conn double — only CallExtension is
// exercised by skills.go's handlers, mirroring
// hooks/goose_config_permissions_test.go's fakeAdminConn (not reused
// directly: Go test doubles aren't exported across packages).
type fakeAdminConn struct {
	lastMethod string
	lastParams any
	calls      int
	response   json.RawMessage
	err        error
}

func (f *fakeAdminConn) Initialize(context.Context, acpsdk.InitializeRequest) (acpsdk.InitializeResponse, error) {
	return acpsdk.InitializeResponse{}, nil
}
func (f *fakeAdminConn) NewSession(context.Context, acpsdk.NewSessionRequest) (acpsdk.NewSessionResponse, error) {
	return acpsdk.NewSessionResponse{}, nil
}
func (f *fakeAdminConn) LoadSession(context.Context, acpsdk.LoadSessionRequest) (acpsdk.LoadSessionResponse, error) {
	return acpsdk.LoadSessionResponse{}, nil
}
func (f *fakeAdminConn) SetSessionMode(context.Context, acpsdk.SetSessionModeRequest) (acpsdk.SetSessionModeResponse, error) {
	return acpsdk.SetSessionModeResponse{}, nil
}
func (f *fakeAdminConn) SetSessionConfigOption(context.Context, acpsdk.SetSessionConfigOptionRequest) (acpsdk.SetSessionConfigOptionResponse, error) {
	return acpsdk.SetSessionConfigOptionResponse{}, nil
}
func (f *fakeAdminConn) CallExtension(_ context.Context, method string, params any) (json.RawMessage, error) {
	f.lastMethod = method
	f.lastParams = params
	f.calls++
	if f.err != nil {
		return nil, f.err
	}
	if f.response != nil {
		return f.response, nil
	}
	return json.RawMessage(`{}`), nil
}
func (f *fakeAdminConn) Prompt(context.Context, acpsdk.PromptRequest) (acpsdk.PromptResponse, error) {
	return acpsdk.PromptResponse{}, nil
}
func (f *fakeAdminConn) Cancel(context.Context, acpsdk.CancelNotification) error { return nil }
func (f *fakeAdminConn) UnstableDeleteSession(context.Context, acpsdk.UnstableDeleteSessionRequest) (acpsdk.UnstableDeleteSessionResponse, error) {
	return acpsdk.UnstableDeleteSessionResponse{}, nil
}
func (f *fakeAdminConn) Close() error { return nil }

var _ acp.Conn = (*fakeAdminConn)(nil)

func fakeCoordWith(fc *fakeAdminConn) func() *coordinator.Coordinator {
	coord, err := coordinator.New(coordinator.Config{
		GooseURL: "ws://unused", GooseSecret: "x", Workspace: "/tmp",
		Dial: func(ctx context.Context, client acpsdk.Client, t coordinator.Target) (acp.Conn, error) {
			return fc, nil
		},
	})
	if err != nil {
		panic(err)
	}
	return func() *coordinator.Coordinator { return coord }
}

func TestBuildCreateSkillParams(t *testing.T) {
	params, err := buildCreateSkillParams(createSkillRequest{
		Name:        "my-skill",
		Description: "does a thing",
		Content:     "# My Skill\n\nBody.",
		Scope:       sourceScopeParam{Scope: "global"},
	})
	if err != nil {
		t.Fatalf("buildCreateSkillParams: %v", err)
	}
	if params.Type != "skill" {
		t.Fatalf("Type = %q, want skill", params.Type)
	}
	if params.Name != "my-skill" || params.Description != "does a thing" || params.Content != "# My Skill\n\nBody." {
		t.Fatalf("params = %+v, want fields to match input", params)
	}
	if params.Target.Scope != "global" {
		t.Fatalf("Target.Scope = %q, want global", params.Target.Scope)
	}
}

func TestBuildCreateSkillParams_RejectsMissingFields(t *testing.T) {
	if _, err := buildCreateSkillParams(createSkillRequest{Description: "d", Content: "c", Scope: sourceScopeParam{Scope: "global"}}); err == nil {
		t.Fatal("expected error for missing name")
	}
	if _, err := buildCreateSkillParams(createSkillRequest{Name: "n", Content: "c", Scope: sourceScopeParam{Scope: "global"}}); err == nil {
		t.Fatal("expected error for missing description")
	}
	if _, err := buildCreateSkillParams(createSkillRequest{Name: "n", Description: "d", Scope: sourceScopeParam{Scope: "global"}}); err == nil {
		t.Fatal("expected error for missing content")
	}
	if _, err := buildCreateSkillParams(createSkillRequest{Name: "n", Description: "d", Content: "c", Scope: sourceScopeParam{Scope: "projectDir"}}); err == nil {
		t.Fatal("expected error for projectDir scope with empty ProjectDir")
	}
	if _, err := buildCreateSkillParams(createSkillRequest{Name: "n", Description: "d", Content: "c", Scope: sourceScopeParam{Scope: "bogus"}}); err == nil {
		t.Fatal("expected error for unrecognized scope value")
	}
}

func TestDialAdmin_ReturnsErrorWhenNoCoordinator(t *testing.T) {
	if _, err := dialAdmin(nil, func() *coordinator.Coordinator { return nil }); err == nil {
		t.Fatal("expected error when coordinator is nil")
	}
}

func TestListSkills_MergesGlobalAndPerProjectCalls(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	// Two agent_profiles with distinct workspace folders, one with none
	// (should be skipped — nothing to scope a project call to).
	harnesses, err := app.FindCollectionByNameOrId("harnesses")
	if err != nil {
		t.Fatal(err)
	}
	harnessRec := core.NewRecord(harnesses)
	harnessRec.Set("name", "goose")
	harnessRec.Set("cli_id", "goose-test")
	harnessRec.Set("acp_transport", "websocket")
	if err := app.Save(harnessRec); err != nil {
		t.Fatal(err)
	}
	poco, err := app.FindCollectionByNameOrId("agent_profiles")
	if err != nil {
		t.Fatal(err)
	}
	withFolder := core.NewRecord(poco)
	withFolder.Set("name", "repo-a")
	withFolder.Set("workspace_folders", []string{"/workspace/repo-a"})
	if err := app.Save(withFolder); err != nil {
		t.Fatal(err)
	}
	noFolder := core.NewRecord(poco)
	noFolder.Set("name", "no-folder")
	if err := app.Save(noFolder); err != nil {
		t.Fatal(err)
	}

	fc := &multiResponseAdminConn{
		byMethodAndProjectDir: map[string]json.RawMessage{
			"": json.RawMessage(`{"sources":[{"name":"global-skill","description":"d","content":"c","path":"/global/global-skill","global":true}]}`),
			"/workspace/repo-a": json.RawMessage(`{"sources":[
				{"name":"global-skill","description":"d","content":"c","path":"/global/global-skill","global":true},
				{"name":"project-skill","description":"d2","content":"c2","path":"/workspace/repo-a/.agents/skills/project-skill","global":false}
			]}`),
		},
	}
	coord, err := coordinator.New(coordinator.Config{
		GooseURL: "ws://unused", GooseSecret: "x", Workspace: "/tmp",
		Dial: func(ctx context.Context, client acpsdk.Client, t coordinator.Target) (acp.Conn, error) {
			return fc, nil
		},
	})
	if err != nil {
		t.Fatal(err)
	}

	entries, err := listSkills(context.Background(), app, func() *coordinator.Coordinator { return coord })
	if err != nil {
		t.Fatalf("listSkills: %v", err)
	}

	if len(entries) != 2 {
		t.Fatalf("entries = %+v, want 2 (deduped by path)", entries)
	}
	byPath := map[string]sourceEntryResp{}
	for _, e := range entries {
		byPath[e.Path] = e
	}
	if _, ok := byPath["/global/global-skill"]; !ok {
		t.Fatal("missing global skill")
	}
	if _, ok := byPath["/workspace/repo-a/.agents/skills/project-skill"]; !ok {
		t.Fatal("missing project-scoped skill — the fan-out over agent_profiles.workspace_folders did not surface it")
	}
	if fc.calls != 2 {
		t.Fatalf("CallExtension calls = %d, want 2 (one global, one for repo-a; no-folder agent_profile must be skipped)", fc.calls)
	}
}

// multiResponseAdminConn returns a canned response keyed by the request's
// ProjectDir (empty string for the global-only call), so a single fake can
// answer the global call and each per-project call differently.
type multiResponseAdminConn struct {
	byMethodAndProjectDir map[string]json.RawMessage
	calls                 int
}

func (f *multiResponseAdminConn) Initialize(context.Context, acpsdk.InitializeRequest) (acpsdk.InitializeResponse, error) {
	return acpsdk.InitializeResponse{}, nil
}
func (f *multiResponseAdminConn) NewSession(context.Context, acpsdk.NewSessionRequest) (acpsdk.NewSessionResponse, error) {
	return acpsdk.NewSessionResponse{}, nil
}
func (f *multiResponseAdminConn) LoadSession(context.Context, acpsdk.LoadSessionRequest) (acpsdk.LoadSessionResponse, error) {
	return acpsdk.LoadSessionResponse{}, nil
}
func (f *multiResponseAdminConn) SetSessionMode(context.Context, acpsdk.SetSessionModeRequest) (acpsdk.SetSessionModeResponse, error) {
	return acpsdk.SetSessionModeResponse{}, nil
}
func (f *multiResponseAdminConn) SetSessionConfigOption(context.Context, acpsdk.SetSessionConfigOptionRequest) (acpsdk.SetSessionConfigOptionResponse, error) {
	return acpsdk.SetSessionConfigOptionResponse{}, nil
}
func (f *multiResponseAdminConn) CallExtension(_ context.Context, method string, params any) (json.RawMessage, error) {
	f.calls++
	lp, ok := params.(listSourcesParams)
	if !ok {
		return nil, fmt.Errorf("unexpected params type %T", params)
	}
	resp, ok := f.byMethodAndProjectDir[lp.ProjectDir]
	if !ok {
		return nil, fmt.Errorf("no canned response for projectDir %q", lp.ProjectDir)
	}
	return resp, nil
}
func (f *multiResponseAdminConn) Prompt(context.Context, acpsdk.PromptRequest) (acpsdk.PromptResponse, error) {
	return acpsdk.PromptResponse{}, nil
}
func (f *multiResponseAdminConn) Cancel(context.Context, acpsdk.CancelNotification) error { return nil }
func (f *multiResponseAdminConn) UnstableDeleteSession(context.Context, acpsdk.UnstableDeleteSessionRequest) (acpsdk.UnstableDeleteSessionResponse, error) {
	return acpsdk.UnstableDeleteSessionResponse{}, nil
}
func (f *multiResponseAdminConn) Close() error { return nil }

var _ acp.Conn = (*multiResponseAdminConn)(nil)
