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

type fakeACPClient struct {
	mu        sync.Mutex
	method    string
	params    map[string]string
	sessionID string
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

func (c *fakeACPClient) notification() (string, map[string]string, string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.method, c.params, c.sessionID
}
