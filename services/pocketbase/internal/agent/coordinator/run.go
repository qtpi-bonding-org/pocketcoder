// Package coordinator composes the private Goose ACP client and the
// frontend-facing AG-UI bridge for one authenticated PocketBase chat run.
package coordinator

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"sync"
	"sync/atomic"

	"github.com/ag-ui-protocol/ag-ui/sdks/community/go/pkg/core/events"
	acpsdk "github.com/coder/acp-go-sdk"
	"github.com/google/uuid"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/acp"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/agui"
)

type Config struct {
	GooseURL    string
	GooseSecret string
	Workspace   string
}

type RunRequest struct {
	ChatID string
	Prompt string
}

type Emit func(events.Event) error

// ResolveSession reads the durable chat-to-Goose mapping while the per-chat
// first-run lock is held.
type ResolveSession func(context.Context) (string, error)

// OnSessionCreated persists just the chat-to-Goose session mapping before the
// first prompt is issued. It must not persist messages, events, or approvals.
type OnSessionCreated func(context.Context, string) error

type Coordinator struct {
	config    Config
	mu        sync.Mutex
	locks     map[string]*sync.Mutex
	activeRun map[string]*activeRun
}

// ErrNoActiveRun means there is no in-process prompt to cancel. Goose remains
// authoritative for completed turns; c1 deliberately does not reconstruct
// active work from persisted state after a restart.
var ErrNoActiveRun = errors.New("no active run")

type acpClient interface {
	Initialize(context.Context, any) (json.RawMessage, error)
	OnNotification(acp.NotificationHandler)
	OpenStream(context.Context, string) error
	Call(context.Context, string, any, string) (json.RawMessage, error)
	Notify(context.Context, string, any, string) error
}

type activeRun struct {
	sessionID string
	client    acpClient
}

func New(config Config) (*Coordinator, error) {
	if config.GooseURL == "" || config.GooseSecret == "" || config.Workspace == "" {
		return nil, fmt.Errorf("GOOSE_ACP_URL, GOOSE_SERVER__SECRET_KEY, and GOOSE_WORKSPACE are required")
	}
	return &Coordinator{
		config:    config,
		locks:     make(map[string]*sync.Mutex),
		activeRun: make(map[string]*activeRun),
	}, nil
}

// Cancel forwards cancellation only to a currently active prompt for the
// chat. The run goroutine still waits for Goose's matching session/prompt
// response and emits the terminal AG-UI events itself.
func (c *Coordinator) Cancel(ctx context.Context, chatID string) error {
	c.mu.Lock()
	run := c.activeRun[chatID]
	c.mu.Unlock()
	if run == nil {
		return ErrNoActiveRun
	}
	return run.client.Notify(ctx, "session/cancel", map[string]string{
		"sessionId": run.sessionID,
	}, run.sessionID)
}

// Run creates or reloads the one Goose session for a chat, then emits AG-UI
// lifecycle events until the correlated session/prompt response arrives.
func (c *Coordinator) Run(ctx context.Context, request RunRequest, emit Emit, resolveSession ResolveSession, onSessionCreated OnSessionCreated) error {
	// A first run has no persisted mapping yet. Serialize it per chat so two
	// simultaneous requests cannot create two Goose sessions for one chat.
	lock := c.chatLock(request.ChatID)
	lock.Lock()
	defer lock.Unlock()

	sessionID, err := resolveSession(ctx)
	if err != nil {
		return fmt.Errorf("load Goose session mapping: %w", err)
	}
	client, err := acp.NewClient(acp.Config{URL: c.config.GooseURL, Secret: c.config.GooseSecret})
	if err != nil {
		return err
	}
	if _, err := client.Initialize(ctx, map[string]any{}); err != nil {
		return err
	}
	if err := client.OpenStream(ctx, ""); err != nil {
		return err
	}

	bridge := agui.NewBridge(request.ChatID, uuid.NewString())
	var emitMu sync.Mutex
	emitLocked := func(event events.Event) error {
		emitMu.Lock()
		defer emitMu.Unlock()
		return emit(event)
	}

	var acceptingUpdates atomic.Bool
	client.OnNotification(func(message acp.Message) {
		if message.Method != "session/update" || !acceptingUpdates.Load() {
			return
		}
		var notification acpsdk.SessionNotification
		if err := json.Unmarshal(message.Params, &notification); err != nil {
			return
		}
		emitMu.Lock()
		defer emitMu.Unlock()
		updates, err := bridge.Update(notification.Update)
		if err != nil {
			return
		}
		for _, event := range updates {
			if emit(event) != nil {
				return
			}
		}
	})

	hadSession := sessionID != ""
	if sessionID == "" {
		result, err := client.Call(ctx, "session/new", map[string]any{
			"cwd":        c.config.Workspace,
			"mcpServers": []any{}, // Gateway MCP/Cognee stays disabled until its attachment is proven.
		}, "")
		if err != nil {
			return err
		}
		var created struct {
			SessionID string `json:"sessionId"`
		}
		if err := json.Unmarshal(result, &created); err != nil {
			return fmt.Errorf("decode session/new response: %w", err)
		}
		if created.SessionID == "" {
			return fmt.Errorf("session/new response missing sessionId")
		}
		sessionID = created.SessionID
		if err := onSessionCreated(ctx, sessionID); err != nil {
			return fmt.Errorf("persist Goose session mapping: %w", err)
		}
	}
	if err := client.OpenStream(ctx, sessionID); err != nil {
		return err
	}
	if hadSession {
		// Goose replays history during load. It is already authoritative in c2 and
		// must not be copied into this run's frontend stream.
		if _, err := client.Call(ctx, "session/load", map[string]any{
			"sessionId":  sessionID,
			"cwd":        c.config.Workspace,
			"mcpServers": []any{},
		}, sessionID); err != nil {
			return err
		}
	}
	acceptingUpdates.Store(true)
	if err := emitLocked(bridge.Started()); err != nil {
		return err
	}
	if err := c.startRun(request.ChatID, sessionID, client); err != nil {
		return err
	}
	defer c.finishRun(request.ChatID, client)
	if _, err := client.Call(ctx, "session/prompt", map[string]any{
		"sessionId": sessionID,
		"prompt":    []map[string]string{{"type": "text", "text": request.Prompt}},
	}, sessionID); err != nil {
		return err
	}

	emitMu.Lock()
	defer emitMu.Unlock()
	for _, event := range bridge.Finished() {
		if err := emit(event); err != nil {
			return err
		}
	}
	return nil
}

func (c *Coordinator) startRun(chatID, sessionID string, client acpClient) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.activeRun[chatID] != nil {
		return fmt.Errorf("chat already has an active run")
	}
	c.activeRun[chatID] = &activeRun{sessionID: sessionID, client: client}
	return nil
}

func (c *Coordinator) finishRun(chatID string, client acpClient) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if run := c.activeRun[chatID]; run != nil && run.client == client {
		delete(c.activeRun, chatID)
	}
}

func (c *Coordinator) chatLock(chatID string) *sync.Mutex {
	c.mu.Lock()
	defer c.mu.Unlock()
	lock := c.locks[chatID]
	if lock == nil {
		lock = &sync.Mutex{}
		c.locks[chatID] = lock
	}
	return lock
}
