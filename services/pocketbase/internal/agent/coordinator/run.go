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
	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/executor"
)

type Config struct {
	GooseURL    string
	GooseSecret string
	Workspace   string
	SandboxURL  string
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
	pending   map[string]*pendingPermission
}

// ErrNoActiveRun means there is no in-process prompt to cancel. Goose remains
// authoritative for completed turns; c1 deliberately does not reconstruct
// active work from persisted state after a restart.
var ErrNoActiveRun = errors.New("no active run")
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
	if config.GooseURL == "" || config.GooseSecret == "" || config.Workspace == "" || config.SandboxURL == "" {
		return nil, fmt.Errorf("GOOSE_ACP_URL, GOOSE_SERVER__SECRET_KEY, GOOSE_WORKSPACE, and SANDBOX_PROXY_URL are required")
	}
	return &Coordinator{
		config:    config,
		locks:     make(map[string]*sync.Mutex),
		activeRun: make(map[string]*activeRun),
		pending:   make(map[string]*pendingPermission),
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
	sandbox, err := executor.New(executor.Config{URL: c.config.SandboxURL, Workspace: c.config.Workspace})
	if err != nil {
		return err
	}
	if _, err := client.Initialize(ctx, executor.Capabilities()); err != nil {
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
		if len(message.ID) != 0 && acceptingUpdates.Load() {
			go c.handleCallback(context.Background(), request.ChatID, sessionID, client, sandbox, bridge, emitLocked, message)
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

func (c *Coordinator) handleCallback(ctx context.Context, chatID, sessionID string, client acpClient, sandbox *executor.Sandbox, bridge *agui.Bridge, emit Emit, message acp.Message) {
	respond := func(result any, err error) {
		if err != nil {
			_ = client.RespondError(ctx, message.ID, -32000, err.Error(), sessionID)
			return
		}
		_ = client.Respond(ctx, message.ID, result, sessionID)
	}
	switch message.Method {
	case "fs/read_text_file":
		var request acpsdk.ReadTextFileRequest
		if err := json.Unmarshal(message.Params, &request); err != nil {
			respond(nil, err)
			return
		}
		result, err := sandbox.ReadTextFile(ctx, request)
		respond(result, err)
	case "fs/write_text_file":
		var request acpsdk.WriteTextFileRequest
		if err := json.Unmarshal(message.Params, &request); err != nil {
			respond(nil, err)
			return
		}
		result, err := sandbox.WriteTextFile(ctx, request)
		respond(result, err)
	case "terminal/create":
		var request acpsdk.CreateTerminalRequest
		if err := json.Unmarshal(message.Params, &request); err != nil {
			respond(nil, err)
			return
		}
		result, err := sandbox.CreateTerminal(ctx, request)
		respond(result, err)
	case "terminal/output":
		var request acpsdk.TerminalOutputRequest
		if err := json.Unmarshal(message.Params, &request); err != nil {
			respond(nil, err)
			return
		}
		result, err := sandbox.TerminalOutput(ctx, request)
		respond(result, err)
	case "terminal/wait_for_exit":
		var request acpsdk.WaitForTerminalExitRequest
		if err := json.Unmarshal(message.Params, &request); err != nil {
			respond(nil, err)
			return
		}
		result, err := sandbox.WaitForTerminalExit(ctx, request)
		respond(result, err)
	case "terminal/kill":
		var request acpsdk.KillTerminalRequest
		if err := json.Unmarshal(message.Params, &request); err != nil {
			respond(nil, err)
			return
		}
		result, err := sandbox.KillTerminal(ctx, request)
		respond(result, err)
	case "terminal/release":
		var request acpsdk.ReleaseTerminalRequest
		if err := json.Unmarshal(message.Params, &request); err != nil {
			respond(nil, err)
			return
		}
		result, err := sandbox.ReleaseTerminal(ctx, request)
		respond(result, err)
	case "session/request_permission":
		var permission acpsdk.RequestPermissionRequest
		if err := json.Unmarshal(message.Params, &permission); err != nil {
			respond(nil, err)
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
	default:
		_ = client.RespondError(ctx, message.ID, -32601, "unsupported ACP client callback", sessionID)
	}
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
