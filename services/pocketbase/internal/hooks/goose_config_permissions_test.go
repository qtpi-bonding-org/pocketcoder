package hooks

import (
	"context"
	"encoding/json"
	"testing"

	acpsdk "github.com/coder/acp-go-sdk"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/acp"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/coordinator"
	_ "github.com/qtpi-automaton/pocketcoder/backend/pb_migrations"
)

// fakeAdminConn is a minimal acp.Conn double for deliverToolPermissions'
// tests — only CallExtension is exercised; every other method is
// unreachable (AdminConn never creates a session or runs a prompt).
type fakeAdminConn struct {
	lastMethod string
	lastParams any
	calls      int
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

func TestDeliverToolPermissions_SkipsWhenNoCoordinator(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	// Must not panic when coord() returns nil (agent profile disabled).
	deliverToolPermissions(app, func() *coordinator.Coordinator { return nil })
}

func TestDeliverToolPermissions_CallsToolsPermissionsSetWithResolvedRows(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	fc := &fakeAdminConn{}
	coord, err := coordinator.New(coordinator.Config{
		GooseURL: "ws://unused", GooseSecret: "x", Workspace: "/tmp",
		Dial: func(ctx context.Context, client acpsdk.Client) (acp.Conn, error) {
			return fc, nil
		},
	})
	if err != nil {
		t.Fatalf("coordinator.New: %v", err)
	}

	poco, err := app.FindCollectionByNameOrId("poco_configs")
	if err != nil {
		t.Fatalf("find poco_configs collection: %v", err)
	}
	rec := core.NewRecord(poco)
	rec.Set("name", "default")
	rec.Set("is_default", true)
	if err := app.Save(rec); err != nil {
		t.Fatalf("save poco_config: %v", err)
	}

	perms, err := app.FindCollectionByNameOrId("tool_permissions")
	if err != nil {
		t.Fatalf("find tool_permissions collection: %v", err)
	}
	permRec := core.NewRecord(perms)
	permRec.Set("tool", "read")
	permRec.Set("action", "allow")
	permRec.Set("pattern", "*")
	permRec.Set("active", true)
	if err := app.Save(permRec); err != nil {
		t.Fatalf("save tool_permissions row: %v", err)
	}

	deliverToolPermissions(app, func() *coordinator.Coordinator { return coord })

	if fc.calls != 1 {
		t.Fatalf("CallExtension calls = %d, want 1", fc.calls)
	}
	if fc.lastMethod != "_goose/unstable/tools/permissions/set" {
		t.Fatalf("method = %q, want tools/permissions/set", fc.lastMethod)
	}
	// lastParams is stored as `any` (CallExtension's own signature) but the
	// caller (deliverToolPermissions) always passes a concrete
	// setToolPermissionsParams value, never a pointer — assert against that
	// exact type, matching how it's constructed in goose_config.go.
	params, ok := fc.lastParams.(setToolPermissionsParams)
	if !ok {
		t.Fatalf("params type = %T, want setToolPermissionsParams", fc.lastParams)
	}
	if len(params.ToolPermissions) != 1 || params.ToolPermissions[0].ToolName != "read" || params.ToolPermissions[0].Permission != "always_allow" {
		t.Fatalf("params = %+v, want one read/always_allow entry", params)
	}
}
