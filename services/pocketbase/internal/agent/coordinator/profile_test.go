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

func TestPerSessionApplierDeliversProviderLive(t *testing.T) {
	fc := &fakeConn{}
	err := PerSessionApplier{}.Apply(context.Background(), fc, "sess-1", SessionProfile{Provider: "anthropic"})
	if err != nil {
		t.Fatalf("Apply: %v", err)
	}
	if fc.lastSetConfigOption.ValueId == nil || fc.lastSetConfigOption.ValueId.ConfigId != "provider" || fc.lastSetConfigOption.ValueId.Value != "anthropic" {
		t.Errorf("expected configId=provider value=anthropic, got %+v", fc.lastSetConfigOption)
	}
}

func TestPerSessionApplierDeliversModelLive(t *testing.T) {
	fc := &fakeConn{}
	err := PerSessionApplier{}.Apply(context.Background(), fc, "sess-1", SessionProfile{Model: "claude-opus"})
	if err != nil {
		t.Fatalf("Apply: %v", err)
	}
	found := false
	for _, c := range fc.setConfigOptionCalls {
		if c.ValueId != nil && c.ValueId.ConfigId == "model" && c.ValueId.Value == "claude-opus" {
			found = true
		}
	}
	if !found {
		t.Errorf("expected a configId=model value=claude-opus call, got %+v", fc.setConfigOptionCalls)
	}
}

func TestPerSessionApplierDeliversInstructionsViaCustomMethod(t *testing.T) {
	fc := &fakeConn{}
	err := PerSessionApplier{}.Apply(context.Background(), fc, "sess-1", SessionProfile{Instructions: "You are a terse assistant."})
	if err != nil {
		t.Fatalf("Apply: %v", err)
	}
	if fc.lastExtensionMethod != "_goose/unstable/session/system-prompt/set" {
		t.Errorf("expected the system-prompt custom method, got %q", fc.lastExtensionMethod)
	}
	params, ok := fc.lastExtensionParams.(systemPromptSetParams)
	if !ok {
		t.Fatalf("expected systemPromptSetParams, got %T", fc.lastExtensionParams)
	}
	if params.SessionID != "sess-1" || params.SystemPrompt != "You are a terse assistant." {
		t.Errorf("unexpected params: %+v", params)
	}
}

func TestPerSessionApplierSkipsEmptyFields(t *testing.T) {
	fc := &fakeConn{}
	// Empty SessionProfile — GlobalConfigApplier already returns nil for
	// empty Mode (profile.go:76); PerSessionApplier must not call Goose
	// at all for Provider/Model/Instructions when they're empty either.
	err := PerSessionApplier{}.Apply(context.Background(), fc, "sess-1", SessionProfile{})
	if err != nil {
		t.Fatalf("Apply: %v", err)
	}
	if len(fc.setConfigOptionCalls) != 0 || fc.callExtensionCalls != 0 {
		t.Errorf("expected zero Goose calls for an empty profile, got %d config calls, %d extension calls", len(fc.setConfigOptionCalls), fc.callExtensionCalls)
	}
}

func TestSelectApplierAlwaysReturnsPerSessionApplier(t *testing.T) {
	applier := selectApplier(&acpsdk.InitializeResponse{})
	if _, ok := applier.(PerSessionApplier); !ok {
		t.Errorf("expected PerSessionApplier, got %T", applier)
	}
}
