package hooks

import (
	"context"
	"testing"

	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/coordinator"
)

func TestRegisterCogneeExtension_SkipsWhenNoCoordinator(t *testing.T) {
	// Must not panic/block when the agent profile is disabled.
	registerCogneeExtensionOnce(context.Background(), func() *coordinator.Coordinator { return nil })
}

func TestRegisterCogneeExtension_AddsWhenAbsent(t *testing.T) {
	fc := &fakeGatewayConn{extensionsListResponse: `{"extensions":[],"warnings":[]}`}
	coord := newTestCoordinator(t, fc)

	registerCogneeExtensionOnce(context.Background(), func() *coordinator.Coordinator { return coord })

	if len(fc.calls) != 2 || fc.calls[0] != "_goose/unstable/config/extensions/list" || fc.calls[1] != "_goose/unstable/config/extensions/add" {
		t.Fatalf("calls = %v, want [list, add]", fc.calls)
	}
}

func TestRegisterCogneeExtension_SkipsWhenAlreadyPresent(t *testing.T) {
	// Real config/extensions/list response shape for an mcp-type extension:
	// name lives at extension.server.name, not a top-level extension.name.
	fc := &fakeGatewayConn{extensionsListResponse: `{"extensions":[{"extension":{"type":"mcp","server":{"type":"http","name":"cognee","url":"http://cognee:8000/mcp","headers":[]}},"enabled":true}],"warnings":[]}`}
	coord := newTestCoordinator(t, fc)

	registerCogneeExtensionOnce(context.Background(), func() *coordinator.Coordinator { return coord })

	if len(fc.calls) != 1 || fc.calls[0] != "_goose/unstable/config/extensions/list" {
		t.Fatalf("calls = %v, want [list] only (already registered, no add call)", fc.calls)
	}
}
