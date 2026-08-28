package coordinator

import (
	"context"
	"encoding/json"
	"errors"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/ag-ui-protocol/ag-ui/sdks/community/go/pkg/core/events"
	acpsdk "github.com/coder/acp-go-sdk"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/agent/acp"
)

func testCoordinator(t *testing.T, dial DialFunc) *Coordinator {
	t.Helper()
	c, err := New(Config{Workspace: "/workspace", Dial: dial})
	if err != nil {
		t.Fatal(err)
	}
	return c
}

// testCoordinatorWithConn builds a coordinator that injects the provided
// fakeConn on every dial. The fake captures the acpsdk.Client on first dial so
// tests can drive SessionUpdate / RequestPermission from inside the fake.
func testCoordinatorWithConn(t *testing.T, f *fakeConn, clk Clock) *Coordinator {
	t.Helper()
	c, err := New(Config{Workspace: "/w", Clock: clk,
		Dial: func(_ context.Context, client acpsdk.Client, _ Target) (acp.Conn, error) {
			f.mu.Lock()
			f.client = client
			f.mu.Unlock()
			return f, nil
		}})
	if err != nil {
		t.Fatal(err)
	}
	return c
}

// newFakeConn constructs a fakeConn wired to the new tests' expectations.
// Defaults AgentCapabilities.LoadSession to true (matching real Goose)
// since establishSession now gates session resumption on it — tests that
// specifically want to exercise the unsupported-capability path override
// f.initResp themselves (see TestEstablishSessionErrorsWhenLoadSessionCapabilityMissing).
func newFakeConn() *fakeConn {
	return &fakeConn{
		promptCalled: make(chan struct{}, 1),
		initResp:     acpsdk.InitializeResponse{AgentCapabilities: acpsdk.AgentCapabilities{LoadSession: true}},
	}
}

func TestIdempotencySlotOverwritesOnNewKey(t *testing.T) {
	c := testCoordinator(t, nil)
	chatID := "chat-1"
	if _, found := c.CheckIdempotency(chatID, "key-a"); found {
		t.Fatal("expected no result for a fresh chat")
	}
	c.RecordIdempotency(chatID, "key-a", "result-a")
	if result, found := c.CheckIdempotency(chatID, "key-a"); !found || result != "result-a" {
		t.Fatalf("expected cached result-a, got %v, found=%v", result, found)
	}
	if _, found := c.CheckIdempotency(chatID, "key-b"); found {
		t.Fatal("expected no result for a new key")
	}
	c.RecordIdempotency(chatID, "key-b", "result-b")
	if _, found := c.CheckIdempotency(chatID, "key-a"); found {
		t.Fatal("expected key-a's slot to be gone after key-b overwrote it")
	}
}

func TestIdempotencyOnlyRecordsAfterSuccessfulWork(t *testing.T) {
	c := testCoordinator(t, nil)
	chatID, key := "chat-1", "retry-key"
	if _, found := c.CheckIdempotency(chatID, key); found {
		t.Fatal("expected no cached result before any work has run")
	}
	c.RecordIdempotency(chatID, key, struct{}{})
	if _, found := c.CheckIdempotency(chatID, key); !found {
		t.Fatal("expected the retried request to find the cached slot")
	}
}

type fakeConn struct {
	mu             sync.Mutex
	cancelled      string
	client         acpsdk.Client
	newSession     string
	deletedSession string
	stopReason     acpsdk.StopReason

	// Task 10: captures the last NewSession/LoadSession request so tests can
	// assert a resolved SessionProfile reaches ACP.
	lastNewSessionReq  acpsdk.NewSessionRequest
	lastLoadSessionReq acpsdk.LoadSessionRequest

	// Task 10 extensions.
	closeCount                  int
	blockPrompt                 chan struct{}
	panicOnPrompt               bool
	promptCalled                chan struct{}
	emitElicitation             bool
	emitElicitationURL          bool
	elicitationResolved         bool
	lastMode                    string
	lastModeSession             string
	requestPermission           bool
	requestPermissionToolCallID string

	// Task 1/2: CallExtension captures.
	lastExtensionMethod string
	lastExtensionParams any
	callExtensionCalls  int
	extensionResponse   json.RawMessage
	extensionErr        error
	callOrder           []string

	resumeCalls                int
	lastResumeSessionReq       acpsdk.ResumeSessionRequest
	resumeErr                  error
	done                       chan struct{}
	closeDoneBeforePromptError bool

	// Task 2: capture dial/handshake counts.
	initializeCalls int
	newSessionCalls int

	// Task 3: SetSessionConfigOption captures (provider/model live delivery).
	lastSetConfigOption  acpsdk.SetSessionConfigOptionRequest
	setConfigOptionCalls []acpsdk.SetSessionConfigOptionRequest

	// Task 6: custom InitializeResponse for testing capability flags
	initResp acpsdk.InitializeResponse
}

// waitForPrompt blocks until the fake's Prompt method is invoked (or 2 s timeout).
func (f *fakeConn) waitForPrompt(t *testing.T) {
	t.Helper()
	select {
	case <-f.promptCalled:
	case <-time.After(2 * time.Second):
		t.Fatal("Prompt was not called")
	}
}

// (Coordinator).waitRunDone polls isReserved until the run releases Reserve,
// signalling full teardown.
func (c *Coordinator) waitRunDone(t *testing.T, chatID string) {
	t.Helper()
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		if !c.isReserved(chatID) {
			return
		}
		time.Sleep(5 * time.Millisecond)
	}
	t.Fatalf("run for %q did not finish", chatID)
}

// (Coordinator).waitForPendingPermission returns the id of the first pending
// permission that matches chatID.
func (c *Coordinator) waitForPendingPermission(t *testing.T, chatID string) string {
	t.Helper()
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		var id string
		c.mu.Lock()
		for k, v := range c.pending {
			if v.chatID == chatID {
				id = k
				break
			}
		}
		c.mu.Unlock()
		if id != "" {
			return id
		}
		time.Sleep(5 * time.Millisecond)
	}
	t.Fatalf("no pending permission for %q", chatID)
	return ""
}

func (f *fakeConn) Initialize(context.Context, acpsdk.InitializeRequest) (acpsdk.InitializeResponse, error) {
	f.mu.Lock()
	f.initializeCalls++
	initResp := f.initResp
	f.mu.Unlock()
	return initResp, nil
}
func (f *fakeConn) NewSession(_ context.Context, req acpsdk.NewSessionRequest) (acpsdk.NewSessionResponse, error) {
	f.mu.Lock()
	f.lastNewSessionReq = req
	f.newSessionCalls++
	f.mu.Unlock()
	return acpsdk.NewSessionResponse{SessionId: acpsdk.SessionId(f.newSession)}, nil
}
func (f *fakeConn) LoadSession(_ context.Context, req acpsdk.LoadSessionRequest) (acpsdk.LoadSessionResponse, error) {
	f.mu.Lock()
	f.lastLoadSessionReq = req
	f.mu.Unlock()
	return acpsdk.LoadSessionResponse{}, nil
}
func (f *fakeConn) ResumeSession(_ context.Context, req acpsdk.ResumeSessionRequest) (acpsdk.ResumeSessionResponse, error) {
	f.mu.Lock()
	f.lastResumeSessionReq = req
	f.resumeCalls++
	err := f.resumeErr
	f.mu.Unlock()
	if err != nil {
		return acpsdk.ResumeSessionResponse{}, err
	}
	return acpsdk.ResumeSessionResponse{}, nil
}
func (f *fakeConn) Done() <-chan struct{} {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.done == nil {
		f.done = make(chan struct{})
	}
	return f.done
}

// closeConnDone is test-only: simulates the transport dying.
func (f *fakeConn) closeConnDone() {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.done == nil {
		f.done = make(chan struct{})
	}
	select {
	case <-f.done:
	default:
		close(f.done)
	}
}
func (f *fakeConn) SetSessionMode(_ context.Context, req acpsdk.SetSessionModeRequest) (acpsdk.SetSessionModeResponse, error) {
	f.mu.Lock()
	f.lastMode = string(req.ModeId)
	f.lastModeSession = string(req.SessionId)
	f.mu.Unlock()
	return acpsdk.SetSessionModeResponse{}, nil
}
func (f *fakeConn) SetSessionConfigOption(_ context.Context, req acpsdk.SetSessionConfigOptionRequest) (acpsdk.SetSessionConfigOptionResponse, error) {
	f.mu.Lock()
	f.lastSetConfigOption = req
	f.setConfigOptionCalls = append(f.setConfigOptionCalls, req)
	f.callOrder = append(f.callOrder, "set_config_option")
	f.mu.Unlock()
	return acpsdk.SetSessionConfigOptionResponse{}, nil
}
func (f *fakeConn) Prompt(ctx context.Context, _ acpsdk.PromptRequest) (acpsdk.PromptResponse, error) {
	if f.promptCalled != nil {
		select {
		case f.promptCalled <- struct{}{}:
		default:
		}
	}
	if f.panicOnPrompt {
		panic("boom")
	}
	f.mu.Lock()
	closeDone := f.closeDoneBeforePromptError
	f.mu.Unlock()
	if closeDone {
		f.closeConnDone()
		return acpsdk.PromptResponse{}, errors.New("simulated peer disconnect")
	}
	if f.requestPermission {
		if rp, ok := f.client.(interface {
			RequestPermission(context.Context, acpsdk.RequestPermissionRequest) (acpsdk.RequestPermissionResponse, error)
		}); ok {
			_, _ = rp.RequestPermission(ctx, acpsdk.RequestPermissionRequest{
				Options:  []acpsdk.PermissionOption{{OptionId: "allow_once", Name: "Allow once"}},
				ToolCall: acpsdk.ToolCallUpdate{ToolCallId: acpsdk.ToolCallId(f.requestPermissionToolCallID)},
			})
		}
	}
	if f.emitElicitation {
		if el, ok := f.client.(interface {
			UnstableCreateElicitation(context.Context, acpsdk.UnstableCreateElicitationRequest) (acpsdk.UnstableCreateElicitationResponse, error)
		}); ok {
			_, _ = el.UnstableCreateElicitation(ctx, acpsdk.UnstableCreateElicitationRequest{Form: &acpsdk.UnstableCreateElicitationForm{}})
			f.mu.Lock()
			f.elicitationResolved = true
			f.mu.Unlock()
		}
	}
	if f.emitElicitationURL {
		if el, ok := f.client.(interface {
			UnstableCreateElicitation(context.Context, acpsdk.UnstableCreateElicitationRequest) (acpsdk.UnstableCreateElicitationResponse, error)
		}); ok {
			_, _ = el.UnstableCreateElicitation(ctx, acpsdk.UnstableCreateElicitationRequest{
				Url: &acpsdk.UnstableCreateElicitationUrl{
					Message: "Please authorize in your browser",
					Mode:    "url",
					Url:     "https://example.com/auth",
				},
			})
			f.mu.Lock()
			f.elicitationResolved = true
			f.mu.Unlock()
		}
	}
	if f.blockPrompt != nil {
		select {
		case <-f.blockPrompt:
		case <-ctx.Done():
			return acpsdk.PromptResponse{}, ctx.Err()
		}
	}
	f.mu.Lock()
	sr := f.stopReason
	f.mu.Unlock()
	if sr == "" {
		sr = acpsdk.StopReasonEndTurn
	}
	return acpsdk.PromptResponse{StopReason: sr}, nil
}
func (f *fakeConn) Cancel(_ context.Context, n acpsdk.CancelNotification) error {
	f.mu.Lock()
	f.cancelled = string(n.SessionId)
	f.mu.Unlock()
	return nil
}
func (f *fakeConn) UnstableDeleteSession(_ context.Context, req acpsdk.UnstableDeleteSessionRequest) (acpsdk.UnstableDeleteSessionResponse, error) {
	f.mu.Lock()
	f.deletedSession = string(req.SessionId)
	f.mu.Unlock()
	return acpsdk.UnstableDeleteSessionResponse{}, nil
}
func (f *fakeConn) CallExtension(_ context.Context, method string, params any) (json.RawMessage, error) {
	f.mu.Lock()
	f.lastExtensionMethod = method
	f.lastExtensionParams = params
	f.callExtensionCalls++
	f.callOrder = append(f.callOrder, "call_extension")
	f.mu.Unlock()
	if f.extensionResponse == nil && f.extensionErr == nil {
		return json.RawMessage(`{}`), nil
	}
	return f.extensionResponse, f.extensionErr
}

func (f *fakeConn) Close() error {
	f.mu.Lock()
	f.closeCount++
	f.mu.Unlock()
	return nil
}

var _ acp.Conn = (*fakeConn)(nil)

func TestReserveRejectsConcurrentRunAndReleases(t *testing.T) {
	c := testCoordinator(t, nil)
	if err := c.Reserve("chat"); err != nil {
		t.Fatal(err)
	}
	if !errors.Is(c.Reserve("chat"), ErrRunInProgress) {
		t.Fatal("second reserve accepted")
	}
	c.release("chat")
	if err := c.Reserve("chat"); err != nil {
		t.Fatal(err)
	}
}

func TestPermissionCallbackBlocksUntilApprove(t *testing.T) {
	c := testCoordinator(t, nil)
	sc := &sessionClient{c: c, chatID: "chat", sessionID: "session", bridge: nil, emit: func(events.Event) error { return nil }}
	_ = sc
	// The production callback is exercised through the coordinator's real bridge
	// in integration tests; this test verifies the decision channel semantics.
	p := &pendingPermission{chatID: "chat", options: map[string]struct{}{"allow_once": {}}, decision: make(chan permissionDecision, 1)}
	c.pending["request"] = p
	if err := c.Approve(context.Background(), "chat", "request", "allow_once"); err != nil {
		t.Fatal(err)
	}
	select {
	case d := <-p.decision:
		if d.option != "allow_once" {
			t.Fatal(d)
		}
	case <-time.After(time.Second):
		t.Fatal("permission did not resolve")
	}
}

// ---- Task 10: detached-run lifecycle tests ----

func TestStartPromptDetachedProceedsAfterCallerReturns(t *testing.T) {
	f := newFakeConn()
	c := testCoordinatorWithConn(t, f, NewFakeClock(time.Unix(0, 0)))
	runID, err := c.StartPrompt("A", "hi",
		func(context.Context) (string, error) { return "s1", nil },
		func(context.Context) (SessionProfile, error) { return SessionProfile{}, nil },
		func(context.Context, string) error { return nil },
		nil)
	if err != nil || runID == "" {
		t.Fatalf("StartPrompt runID=%q err=%v", runID, err)
	}
	f.waitForPrompt(t) // proceeds though StartPrompt already returned
	if f.cancelled != "" {
		t.Fatal("caller returning must not cancel the detached run")
	}
	c.waitRunDone(t, "A")
}

func TestTeardownIdempotentClosesConnOnce(t *testing.T) {
	f := newFakeConn()
	f.blockPrompt = make(chan struct{})
	c := testCoordinatorWithConn(t, f, NewFakeClock(time.Unix(0, 0)))
	c.StartPrompt("A", "hi",
		func(context.Context) (string, error) { return "s1", nil },
		func(context.Context) (SessionProfile, error) { return SessionProfile{}, nil },
		func(context.Context, string) error { return nil },
		nil)
	f.waitForPrompt(t)
	go c.Cancel(context.Background(), "A")
	close(f.blockPrompt)
	c.waitRunDone(t, "A")
	if f.closeCount != 1 {
		t.Fatalf("conn.Close called %d times, want 1", f.closeCount)
	}
}

func TestPanicInProduceReleasesReserve(t *testing.T) {
	f := newFakeConn()
	f.panicOnPrompt = true
	c := testCoordinatorWithConn(t, f, NewFakeClock(time.Unix(0, 0)))
	c.StartPrompt("A", "boom",
		func(context.Context) (string, error) { return "s1", nil },
		func(context.Context) (SessionProfile, error) { return SessionProfile{}, nil },
		func(context.Context, string) error { return nil },
		nil)
	c.waitRunDone(t, "A") // must still release Reserve despite the panic
}

func TestDetachedRunPermissionEmitsThroughHub(t *testing.T) {
	f := newFakeConn()
	f.requestPermission = true // fake calls sc.RequestPermission during Prompt, then auto-approves via decision
	c := testCoordinatorWithConn(t, f, NewFakeClock(time.Unix(0, 0)))
	c.StartPrompt("A", "do it",
		func(context.Context) (string, error) { return "s1", nil },
		func(context.Context) (SessionProfile, error) { return SessionProfile{}, nil },
		func(context.Context, string) error { return nil },
		nil)
	id := c.waitForPendingPermission(t, "A") // polls c.pending for the chat
	if err := c.Approve(context.Background(), "A", id, "allow_once"); err != nil {
		t.Fatal(err)
	}
	c.waitRunDone(t, "A") // must not panic on a nil emit
}

func TestPromptFailureAfterConnDoneEmitsInterrupted(t *testing.T) {
	f := newFakeConn()
	f.closeDoneBeforePromptError = true
	c := testCoordinatorWithConn(t, f, NewFakeClock(time.Unix(0, 0)))
	chatID := "interrupted-chat"

	if _, err := c.StartPrompt(chatID, "hello",
		func(context.Context) (string, error) { return "s1", nil },
		func(context.Context) (SessionProfile, error) { return SessionProfile{}, nil },
		func(context.Context, string) error { return nil },
		nil); err != nil {
		t.Fatalf("StartPrompt: %v", err)
	}

	att := c.Attach(chatID, 0)
	defer att.Unsubscribe()
	deadline := time.After(2 * time.Second)
	for {
		for _, se := range att.Buffered {
			b, err := json.Marshal(se.Ev)
			if err != nil {
				t.Fatal(err)
			}
			if strings.Contains(string(b), `"connection_interrupted"`) {
				return
			}
		}
		select {
		case se, ok := <-att.Live:
			if !ok {
				t.Fatal("event stream closed before connection_interrupted")
			}
			b, err := json.Marshal(se.Ev)
			if err != nil {
				t.Fatal(err)
			}
			if strings.Contains(string(b), `"connection_interrupted"`) {
				return
			}
		case <-deadline:
			t.Fatal("timed out waiting for connection_interrupted")
		}
	}
}

// TestRequestPermissionForwardsToolCallID covers the fix for the
// ACP->AG-UI field-drop audit finding: RequestPermissionRequest.ToolCall
// (the id of the tool call this permission gates) must reach the AG-UI
// STATE_DELTA published to the hub, not be dropped in sessionClient.RequestPermission.
func TestRequestPermissionForwardsToolCallID(t *testing.T) {
	f := newFakeConn()
	f.requestPermission = true
	f.requestPermissionToolCallID = "tool-99"
	c := testCoordinatorWithConn(t, f, NewFakeClock(time.Unix(0, 0)))
	c.StartPrompt("A", "do it",
		func(context.Context) (string, error) { return "s1", nil },
		func(context.Context) (SessionProfile, error) { return SessionProfile{}, nil },
		func(context.Context, string) error { return nil },
		nil)
	id := c.waitForPendingPermission(t, "A")

	att := c.Attach("A", 0)
	found := false
	for _, se := range att.Buffered {
		b, err := json.Marshal(se.Ev)
		if err != nil {
			t.Fatal(err)
		}
		if strings.Contains(string(b), `"toolCallId":"tool-99"`) {
			found = true
			break
		}
	}
	att.Unsubscribe()
	if !found {
		t.Fatalf("expected a buffered event carrying toolCallId=tool-99, got %d events", len(att.Buffered))
	}

	if err := c.Approve(context.Background(), "A", id, "allow_once"); err != nil {
		t.Fatal(err)
	}
	c.waitRunDone(t, "A")
}

func TestStartPromptWithUserMessageIDEchoesTextMessage(t *testing.T) {
	f := newFakeConn()
	c := testCoordinatorWithConn(t, f, NewFakeClock(time.Unix(0, 0)))
	att := c.hubFor("A").Attach(0)
	defer att.Unsubscribe()

	_, err := c.StartPrompt("A", "hi",
		func(context.Context) (string, error) { return "s1", nil },
		func(context.Context) (SessionProfile, error) { return SessionProfile{}, nil },
		func(context.Context, string) error { return nil },
		nil,
		WithUserMessageID("user-msg-1"),
	)
	if err != nil {
		t.Fatalf("StartPrompt err=%v", err)
	}
	c.waitRunDone(t, "A")

	var sawStart, sawContent, sawEnd bool
	for i := 0; i < 20; i++ {
		select {
		case se := <-att.Live:
			switch ev := se.Ev.(type) {
			case *events.TextMessageStartEvent:
				if ev.MessageID == "user-msg-1" && ev.Role != nil && *ev.Role == "user" {
					sawStart = true
				}
			case *events.TextMessageContentEvent:
				if ev.MessageID == "user-msg-1" && ev.Delta == "hi" {
					sawContent = true
				}
			case *events.TextMessageEndEvent:
				if ev.MessageID == "user-msg-1" {
					sawEnd = true
				}
			}
		default:
		}
	}
	if !sawStart || !sawContent || !sawEnd {
		t.Fatalf("user message echo incomplete: start=%v content=%v end=%v",
			sawStart, sawContent, sawEnd)
	}
}

func TestStartPromptWithoutUserMessageIDEchoesNothing(t *testing.T) {
	f := newFakeConn()
	c := testCoordinatorWithConn(t, f, NewFakeClock(time.Unix(0, 0)))
	att := c.hubFor("A").Attach(0)
	defer att.Unsubscribe()

	_, err := c.StartPrompt("A", "hi",
		func(context.Context) (string, error) { return "s1", nil },
		func(context.Context) (SessionProfile, error) { return SessionProfile{}, nil },
		func(context.Context, string) error { return nil },
		nil)
	if err != nil {
		t.Fatalf("StartPrompt err=%v", err)
	}
	c.waitRunDone(t, "A")

	for i := 0; i < 20; i++ {
		select {
		case se := <-att.Live:
			if _, ok := se.Ev.(*events.TextMessageStartEvent); ok {
				t.Fatal("no user message echo expected when WithUserMessageID is not set")
			}
		default:
		}
	}
}

// testCoordinatorWithConnAndConfig is testCoordinatorWithConn plus a hook
// to set additional Config fields (e.g. OnPermissionPending) that the
// 3-arg helper has no room for.
func testCoordinatorWithConnAndConfig(t *testing.T, f *fakeConn, clk Clock, configure func(*Config)) *Coordinator {
	t.Helper()
	cfg := Config{Workspace: "/w", Clock: clk,
		Dial: func(_ context.Context, client acpsdk.Client, _ Target) (acp.Conn, error) {
			f.mu.Lock()
			f.client = client
			f.mu.Unlock()
			return f, nil
		}}
	configure(&cfg)
	c, err := New(cfg)
	if err != nil {
		t.Fatal(err)
	}
	return c
}

// TestRequestPermissionFiresOnPermissionPendingWithAGUIShapedPayload covers
// this session's push-schema slice: OnPermissionPending must fire with
// exactly the AG-UI STATE_DELTA payload shape (agui.PermissionPayload) the
// live SSE stream already carries -- not a second, ACP-shaped schema.
func TestRequestPermissionFiresOnPermissionPendingWithAGUIShapedPayload(t *testing.T) {
	f := newFakeConn()
	f.requestPermission = true
	var gotChatID string
	var gotPayload map[string]any
	done := make(chan struct{})
	c := testCoordinatorWithConnAndConfig(t, f, NewFakeClock(time.Unix(0, 0)), func(cfg *Config) {
		cfg.OnPermissionPending = func(_ context.Context, chatID string, payload map[string]any) {
			gotChatID, gotPayload = chatID, payload
			close(done)
		}
	})
	c.StartPrompt("A", "do it",
		func(context.Context) (string, error) { return "s1", nil },
		func(context.Context) (SessionProfile, error) { return SessionProfile{}, nil },
		func(context.Context, string) error { return nil },
		nil)
	id := c.waitForPendingPermission(t, "A")

	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("OnPermissionPending never fired")
	}
	if gotChatID != "A" {
		t.Fatalf("chatID = %q, want %q", gotChatID, "A")
	}
	if gotPayload["requestId"] != id {
		t.Fatalf("payload[\"requestId\"] = %v, want %q", gotPayload["requestId"], id)
	}
	if gotPayload["status"] != "pending" {
		t.Fatalf("payload[\"status\"] = %v, want \"pending\"", gotPayload["status"])
	}
	options, ok := gotPayload["options"].([]map[string]string)
	if !ok || len(options) == 0 {
		t.Fatalf("payload[\"options\"] = %#v, want a non-empty []map[string]string (AG-UI shape)", gotPayload["options"])
	}

	if err := c.Approve(context.Background(), "A", id, options[0]["optionId"]); err != nil {
		t.Fatal(err)
	}
	c.waitRunDone(t, "A")
}

// TestUnstableCreateElicitationFiresOnElicitationPendingWithAGUIShapedPayload
// mirrors the permission test above -- OnElicitationPending must fire with
// agui.ElicitationPayload's exact shape (elicitationId/message/mode/url),
// the same one the live SSE STATE_DELTA carries.
func TestUnstableCreateElicitationFiresOnElicitationPendingWithAGUIShapedPayload(t *testing.T) {
	f := newFakeConn()
	f.emitElicitationURL = true
	var gotChatID string
	var gotPayload map[string]any
	done := make(chan struct{})
	c := testCoordinatorWithConnAndConfig(t, f, NewFakeClock(time.Unix(0, 0)), func(cfg *Config) {
		cfg.OnElicitationPending = func(_ context.Context, chatID string, payload map[string]any) {
			gotChatID, gotPayload = chatID, payload
			close(done)
		}
	})
	c.StartPrompt("A", "need input",
		func(context.Context) (string, error) { return "s1", nil },
		func(context.Context) (SessionProfile, error) { return SessionProfile{}, nil },
		func(context.Context, string) error { return nil },
		nil)
	id := c.waitForPendingElicitation(t, "A")

	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("OnElicitationPending never fired")
	}
	if gotChatID != "A" {
		t.Fatalf("chatID = %q, want %q", gotChatID, "A")
	}
	if gotPayload["elicitationId"] != id {
		t.Fatalf("payload[\"elicitationId\"] = %v, want %q", gotPayload["elicitationId"], id)
	}
	if gotPayload["message"] != "Please authorize in your browser" {
		t.Fatalf("payload[\"message\"] = %v, want %q", gotPayload["message"], "Please authorize in your browser")
	}
	if gotPayload["mode"] != "url" {
		t.Fatalf("payload[\"mode\"] = %v, want \"url\"", gotPayload["mode"])
	}
	if gotPayload["url"] != "https://example.com/auth" {
		t.Fatalf("payload[\"url\"] = %v, want %q", gotPayload["url"], "https://example.com/auth")
	}

	if err := c.ResolveElicitation("A", id, acpsdk.UnstableCreateElicitationResponse{
		Accept: &acpsdk.UnstableCreateElicitationAccept{},
	}); err != nil {
		t.Fatal(err)
	}
	c.waitRunDone(t, "A")
}

func TestNoPermissionRequestDoesNotFireOnPermissionPending(t *testing.T) {
	f := newFakeConn()
	fired := false
	c := testCoordinatorWithConnAndConfig(t, f, NewFakeClock(time.Unix(0, 0)), func(cfg *Config) {
		cfg.OnPermissionPending = func(context.Context, string, map[string]any) { fired = true }
	})
	c.StartPrompt("B", "do it",
		func(context.Context) (string, error) { return "s1", nil },
		func(context.Context) (SessionProfile, error) { return SessionProfile{}, nil },
		func(context.Context, string) error { return nil },
		nil)
	c.waitRunDone(t, "B")
	if fired {
		t.Fatal("OnPermissionPending fired for a run with no permission request at all")
	}
}

func TestAutomaticPermissionResponseUsesOneShotOption(t *testing.T) {
	resp := automaticPermissionResponse([]acpsdk.PermissionOption{
		{OptionId: "allow_always", Kind: acpsdk.PermissionOptionKindAllowAlways},
		{OptionId: "allow_once", Kind: acpsdk.PermissionOptionKindAllowOnce},
	}, ToolPermissionAllow)
	if resp.Outcome.Selected == nil || resp.Outcome.Selected.OptionId != "allow_once" {
		t.Fatalf("allow response = %#v, want allow_once", resp)
	}
	resp = automaticPermissionResponse([]acpsdk.PermissionOption{{OptionId: "reject_once", Kind: acpsdk.PermissionOptionKindRejectOnce}}, ToolPermissionDeny)
	if resp.Outcome.Selected == nil || resp.Outcome.Selected.OptionId != "reject_once" {
		t.Fatalf("deny response = %#v, want reject_once", resp)
	}
}

// ---- Task 11: cancel triggers + orphan-session compensation ----

// Explicit cancel must propagate to the ACP conn as a Cancel notification
// carrying the detached run's sessionId.
func TestExplicitCancelSendsAcpCancel(t *testing.T) {
	f := newFakeConn()
	f.blockPrompt = make(chan struct{})
	c := testCoordinatorWithConn(t, f, NewFakeClock(time.Unix(0, 0)))
	c.StartPrompt("A", "hi",
		func(context.Context) (string, error) { return "s1", nil },
		func(context.Context) (SessionProfile, error) { return SessionProfile{}, nil },
		func(context.Context, string) error { return nil },
		nil)
	f.waitForPrompt(t)
	if err := c.Cancel(context.Background(), "A"); err != nil {
		t.Fatal(err)
	}
	c.waitRunDone(t, "A")
	if f.cancelled != "s1" {
		t.Fatalf("cancelled=%q, want s1", f.cancelled)
	}
}

// Max-run timer (default 15m) must fire under a fake clock, cancel the run,
// and let the detached teardown release Reserve.
func TestMaxRunTimeoutTearsDown(t *testing.T) {
	f := newFakeConn()
	f.blockPrompt = make(chan struct{}) // never unblocked
	clk := NewFakeClock(time.Unix(0, 0))
	c := testCoordinatorWithConn(t, f, clk)
	c.StartPrompt("A", "hi",
		func(context.Context) (string, error) { return "s1", nil },
		func(context.Context) (SessionProfile, error) { return SessionProfile{}, nil },
		func(context.Context, string) error { return nil },
		nil)
	f.waitForPrompt(t)
	clk.Advance(15*time.Minute + time.Second)
	c.waitRunDone(t, "A")
}

// When session/new succeeds but the mapping persist fails, the freshly minted
// Goose session must be deleted so it does not strand history on the server.
func TestOrphanSessionCompensatedOnPersistFailure(t *testing.T) {
	f := newFakeConn()
	f.newSession = "orphan-1"
	c := testCoordinatorWithConn(t, f, NewFakeClock(time.Unix(0, 0)))
	c.StartPrompt("A", "hi",
		func(context.Context) (string, error) { return "", nil }, // unmapped -> session/new
		func(context.Context) (SessionProfile, error) { return SessionProfile{}, nil },
		func(context.Context, string) error { return errors.New("db down") },
		nil)
	c.waitRunDone(t, "A")
	if f.deletedSession != "orphan-1" {
		t.Fatalf("persist failure must compensate via delete, deleted=%q", f.deletedSession)
	}
}

// TestResolvedProfileReachesNewSessionAndMode proves a resolved SessionProfile
// (cwd, additional directories, MCP servers, mode) reaches the ACP
// session/new + set_session_mode calls made during a detached run.
func TestResolvedProfileReachesNewSessionAndMode(t *testing.T) {
	f := newFakeConn()
	f.newSession = "s-new"
	c := testCoordinatorWithConn(t, f, NewFakeClock(time.Unix(0, 0)))
	profile := SessionProfile{
		Cwd:                           "/repo",
		AdditionalDirectories:         []string{"/repo/extra"},
		SupportsAdditionalDirectories: true,
		McpServers:                    []acpsdk.McpServer{{Stdio: &acpsdk.McpServerStdio{Name: "fs", Command: "mcp-fs"}}},
		Mode:                          acpsdk.SessionModeId("auto"),
	}
	c.StartPrompt("A", "hi",
		func(context.Context) (string, error) { return "", nil }, // unmapped -> session/new
		func(context.Context) (SessionProfile, error) { return profile, nil },
		func(context.Context, string) error { return nil },
		nil)
	c.waitRunDone(t, "A")

	f.mu.Lock()
	newReq := f.lastNewSessionReq
	mode := f.lastMode
	modeSess := f.lastModeSession
	f.mu.Unlock()

	if newReq.Cwd != "/repo" {
		t.Fatalf("NewSession cwd = %q, want /repo", newReq.Cwd)
	}
	if len(newReq.AdditionalDirectories) != 1 || newReq.AdditionalDirectories[0] != "/repo/extra" {
		t.Fatalf("NewSession additionalDirectories = %v", newReq.AdditionalDirectories)
	}
	if len(newReq.McpServers) != 1 || newReq.McpServers[0].Stdio == nil || newReq.McpServers[0].Stdio.Name != "fs" {
		t.Fatalf("NewSession mcpServers = %+v", newReq.McpServers)
	}
	if mode != "auto" || modeSess != "s-new" {
		t.Fatalf("set_session_mode not applied from profile: mode=%q sess=%q", mode, modeSess)
	}
}

// TestOnRunFinishedInvokedOnEndTurn proves the OnRunFinished callback wired
// through StartPrompt is invoked exactly once with StopReasonEndTurn on a
// normal successful prompt.
func TestOnRunFinishedInvokedOnEndTurn(t *testing.T) {
	f := newFakeConn()
	c := testCoordinatorWithConn(t, f, NewFakeClock(time.Unix(0, 0)))
	var calls int
	var last acpsdk.StopReason
	finished := func(_ context.Context, sr acpsdk.StopReason) error {
		calls++
		last = sr
		return nil
	}
	if _, err := c.StartPrompt("A", "hi",
		func(context.Context) (string, error) { return "s1", nil },
		func(context.Context) (SessionProfile, error) { return SessionProfile{}, nil },
		func(context.Context, string) error { return nil },
		finished); err != nil {
		t.Fatal(err)
	}
	c.waitRunDone(t, "A")
	if calls != 1 {
		t.Fatalf("finished callback calls=%d, want 1", calls)
	}
	if last != acpsdk.StopReasonEndTurn {
		t.Fatalf("finished StopReason=%q, want %q", last, acpsdk.StopReasonEndTurn)
	}
}

// TestOnRunFinishedNotInvokedOnCancel proves the OnRunFinished callback is
// never called when the run is cancelled mid-flight: the cancel-guard
// (StopReasonCancelled + runCtx.Err()) keeps the notification fire path
// off the user-initiated-cancel branch.
func TestOnRunFinishedNotInvokedOnCancel(t *testing.T) {
	f := newFakeConn()
	f.blockPrompt = make(chan struct{})
	c := testCoordinatorWithConn(t, f, NewFakeClock(time.Unix(0, 0)))
	var calls int
	finished := func(_ context.Context, _ acpsdk.StopReason) error {
		calls++
		return nil
	}
	c.StartPrompt("A", "hi",
		func(context.Context) (string, error) { return "s1", nil },
		func(context.Context) (SessionProfile, error) { return SessionProfile{}, nil },
		func(context.Context, string) error { return nil },
		finished)
	f.waitForPrompt(t)
	if err := c.Cancel(context.Background(), "A"); err != nil {
		t.Fatal(err)
	}
	c.waitRunDone(t, "A")
	if calls != 0 {
		t.Fatalf("finished callback calls=%d on cancel, want 0", calls)
	}
}

// ---- Task 6: establishSession tests ----

func TestEstablishSessionRejectsHarnessMismatch(t *testing.T) {
	f := newFakeConn()
	c := testCoordinatorWithConn(t, f, NewFakeClock(time.Unix(0, 0)))
	profile := SessionProfile{
		Target:             Target{URL: "ws://new-harness/acp"},
		ResolvedInstanceID: "newharness12345",
		PinnedInstanceID:   "oldharness12345", // different from ResolvedInstanceID
	}
	_, _, _, _, _, _, err := c.establishSession(context.Background(), nil, profile, "existing-session-id", func() {})
	if err == nil {
		t.Fatal("expected an error when resolved harness differs from pinned harness")
	}
}

func TestEstablishSessionAllowsMatchingPin(t *testing.T) {
	f := newFakeConn()
	c := testCoordinatorWithConn(t, f, NewFakeClock(time.Unix(0, 0)))
	profile := SessionProfile{
		Target:             Target{URL: "ws://same-harness/acp"},
		ResolvedInstanceID: "sameharness1234",
		PinnedInstanceID:   "sameharness1234",
	}
	_, _, _, _, _, _, err := c.establishSession(context.Background(), nil, profile, "existing-session-id", func() {})
	if err != nil {
		t.Fatalf("expected no error when resolved == pinned, got %v", err)
	}
}

func TestEstablishSessionCallsBeforeSessionCallBeforeLoadSession(t *testing.T) {
	f := newFakeConn()
	c := testCoordinatorWithConn(t, f, NewFakeClock(time.Unix(0, 0)))
	var calledBefore bool
	profile := SessionProfile{PinnedInstanceID: "", ResolvedInstanceID: ""}
	_, _, _, _, _, _, err := c.establishSession(context.Background(), nil, profile, "existing-session-id", func() { calledBefore = true })
	if err != nil {
		t.Fatal(err)
	}
	if !calledBefore {
		t.Fatal("beforeSessionCall must be invoked before LoadSession")
	}
}

func TestEstablishSessionErrorsWhenLoadSessionCapabilityMissing(t *testing.T) {
	f := newFakeConn()
	f.initResp = acpsdk.InitializeResponse{AgentCapabilities: acpsdk.AgentCapabilities{LoadSession: false}}
	c := testCoordinatorWithConn(t, f, NewFakeClock(time.Unix(0, 0)))
	profile := SessionProfile{}
	_, _, _, _, _, _, err := c.establishSession(context.Background(), nil, profile, "existing-session-id", func() {})
	if err == nil {
		t.Fatal("expected an error resuming a session against a harness that doesn't advertise LoadSession")
	}
}

func TestEstablishSessionUsesResumeWhenAdvertised(t *testing.T) {
	f := newFakeConn()
	f.initResp = acpsdk.InitializeResponse{AgentCapabilities: acpsdk.AgentCapabilities{
		LoadSession:         true,
		SessionCapabilities: acpsdk.SessionCapabilities{Resume: &acpsdk.SessionResumeCapabilities{}},
	}}
	c := testCoordinatorWithConn(t, f, RealClock())
	profile := SessionProfile{Target: Target{URL: "ws://x"}}
	_, _, _, _, _, _, err := c.establishSession(context.Background(), nil, profile, "existing-session-id", func() {})
	if err != nil {
		t.Fatalf("establishSession: %v", err)
	}
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.resumeCalls != 1 {
		t.Fatalf("expected ResumeSession to be called once, got %d", f.resumeCalls)
	}
	if string(f.lastResumeSessionReq.SessionId) != "existing-session-id" {
		t.Fatalf("ResumeSession called with wrong session id: %q", f.lastResumeSessionReq.SessionId)
	}
}

func TestEstablishSessionFallsBackToLoadWhenResumeNotAdvertised(t *testing.T) {
	f := newFakeConn()
	c := testCoordinatorWithConn(t, f, RealClock())
	profile := SessionProfile{Target: Target{URL: "ws://x"}}
	_, _, _, _, _, _, err := c.establishSession(context.Background(), nil, profile, "existing-session-id", func() {})
	if err != nil {
		t.Fatalf("establishSession: %v", err)
	}
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.resumeCalls != 0 {
		t.Fatalf("expected ResumeSession NOT to be called, got %d calls", f.resumeCalls)
	}
	if string(f.lastLoadSessionReq.SessionId) != "existing-session-id" {
		t.Fatalf("expected LoadSession fallback, got %+v", f.lastLoadSessionReq)
	}
}
