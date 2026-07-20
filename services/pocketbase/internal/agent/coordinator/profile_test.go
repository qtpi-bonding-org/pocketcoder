package coordinator

import (
	"context"
	"testing"

	acpsdk "github.com/coder/acp-go-sdk"
)

func TestGlobalConfigApplier_SetsMode(t *testing.T) {
	fc := &fakeConn{}
	err := GlobalConfigApplier{}.Apply(context.Background(), fc, "sess-1",
		SessionProfile{Mode: acpsdk.SessionModeId("auto")})
	if err != nil {
		t.Fatal(err)
	}
	if fc.lastModeSession != "sess-1" || fc.lastMode != "auto" {
		t.Fatalf("set_mode not forwarded: sess=%q mode=%q", fc.lastModeSession, fc.lastMode)
	}
}

func TestSelectApplier_DefaultsToGlobalToday(t *testing.T) {
	if _, ok := selectApplier(&acpsdk.InitializeResponse{}).(GlobalConfigApplier); !ok {
		t.Fatal("expected GlobalConfigApplier under today's capabilities")
	}
}

// Goose's session/new|load rejects a null mcpServers/additionalDirectories
// with -32602 "invalid type: null, expected a sequence". A profile with no MCP
// servers and no extra directories (the default chat) must still serialize
// those fields as empty arrays, so the accessors never return nil.
func TestSessionProfile_SliceAccessorsNeverNil(t *testing.T) {
	var p SessionProfile // zero value: both slices nil
	if got := p.mcpServers(); got == nil {
		t.Fatal("mcpServers() returned nil; Goose requires an array")
	}
	if got := p.additionalDirectories(); got == nil {
		t.Fatal("additionalDirectories() returned nil; Goose requires an array")
	}

	server := acpsdk.McpServer{Stdio: &acpsdk.McpServerStdio{Name: "x"}}
	p2 := SessionProfile{McpServers: []acpsdk.McpServer{server}, AdditionalDirectories: []string{"/d"}}
	if len(p2.mcpServers()) != 1 || len(p2.additionalDirectories()) != 1 {
		t.Fatal("accessors must pass through populated slices unchanged")
	}
}
