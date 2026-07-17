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
	"time"

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
	running   map[string]struct{}
	activeRun map[string]*activeRun
	pending   map[string]*pendingPermission
}

// ErrNoActiveRun means there is no in-process prompt to cancel. Goose remains
// authoritative for completed turns; c1 deliberately does not reconstruct
// active work from persisted state after a restart.
var ErrNoActiveRun = errors.New("no active run")
var ErrRunInProgress = errors.New("chat already has an active run")
var ErrNoPendingPermission = errors.New("no pending permission")
var ErrPermissionOptionNotOffered = errors.New("permission option was not offered")

type acpClient interface {
	Initialize(context.Context, any) (json.RawMessage, error)
	OnNotification(acp.NotificationHandler)
	OpenStream(context.Context, string) error
	Call(context.Context, string, any, string) (json.RawMessage, error)
	Notify(context.Context, string, any, string) error
	Respond(context.Context, json.RawMessage, any, string) error
	RespondError(context.Context, json.RawMessage, int, string, string) error
}

type pendingPermission struct {
	chatID, sessionID string
	rpcID             json.RawMessage
	options           map[string]struct{}
	client            acpClient
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
		running:   make(map[string]struct{}),
		activeRun: make(map[string]*activeRun),
		pending:   make(map[string]*pendingPermission),
	}, nil
}

// Reserve claims the single in-process run slot for a chat. It is separate
// from RunReserved so the HTTP route can return a proper 409 before it starts
// an SSE response.
func (c *Coordinator) Reserve(chatID string) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	if _, exists := c.running[chatID]; exists {
		return ErrRunInProgress
	}
	c.running[chatID] = struct{}{}
	return nil
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
	if err := run.client.Notify(ctx, "session/cancel", map[string]string{
		"sessionId": run.sessionID,
	}, run.sessionID); err != nil {
		return err
	}
	// A pending callback is memory-only. Resolve it as cancelled so Goose does
	// not remain blocked when cancellation races with the phone decision.
	c.mu.Lock()
	var pending *pendingPermission
	for id, value := range c.pending {
		if value.chatID == chatID {
			pending = value
			delete(c.pending, id)
			break
		}
	}
	c.mu.Unlock()
	if pending != nil {
		return pending.client.Respond(ctx, pending.rpcID, map[string]any{"outcome": map[string]string{"outcome": "cancelled"}}, pending.sessionID)
	}
	return nil
}

// Approve forwards only an option Goose offered for this in-process request.
// The map is deliberately lost on c1 restart and is never persisted.
func (c *Coordinator) Approve(ctx context.Context, chatID, requestID, optionID string) error {
	c.mu.Lock()
	pending := c.pending[requestID]
	if pending == nil || pending.chatID != chatID {
		c.mu.Unlock()
		return ErrNoPendingPermission
	}
	if _, ok := pending.options[optionID]; !ok {
		c.mu.Unlock()
		return ErrPermissionOptionNotOffered
	}
	delete(c.pending, requestID)
	c.mu.Unlock()
	return pending.client.Respond(ctx, pending.rpcID, map[string]any{"outcome": map[string]string{"outcome": "selected", "optionId": optionID}}, pending.sessionID)
}

// Run creates or reloads the one Goose session for a chat, then emits AG-UI
// lifecycle events until the correlated session/prompt response arrives.
func (c *Coordinator) Run(ctx context.Context, request RunRequest, emit Emit, resolveSession ResolveSession, onSessionCreated OnSessionCreated) error {
	if err := c.Reserve(request.ChatID); err != nil {
		return err
	}
	return c.RunReserved(ctx, request, emit, resolveSession, onSessionCreated)
}

// RunReserved runs a chat after Reserve has claimed its slot. The route uses
// this form to make concurrent-request rejection an HTTP 409 rather than an
// SSE error event.
func (c *Coordinator) RunReserved(ctx context.Context, request RunRequest, emit Emit, resolveSession ResolveSession, onSessionCreated OnSessionCreated) error {
	defer c.release(request.ChatID)

	sessionID, err := resolveSession(ctx)
	if err != nil {
		return fmt.Errorf("load Goose session mapping: %w", err)
	}
	client, err := acp.NewClient(acp.Config{URL: c.config.GooseURL, Secret: c.config.GooseSecret})
	if err != nil {
		return err
	}
	// Goose owns execution in c2 for the selected simplified runtime. Do not
	// advertise ACP filesystem/terminal callbacks: Goose's built-in shell does
	// not use them, and c1 must not imply a sandbox boundary it does not enforce.
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
		if message.Method == "session/update" && acceptingUpdates.Load() {
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
			return
		}
		if message.Method == "session/request_permission" && len(message.ID) != 0 && acceptingUpdates.Load() {
			go c.handlePermissionRequest(context.Background(), request.ChatID, sessionID, client, bridge, emitLocked, message)
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
	// Goose's approve mode makes developer filesystem/terminal work stop at the
	// permission callback instead of silently applying it in c2.
	if _, err := client.Call(ctx, "session/set_mode", map[string]string{"sessionId": sessionID, "modeId": "approve"}, sessionID); err != nil {
		return err
	}
	acceptingUpdates.Store(true)
	if err := emitLocked(bridge.Started()); err != nil {
		return err
	}
	if err := c.startRun(request.ChatID, sessionID, client); err != nil {
		return err
	}
	defer c.finishRun(request.ChatID, client)
	defer c.dropPendingForChat(request.ChatID)
	if _, err := client.Call(ctx, "session/prompt", map[string]any{
		"sessionId": sessionID,
		"prompt":    []map[string]string{{"type": "text", "text": request.Prompt}},
	}, sessionID); err != nil {
		c.cancelOnClientDisconnect(ctx, request.ChatID)
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

func (c *Coordinator) cancelOnClientDisconnect(ctx context.Context, chatID string) {
	if !errors.Is(ctx.Err(), context.Canceled) && !errors.Is(ctx.Err(), context.DeadlineExceeded) {
		return
	}
	cancelCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_ = c.Cancel(cancelCtx, chatID)
}

func (c *Coordinator) release(chatID string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	delete(c.running, chatID)
}

func (c *Coordinator) handlePermissionRequest(ctx context.Context, chatID, sessionID string, client acpClient, bridge *agui.Bridge, emit Emit, message acp.Message) {
	var permission acpsdk.RequestPermissionRequest
	if err := json.Unmarshal(message.Params, &permission); err != nil {
		_ = client.RespondError(ctx, message.ID, -32602, "invalid permission request", sessionID)
		return
	}
	id := uuid.NewString()
	options := make(map[string]struct{}, len(permission.Options))
	for _, option := range permission.Options {
		options[string(option.OptionId)] = struct{}{}
	}
	c.mu.Lock()
	c.pending[id] = &pendingPermission{chatID: chatID, sessionID: sessionID, rpcID: message.ID, options: options, client: client}
	c.mu.Unlock()
	_ = emit(bridge.PermissionPending(id, permission.Options))
}

func (c *Coordinator) dropPendingForChat(chatID string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	for id, pending := range c.pending {
		if pending.chatID == chatID {
			delete(c.pending, id)
		}
	}
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
