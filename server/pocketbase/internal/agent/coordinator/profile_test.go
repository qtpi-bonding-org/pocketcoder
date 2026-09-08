package coordinator

import (
	"context"
	"encoding/json"
	"testing"
	"time"

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
	_, err := GlobalConfigApplier{}.Apply(context.Background(), fc, "sess-1",
		SessionProfile{Mode: acpsdk.SessionModeId("auto")}, nil)
	if err != nil {
		t.Fatal(err)
	}
	if fc.lastModeSession != "sess-1" || fc.lastMode != "auto" {
		t.Fatalf("set_mode not forwarded: sess=%q mode=%q", fc.lastModeSession, fc.lastMode)
	}
}

func TestGlobalConfigApplier_ToleratesUnknownModeError(t *testing.T) {
	fc := &fakeConn{setModeErr: &acpsdk.RequestError{
		Code: -32602, Message: "Invalid params: mode not found: approve",
		Data: map[string]any{"mode": "approve"},
	}}
	_, err := GlobalConfigApplier{}.Apply(context.Background(), fc, "sess-1",
		SessionProfile{Mode: acpsdk.SessionModeId("approve")}, nil)
	if err != nil {
		t.Fatalf("expected the unknown-mode error to be swallowed, got: %v", err)
	}
}

func TestGlobalConfigApplier_UsesStructuredDataOverMessageText(t *testing.T) {
	fc := &fakeConn{setModeErr: &acpsdk.RequestError{
		Code: -32602, Message: "Invalid params: totally different wording",
		Data: map[string]any{"mode": "approve"},
	}}
	_, err := GlobalConfigApplier{}.Apply(context.Background(), fc, "sess-1",
		SessionProfile{Mode: acpsdk.SessionModeId("approve")}, nil)
	if err != nil {
		t.Fatalf("expected Data.mode match to swallow the error regardless of message text, got: %v", err)
	}
}

func TestGlobalConfigApplier_DoesNotSwallowMismatchedModeInData(t *testing.T) {
	fc := &fakeConn{setModeErr: &acpsdk.RequestError{
		Code: -32602, Message: "Invalid params: mode not found: some-other-mode",
		Data: map[string]any{"mode": "some-other-mode"},
	}}
	_, err := GlobalConfigApplier{}.Apply(context.Background(), fc, "sess-1",
		SessionProfile{Mode: acpsdk.SessionModeId("approve")}, nil)
	if err == nil {
		t.Fatal("expected an error for a mode mismatch unrelated to the one we sent")
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
	_, err := PerSessionApplier{}.Apply(context.Background(), fc, "sess-1", SessionProfile{
		Provider: "anthropic", SupportsLiveConfig: true, SupportsLiveCredentialRegistration: true,
	}, nil)
	if err != nil {
		t.Fatalf("Apply: %v", err)
	}
	if fc.lastSetConfigOption.ValueId == nil || fc.lastSetConfigOption.ValueId.ConfigId != "provider" || fc.lastSetConfigOption.ValueId.Value != "anthropic" {
		t.Errorf("expected configId=provider value=anthropic, got %+v", fc.lastSetConfigOption)
	}
	if len(fc.setConfigOptionCalls) != 1 {
		t.Errorf("config calls = %d, want exactly 1", len(fc.setConfigOptionCalls))
	}
}

// TestPerSessionApplierSkipsProviderConfigForOpencodeShapedProfile guards
// against a real bug: opencode is SupportsLiveConfig=true (like goose) but
// its ACP server only implements session/set_config_option for
// "model"/"effort"/"mode", never "provider" -- sending it always fails with
// "unknown config option: provider". SupportsLiveCredentialRegistration is
// goose-exclusive today and is what actually gates whether "provider" is a
// supported configId, not SupportsLiveConfig alone.
func TestPerSessionApplierSkipsProviderConfigForOpencodeShapedProfile(t *testing.T) {
	fc := &fakeConn{}
	_, err := PerSessionApplier{}.Apply(context.Background(), fc, "sess-1", SessionProfile{
		Provider: "openrouter", Model: "openrouter/auto",
		SupportsLiveConfig: true, SupportsLiveCredentialRegistration: false,
	}, nil)
	if err != nil {
		t.Fatalf("Apply: %v", err)
	}
	for _, c := range fc.setConfigOptionCalls {
		if c.ValueId != nil && c.ValueId.ConfigId == "provider" {
			t.Fatalf("expected no configId=provider call for an opencode-shaped profile, got %+v", c)
		}
	}
	found := false
	for _, c := range fc.setConfigOptionCalls {
		if c.ValueId != nil && c.ValueId.ConfigId == "model" && c.ValueId.Value == "openrouter/auto" {
			found = true
		}
	}
	if !found {
		t.Errorf("expected a configId=model value=openrouter/auto call, got %+v", fc.setConfigOptionCalls)
	}
}

func TestPerSessionApplierDeliversModelLive(t *testing.T) {
	fc := &fakeConn{}
	_, err := PerSessionApplier{}.Apply(context.Background(), fc, "sess-1", SessionProfile{Model: "claude-opus", SupportsLiveConfig: true}, nil)
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

// Apply must surface the harness's post-correction ConfigOptions so a
// caller can republish the corrected value to the client.
func TestPerSessionApplierReturnsConfigOptionsFromTheModelResponse(t *testing.T) {
	fc := &fakeConn{setConfigOptionResp: acpsdk.SetSessionConfigOptionResponse{
		ConfigOptions: []acpsdk.SessionConfigOption{{Select: &acpsdk.SessionConfigOptionSelect{
			Id: "model", CurrentValue: "minimax/minimax-m2.7:free",
		}}},
	}}
	options, err := PerSessionApplier{}.Apply(context.Background(), fc, "sess-1", SessionProfile{
		Model: "minimax/minimax-m2.7:free", SupportsLiveConfig: true,
	}, nil)
	if err != nil {
		t.Fatalf("Apply: %v", err)
	}
	if len(options) != 1 || options[0].Select == nil || options[0].Select.CurrentValue != "minimax/minimax-m2.7:free" {
		t.Fatalf("Apply options = %+v, want the fake's post-correction ConfigOptions passed through", options)
	}
}

func TestPerSessionApplierRetriesModelNotFound(t *testing.T) {
	originalPoll := modelRetryPollInterval
	modelRetryPollInterval = 5 * time.Millisecond
	defer func() { modelRetryPollInterval = originalPoll }()

	modelNotFound := &acpsdk.RequestError{
		Code: -32602, Message: "Invalid params: model not found: openrouter/auto",
		Data: map[string]any{"modelId": "openrouter/auto"},
	}
	fc := &fakeConn{setConfigOptionErrs: []error{modelNotFound, modelNotFound, nil}}
	_, err := PerSessionApplier{}.Apply(context.Background(), fc, "sess-1", SessionProfile{
		Model: "openrouter/auto", SupportsLiveConfig: true,
	}, nil)
	if err != nil {
		t.Fatalf("expected the model to be applied after retrying, got: %v", err)
	}
	if len(fc.setConfigOptionCalls) != 3 {
		t.Fatalf("set_config_option calls = %d, want 3 (2 failures + 1 success)", len(fc.setConfigOptionCalls))
	}
}

func TestPerSessionApplierRetriesOnDataModelIdRegardlessOfMessageText(t *testing.T) {
	originalPoll := modelRetryPollInterval
	modelRetryPollInterval = 5 * time.Millisecond
	defer func() { modelRetryPollInterval = originalPoll }()

	modelNotFound := &acpsdk.RequestError{
		Code: -32602, Message: "Invalid params: totally different wording",
		Data: map[string]any{"modelId": "openrouter/auto"},
	}
	fc := &fakeConn{setConfigOptionErrs: []error{modelNotFound, nil}}
	_, err := PerSessionApplier{}.Apply(context.Background(), fc, "sess-1", SessionProfile{
		Model: "openrouter/auto", SupportsLiveConfig: true,
	}, nil)
	if err != nil {
		t.Fatalf("expected Data.modelId match to trigger a retry regardless of message text, got: %v", err)
	}
}

func TestPerSessionApplierGivesUpOnGenuinelyUnknownModel(t *testing.T) {
	originalTimeout, originalPoll := modelRetryTimeout, modelRetryPollInterval
	modelRetryTimeout, modelRetryPollInterval = 30*time.Millisecond, 5*time.Millisecond
	defer func() { modelRetryTimeout, modelRetryPollInterval = originalTimeout, originalPoll }()

	notFound := &acpsdk.RequestError{
		Code: -32602, Message: "Invalid params: model not found: nonexistent-model",
	}
	fc := &fakeConnAlwaysErr{err: notFound}
	_, err := PerSessionApplier{}.Apply(context.Background(), fc, "sess-1", SessionProfile{
		Model: "nonexistent-model", SupportsLiveConfig: true,
	}, nil)
	if err == nil {
		t.Fatal("expected an error for a model that never becomes available, got nil")
	}
	if fc.calls < 2 {
		t.Fatalf("set_config_option calls = %d, want at least 2 (proves it actually retried before giving up)", fc.calls)
	}
}

// fakeConnAlwaysErr avoids a bounded scripted-error queue that would panic
// once exhausted.
type fakeConnAlwaysErr struct {
	fakeConn
	err   error
	calls int
}

func (f *fakeConnAlwaysErr) SetSessionConfigOption(ctx context.Context, req acpsdk.SetSessionConfigOptionRequest) (acpsdk.SetSessionConfigOptionResponse, error) {
	f.calls++
	return acpsdk.SetSessionConfigOptionResponse{}, f.err
}

func TestPerSessionApplierSkipsEmptyFields(t *testing.T) {
	fc := &fakeConn{}
	// Empty SessionProfile — GlobalConfigApplier already returns nil for
	// empty Mode (profile.go:76); PerSessionApplier must not call Goose
	// at all for Provider/Model/Instructions when they're empty either.
	_, err := PerSessionApplier{}.Apply(context.Background(), fc, "sess-1", SessionProfile{}, nil)
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
	if _, err := applier.Apply(context.Background(), conn, "sess1", p, nil); err != nil {
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
	if _, err := applier.Apply(context.Background(), conn, "sess1", p, modes); err != nil {
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
	if _, err := applier.Apply(context.Background(), conn, "sess1", p, nil); err != nil {
		t.Fatal(err)
	}
	if !conn.calledSetSessionMode {
		t.Error("nil modes must mean 'don't assert', not 'skip' — expected SetSessionMode to still be called")
	}
}
