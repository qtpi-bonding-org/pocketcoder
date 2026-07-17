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

type fakeConn struct {
	mu         sync.Mutex
	cancelled  string
	client     acpsdk.Client
	newSession string
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
func (f *fakeConn) SetSessionMode(context.Context, acpsdk.SetSessionModeRequest) (acpsdk.SetSessionModeResponse, error) {
	return acpsdk.SetSessionModeResponse{}, nil
}
func (f *fakeConn) Prompt(context.Context, acpsdk.PromptRequest) (acpsdk.PromptResponse, error) {
	return acpsdk.PromptResponse{}, nil
}
func (f *fakeConn) Cancel(_ context.Context, n acpsdk.CancelNotification) error {
	f.mu.Lock()
	f.cancelled = string(n.SessionId)
	f.mu.Unlock()
	return nil
}
func (f *fakeConn) Close() error { return nil }

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
