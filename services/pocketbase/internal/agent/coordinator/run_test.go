package coordinator

import (
	"context"
	"encoding/json"
	"errors"
	"sync"
	"testing"

	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/acp"
)

func TestCancelForwardsToTheActiveSession(t *testing.T) {
	c, err := New(Config{GooseURL: "http://goose.test/acp", GooseSecret: "secret", Workspace: "/workspace"})
	if err != nil {
		t.Fatal(err)
	}
	client := &fakeACPClient{}
	if err := c.startRun("chat-1", "goose-session-1", client); err != nil {
		t.Fatal(err)
	}

	if err := c.Cancel(context.Background(), "chat-1"); err != nil {
		t.Fatal(err)
	}
	method, params, sessionID := client.notification()
	if method != "session/cancel" || sessionID != "goose-session-1" {
		t.Fatalf("cancel = %q for %q", method, sessionID)
	}
	if params["sessionId"] != "goose-session-1" {
		t.Fatalf("cancel params = %#v", params)
	}
}

func TestCancelRejectsWhenNoRunIsActive(t *testing.T) {
	c, err := New(Config{GooseURL: "http://goose.test/acp", GooseSecret: "secret", Workspace: "/workspace"})
	if err != nil {
		t.Fatal(err)
	}
	if err := c.Cancel(context.Background(), "chat-1"); !errors.Is(err, ErrNoActiveRun) {
		t.Fatalf("Cancel error = %v, want ErrNoActiveRun", err)
	}
}

func TestCancelRejectsAfterRunFinishes(t *testing.T) {
	c, err := New(Config{GooseURL: "http://goose.test/acp", GooseSecret: "secret", Workspace: "/workspace"})
	if err != nil {
		t.Fatal(err)
	}
	client := &fakeACPClient{}
	if err := c.startRun("chat-1", "goose-session-1", client); err != nil {
		t.Fatal(err)
	}
	c.finishRun("chat-1", client)
	if err := c.Cancel(context.Background(), "chat-1"); !errors.Is(err, ErrNoActiveRun) {
		t.Fatalf("Cancel error = %v, want ErrNoActiveRun", err)
	}
}

func TestApproveForwardsOnlyOfferedOptionAndIsMemoryOnly(t *testing.T) {
	c, err := New(Config{GooseURL: "http://goose.test/acp", GooseSecret: "secret", Workspace: "/workspace"})
	if err != nil {
		t.Fatal(err)
	}
	client := &fakeACPClient{}
	c.pending["approval-1"] = &pendingPermission{chatID: "chat-1", sessionID: "goose-1", rpcID: json.RawMessage("42"), options: map[string]struct{}{"allow_once": {}, "reject_once": {}}, client: client}
	if err := c.Approve(context.Background(), "chat-1", "approval-1", "allow_always"); !errors.Is(err, ErrPermissionOptionNotOffered) {
		t.Fatalf("Approve invalid = %v", err)
	}
	if err := c.Approve(context.Background(), "chat-1", "approval-1", "allow_once"); err != nil {
		t.Fatal(err)
	}
	if err := c.Approve(context.Background(), "chat-1", "approval-1", "allow_once"); !errors.Is(err, ErrNoPendingPermission) {
		t.Fatalf("Approve after forward = %v", err)
	}
	result, sessionID := client.response()
	if sessionID != "goose-1" || result["outcome"].(map[string]string)["optionId"] != "allow_once" {
		t.Fatalf("response=%#v session=%s", result, sessionID)
	}
}

func TestDenyForwardsAnOfferedRejectOption(t *testing.T) {
	c, err := New(Config{GooseURL: "http://goose.test/acp", GooseSecret: "secret", Workspace: "/workspace"})
	if err != nil {
		t.Fatal(err)
	}
	client := &fakeACPClient{}
	c.pending["approval-1"] = &pendingPermission{chatID: "chat-1", sessionID: "goose-1", rpcID: json.RawMessage("42"), options: map[string]struct{}{"reject_once": {}}, client: client}
	if err := c.Approve(context.Background(), "chat-1", "approval-1", "reject_once"); err != nil {
		t.Fatal(err)
	}
	result, _ := client.response()
	if result["outcome"].(map[string]string)["optionId"] != "reject_once" {
		t.Fatalf("deny response=%#v", result)
	}
}

func TestRestartHasNoPendingPermissions(t *testing.T) {
	fresh, err := New(Config{GooseURL: "http://goose.test/acp", GooseSecret: "secret", Workspace: "/workspace"})
	if err != nil {
		t.Fatal(err)
	}
	if err := fresh.Approve(context.Background(), "chat-1", "old-approval", "allow_once"); !errors.Is(err, ErrNoPendingPermission) {
		t.Fatalf("restart approval = %v", err)
	}
}

func TestCancelResolvesPendingPermissionAsCancelled(t *testing.T) {
	c, err := New(Config{GooseURL: "http://goose.test/acp", GooseSecret: "secret", Workspace: "/workspace"})
	if err != nil {
		t.Fatal(err)
	}
	client := &fakeACPClient{}
	if err := c.startRun("chat-1", "goose-1", client); err != nil {
		t.Fatal(err)
	}
	c.pending["approval-1"] = &pendingPermission{chatID: "chat-1", sessionID: "goose-1", rpcID: json.RawMessage("42"), options: map[string]struct{}{"allow_once": {}}, client: client}
	if err := c.Cancel(context.Background(), "chat-1"); err != nil {
		t.Fatal(err)
	}
	result, _ := client.response()
	if result["outcome"].(map[string]string)["outcome"] != "cancelled" {
		t.Fatalf("cancel response=%#v", result)
	}
}

type fakeACPClient struct {
	mu              sync.Mutex
	method          string
	params          map[string]string
	sessionID       string
	responseValue   any
	responseSession string
}

func (c *fakeACPClient) Initialize(context.Context, any) (json.RawMessage, error) { return nil, nil }
func (c *fakeACPClient) OnNotification(acp.NotificationHandler)                   {}
func (c *fakeACPClient) OpenStream(context.Context, string) error                 { return nil }
func (c *fakeACPClient) Call(context.Context, string, any, string) (json.RawMessage, error) {
	return nil, nil
}
func (c *fakeACPClient) Notify(_ context.Context, method string, value any, sessionID string) error {
	params, ok := value.(map[string]string)
	if !ok {
		return errors.New("unexpected cancel params")
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	c.method = method
	c.params = params
	c.sessionID = sessionID
	return nil
}
func (c *fakeACPClient) Respond(_ context.Context, _ json.RawMessage, value any, sessionID string) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.responseValue = value
	c.responseSession = sessionID
	return nil
}
func (c *fakeACPClient) RespondError(context.Context, json.RawMessage, int, string, string) error {
	return nil
}

func (c *fakeACPClient) response() (map[string]any, string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.responseValue.(map[string]any), c.responseSession
}

func (c *fakeACPClient) notification() (string, map[string]string, string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.method, c.params, c.sessionID
}
