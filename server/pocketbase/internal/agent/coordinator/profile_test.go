package coordinator

import (
	"context"
	"encoding/json"
	"testing"

	acpsdk "github.com/coder/acp-go-sdk"
)

// recordingConn is a minimal test fake that records which methods were called.
type recordingConn struct {
	calledSystemPromptSet bool
	calledSetConfigOption bool
	calledSetSessionMode  bool
}

func (r *recordingConn) Initialize(context.Context, acpsdk.InitializeRequest) (acpsdk.InitializeResponse, error) {
	return acpsdk.InitializeResponse{}, nil
}
func (r *recordingConn) NewSession(context.Context, acpsdk.NewSessionRequest) (acpsdk.NewSessionResponse, error) {
	return acpsdk.NewSessionResponse{}, nil
}
func (r *recordingConn) LoadSession(context.Context, acpsdk.LoadSessionRequest) (acpsdk.LoadSessionResponse, error) {
	return acpsdk.LoadSessionResponse{}, nil
}
func (r *recordingConn) ResumeSession(context.Context, acpsdk.ResumeSessionRequest) (acpsdk.ResumeSessionResponse, error) {
	return acpsdk.ResumeSessionResponse{}, nil
}
func (r *recordingConn) SetSessionMode(context.Context, acpsdk.SetSessionModeRequest) (acpsdk.SetSessionModeResponse, error) {
	r.calledSetSessionMode = true
	return acpsdk.SetSessionModeResponse{}, nil
}
func (r *recordingConn) SetSessionConfigOption(context.Context, acpsdk.SetSessionConfigOptionRequest) (acpsdk.SetSessionConfigOptionResponse, error) {
	r.calledSetConfigOption = true
	return acpsdk.SetSessionConfigOptionResponse{}, nil
}
func (r *recordingConn) Prompt(context.Context, acpsdk.PromptRequest) (acpsdk.PromptResponse, error) {
	return acpsdk.PromptResponse{}, nil
}
func (r *recordingConn) Cancel(context.Context, acpsdk.CancelNotification) error {
	return nil
}
func (r *recordingConn) UnstableDeleteSession(context.Context, acpsdk.UnstableDeleteSessionRequest) (acpsdk.UnstableDeleteSessionResponse, error) {
	return acpsdk.UnstableDeleteSessionResponse{}, nil
}
func (r *recordingConn) CallExtension(context.Context, string, any) (json.RawMessage, error) {
	r.calledSystemPromptSet = true
	return json.RawMessage(`{}`), nil
}
func (r *recordingConn) Done() <-chan struct{} {
	return nil
}
func (r *recordingConn) Close() error {
	return nil
}

func TestGlobalConfigApplier_SetsMode(t *testing.T) {
	fc := &fakeConn{}
	err := GlobalConfigApplier{}.Apply(context.Background(), fc, "sess-1",
		SessionProfile{Mode: acpsdk.SessionModeId("auto")}, nil)
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
	p2 := SessionProfile{McpServers: []acpsdk.McpServer{server}, AdditionalDirectories: []string{"/d"}, SupportsAdditionalDirectories: true}
	if len(p2.mcpServers()) != 1 || len(p2.additionalDirectories()) != 1 {
		t.Fatal("accessors must pass through populated slices unchanged")
	}
}

func TestSessionProfilePermissionDecisionUsesSpecificRule(t *testing.T) {
	p := SessionProfile{PermissionRules: []ToolPermissionRule{
		{Tool: "*", Pattern: "*", Action: ToolPermissionAsk},
		{Tool: "bash", Pattern: "*", Action: ToolPermissionAsk},
		{Tool: "bash", Pattern: "ls *", Action: ToolPermissionAllow},
	}}
	if got := p.PermissionDecision("bash", "ls -la"); got != ToolPermissionAllow {
		t.Fatalf("specific allow = %q, want allow", got)
	}
	if got := p.PermissionDecision("bash", "rm -rf /workspace"); got != ToolPermissionAsk {
		t.Fatalf("broad ask = %q, want ask", got)
	}
}

func TestSessionMetaContainsOptionalPromptExtension(t *testing.T) {
	p := SessionProfile{Instructions: "be concise"}
	meta := p.sessionMeta()
	if meta == nil || meta["pocketcoder"].(map[string]any)["systemPrompt"] != "be concise" {
		t.Fatalf("unexpected session metadata: %#v", meta)
	}
}

func TestPerSessionApplierDeliversProviderLive(t *testing.T) {
	fc := &fakeConn{}
	err := PerSessionApplier{}.Apply(context.Background(), fc, "sess-1", SessionProfile{Provider: "anthropic", SupportsLiveConfig: true}, nil)
	if err != nil {
		t.Fatalf("Apply: %v", err)
	}
	if fc.lastSetConfigOption.ValueId == nil || fc.lastSetConfigOption.ValueId.ConfigId != "provider" || fc.lastSetConfigOption.ValueId.Value != "anthropic" {
		t.Errorf("expected configId=provider value=anthropic, got %+v", fc.lastSetConfigOption)
	}
}

func TestPerSessionApplierDeliversModelLive(t *testing.T) {
	fc := &fakeConn{}
	err := PerSessionApplier{}.Apply(context.Background(), fc, "sess-1", SessionProfile{Model: "claude-opus", SupportsLiveConfig: true}, nil)
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

func TestPerSessionApplierSkipsEmptyFields(t *testing.T) {
	fc := &fakeConn{}
	// Empty SessionProfile — GlobalConfigApplier already returns nil for
	// empty Mode (profile.go:76); PerSessionApplier must not call Goose
	// at all for Provider/Model/Instructions when they're empty either.
	err := PerSessionApplier{}.Apply(context.Background(), fc, "sess-1", SessionProfile{}, nil)
	if err != nil {
		t.Fatalf("Apply: %v", err)
	}
	if len(fc.setConfigOptionCalls) != 0 || fc.callExtensionCalls != 0 {
		t.Errorf("expected zero Goose calls for an empty profile, got %d config calls, %d extension calls", len(fc.setConfigOptionCalls), fc.callExtensionCalls)
	}
}

func TestSelectApplierAlwaysReturnsPerSessionApplier(t *testing.T) {
	applier := selectApplier(SessionProfile{})
	if _, ok := applier.(PerSessionApplier); !ok {
		t.Errorf("expected PerSessionApplier, got %T", applier)
	}
}

func TestSessionProfileCarriesTargetAndCapabilityFlags(t *testing.T) {
	p := SessionProfile{
		Target:             Target{URL: "ws://example/acp", Secret: "s3cr3t"},
		ResolvedInstanceID: "abc123456789012",
		PinnedInstanceID:   "abc123456789012",
		SupportsLiveConfig: true,
	}
	if p.Target.URL != "ws://example/acp" {
		t.Error("Target.URL not settable")
	}
	if !p.SupportsLiveConfig {
		t.Error("expected live config capability")
	}
	if p.ResolvedInstanceID != p.PinnedInstanceID {
		t.Error("expected fields to be independently settable and equal in this fixture")
	}
}

func TestApplySkipsSetConfigOptionWhenLiveConfigUnsupported(t *testing.T) {
	conn := &recordingConn{}
	p := SessionProfile{Provider: "anthropic", Model: "claude", SupportsLiveConfig: false}
	applier := PerSessionApplier{}
	if err := applier.Apply(context.Background(), conn, "sess1", p, nil); err != nil {
		t.Fatal(err)
	}
	if conn.calledSetConfigOption {
		t.Error("must not call session/set_config_option when SupportsLiveConfig is false")
	}
}

func TestApplySkipsSetSessionModeWhenModeNotAdvertised(t *testing.T) {
	conn := &recordingConn{}
	p := SessionProfile{Mode: "approve"}
	modes := &acpsdk.SessionModeState{AvailableModes: []acpsdk.SessionMode{{Id: "chat"}}} // "approve" not in the list
	applier := PerSessionApplier{}
	if err := applier.Apply(context.Background(), conn, "sess1", p, modes); err != nil {
		t.Fatal(err)
	}
	if conn.calledSetSessionMode {
		t.Error("must not call session/set_mode with a mode id the harness didn't advertise")
	}
}

func TestApplyDoesNotSkipModeWhenModesIsNil(t *testing.T) {
	conn := &recordingConn{}
	p := SessionProfile{Mode: "approve"}
	applier := PerSessionApplier{}
	if err := applier.Apply(context.Background(), conn, "sess1", p, nil); err != nil {
		t.Fatal(err)
	}
	if !conn.calledSetSessionMode {
		t.Error("nil modes must mean 'don't assert', not 'skip' — expected SetSessionMode to still be called")
	}
}
