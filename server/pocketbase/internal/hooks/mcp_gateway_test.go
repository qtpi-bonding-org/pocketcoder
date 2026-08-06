package hooks

import (
	"context"
	"encoding/json"
	"testing"

	acpsdk "github.com/coder/acp-go-sdk"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/acp"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/coordinator"
)

// fakeGatewayConn is a scriptable acp.Conn double: CallExtension responds
// differently per method so tests can simulate "gateway already registered"
// vs. "not yet registered".
type fakeGatewayConn struct {
	extensionsListResponse string // raw JSON returned for config/extensions/list
	calls                   []string
}

func (f *fakeGatewayConn) Initialize(context.Context, acpsdk.InitializeRequest) (acpsdk.InitializeResponse, error) {
	return acpsdk.InitializeResponse{}, nil
}
func (f *fakeGatewayConn) NewSession(context.Context, acpsdk.NewSessionRequest) (acpsdk.NewSessionResponse, error) {
	return acpsdk.NewSessionResponse{}, nil
}
func (f *fakeGatewayConn) LoadSession(context.Context, acpsdk.LoadSessionRequest) (acpsdk.LoadSessionResponse, error) {
	return acpsdk.LoadSessionResponse{}, nil
}
func (f *fakeGatewayConn) SetSessionMode(context.Context, acpsdk.SetSessionModeRequest) (acpsdk.SetSessionModeResponse, error) {
	return acpsdk.SetSessionModeResponse{}, nil
}
func (f *fakeGatewayConn) SetSessionConfigOption(context.Context, acpsdk.SetSessionConfigOptionRequest) (acpsdk.SetSessionConfigOptionResponse, error) {
	return acpsdk.SetSessionConfigOptionResponse{}, nil
}
func (f *fakeGatewayConn) CallExtension(_ context.Context, method string, _ any) (json.RawMessage, error) {
	f.calls = append(f.calls, method)
	if method == "_goose/unstable/config/extensions/list" {
		return json.RawMessage(f.extensionsListResponse), nil
	}
	return json.RawMessage(`{}`), nil
}
func (f *fakeGatewayConn) Prompt(context.Context, acpsdk.PromptRequest) (acpsdk.PromptResponse, error) {
	return acpsdk.PromptResponse{}, nil
}
func (f *fakeGatewayConn) Cancel(context.Context, acpsdk.CancelNotification) error { return nil }
func (f *fakeGatewayConn) UnstableDeleteSession(context.Context, acpsdk.UnstableDeleteSessionRequest) (acpsdk.UnstableDeleteSessionResponse, error) {
	return acpsdk.UnstableDeleteSessionResponse{}, nil
}
func (f *fakeGatewayConn) Close() error { return nil }

var _ acp.Conn = (*fakeGatewayConn)(nil)

func newTestCoordinator(t *testing.T, fc *fakeGatewayConn) *coordinator.Coordinator {
	t.Helper()
	coord, err := coordinator.New(coordinator.Config{
		GooseURL: "ws://unused", GooseSecret: "x", Workspace: "/tmp",
		Dial: func(ctx context.Context, client acpsdk.Client, _ coordinator.Target) (acp.Conn, error) {
			return fc, nil
		},
	})
	if err != nil {
		t.Fatalf("coordinator.New: %v", err)
	}
	return coord
}

func TestRegisterMcpGatewayExtension_SkipsWhenNoCoordinator(t *testing.T) {
	// Must not panic/block when the agent profile is disabled.
	registerMcpGatewayExtensionOnce(context.Background(), func() *coordinator.Coordinator { return nil })
}

func TestRegisterMcpGatewayExtension_AddsWhenAbsent(t *testing.T) {
	fc := &fakeGatewayConn{extensionsListResponse: `{"extensions":[],"warnings":[]}`}
	coord := newTestCoordinator(t, fc)

	registerMcpGatewayExtensionOnce(context.Background(), func() *coordinator.Coordinator { return coord })

	if len(fc.calls) != 2 || fc.calls[0] != "_goose/unstable/config/extensions/list" || fc.calls[1] != "_goose/unstable/config/extensions/add" {
		t.Fatalf("calls = %v, want [list, add]", fc.calls)
	}
}

func TestRegisterMcpGatewayExtension_SkipsWhenAlreadyPresent(t *testing.T) {
	// Goose's real config/extensions/list response for an mcp-type extension
	// has no top-level extension.name — the name lives at
	// extension.server.name (see registerMcpGatewayExtensionOnce's comment).
	// This fixture must match that real shape, not a simplified one, or this
	// test would pass while the production parsing logic is still broken.
	fc := &fakeGatewayConn{extensionsListResponse: `{"extensions":[{"extension":{"type":"mcp","server":{"type":"http","name":"gateway","url":"http://mcp-gateway:8811/mcp","headers":[]}},"enabled":true}],"warnings":[]}`}
	coord := newTestCoordinator(t, fc)

	registerMcpGatewayExtensionOnce(context.Background(), func() *coordinator.Coordinator { return coord })

	if len(fc.calls) != 1 || fc.calls[0] != "_goose/unstable/config/extensions/list" {
		t.Fatalf("calls = %v, want [list] only (already registered, no add call)", fc.calls)
	}
}

func TestMcpGatewayAuthHeaders(t *testing.T) {
	t.Run("empty token yields no headers", func(t *testing.T) {
		t.Setenv("MCP_GATEWAY_AUTH_TOKEN", "")
		got := mcpGatewayAuthHeaders()
		if len(got) != 0 {
			t.Fatalf("headers = %v, want empty", got)
		}
	})

	t.Run("token yields a Bearer Authorization header", func(t *testing.T) {
		t.Setenv("MCP_GATEWAY_AUTH_TOKEN", "spike-test-token")
		got := mcpGatewayAuthHeaders()
		want := []httpHeaderParam{{Name: "Authorization", Value: "Bearer spike-test-token"}}
		if len(got) != 1 || got[0] != want[0] {
			t.Fatalf("headers = %v, want %v", got, want)
		}
	})
}
