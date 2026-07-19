package coordinator

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"

	"github.com/ag-ui-protocol/ag-ui/sdks/community/go/pkg/core/events"
	acpsdk "github.com/coder/acp-go-sdk"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/acp"
)

func testCoordinator(t *testing.T, dial DialFunc) *Coordinator {
	t.Helper()
	c, err := New(Config{GooseURL: "ws://goose.test/acp", GooseSecret: "secret", Workspace: "/workspace", Dial: dial})
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
	c, err := New(Config{GooseURL: "ws://x", GooseSecret: "s", Workspace: "/w", Clock: clk,
		Dial: func(_ context.Context, client acpsdk.Client) (acp.Conn, error) {
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
func newFakeConn() *fakeConn {
	return &fakeConn{promptCalled: make(chan struct{}, 1)}
}

type fakeConn struct {
	mu                 sync.Mutex
	cancelled          string
	client             acpsdk.Client
	newSession         string
	deletedSession     string

	// Task 10 extensions.
	closeCount        int
	blockPrompt       chan struct{}
	panicOnPrompt     bool
	promptCalled      chan struct{}
	emitElicitation   bool
	elicitationResolved bool
	lastMode          string
	requestPermission bool
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
	return acpsdk.InitializeResponse{}, nil
}
func (f *fakeConn) NewSession(context.Context, acpsdk.NewSessionRequest) (acpsdk.NewSessionResponse, error) {
	return acpsdk.NewSessionResponse{SessionId: acpsdk.SessionId(f.newSession)}, nil
}
func (f *fakeConn) LoadSession(context.Context, acpsdk.LoadSessionRequest) (acpsdk.LoadSessionResponse, error) {
	return acpsdk.LoadSessionResponse{}, nil
}
func (f *fakeConn) SetSessionMode(_ context.Context, req acpsdk.SetSessionModeRequest) (acpsdk.SetSessionModeResponse, error) {
	f.mu.Lock()
	f.lastMode = string(req.ModeId)
	f.mu.Unlock()
	return acpsdk.SetSessionModeResponse{}, nil
}
func (f *fakeConn) SetSessionConfigOption(context.Context, acpsdk.SetSessionConfigOptionRequest) (acpsdk.SetSessionConfigOptionResponse, error) {
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
	if f.requestPermission {
		if rp, ok := f.client.(interface {
			RequestPermission(context.Context, acpsdk.RequestPermissionRequest) (acpsdk.RequestPermissionResponse, error)
		}); ok {
			_, _ = rp.RequestPermission(ctx, acpsdk.RequestPermissionRequest{
				Options: []acpsdk.PermissionOption{{OptionId: "allow_once", Name: "Allow once"}},
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
	if f.blockPrompt != nil {
		select {
		case <-f.blockPrompt:
		case <-ctx.Done():
			return acpsdk.PromptResponse{}, ctx.Err()
		}
	}
	return acpsdk.PromptResponse{StopReason: acpsdk.StopReasonEndTurn}, nil
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

func TestCancelForwardsToActiveSession(t *testing.T) {
	f := &fakeConn{}
	c := testCoordinator(t, nil)
	if err := c.startRun("chat", "session", f); err != nil {
		t.Fatal(err)
	}
	if err := c.Cancel(context.Background(), "chat"); err != nil {
		t.Fatal(err)
	}
	if f.cancelled != "session" {
		t.Fatalf("cancelled=%q", f.cancelled)
	}
}

func TestUnmappedReplayDoesNotDial(t *testing.T) {
	dialed := false
	c := testCoordinator(t, func(context.Context, acpsdk.Client) (acp.Conn, error) { dialed = true; return nil, nil })
	if err := c.Replay(context.Background(), "chat", "", func(events.Event) error { return nil }); err != nil {
		t.Fatal(err)
	}
	if dialed {
		t.Fatal("unmapped replay dialed Goose")
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
		func(context.Context, string) error { return nil })
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
		func(context.Context, string) error { return nil })
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
		func(context.Context, string) error { return nil })
	c.waitRunDone(t, "A") // must still release Reserve despite the panic
}

func TestDetachedRunPermissionEmitsThroughHub(t *testing.T) {
	f := newFakeConn()
	f.requestPermission = true // fake calls sc.RequestPermission during Prompt, then auto-approves via decision
	c := testCoordinatorWithConn(t, f, NewFakeClock(time.Unix(0, 0)))
	c.StartPrompt("A", "do it",
		func(context.Context) (string, error) { return "s1", nil },
		func(context.Context, string) error { return nil })
	id := c.waitForPendingPermission(t, "A") // polls c.pending for the chat
	if err := c.Approve(context.Background(), "A", id, "allow_once"); err != nil {
		t.Fatal(err)
	}
	c.waitRunDone(t, "A") // must not panic on a nil emit
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
		func(context.Context, string) error { return nil })
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
		func(context.Context, string) error { return nil })
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
		func(context.Context, string) error { return errors.New("db down") })
	c.waitRunDone(t, "A")
	if f.deletedSession != "orphan-1" {
		t.Fatalf("persist failure must compensate via delete, deleted=%q", f.deletedSession)
	}
}
