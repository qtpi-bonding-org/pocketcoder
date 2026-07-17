package coordinator

import (
	"context"
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
	GooseURL, GooseSecret, Workspace string
	PermissionTimeout                time.Duration
	Dial                             DialFunc
}
type RunRequest struct{ ChatID, Prompt string }
type Emit func(events.Event) error
type ResolveSession func(context.Context) (string, error)
type OnSessionCreated func(context.Context, string) error
type DialFunc func(context.Context, acpsdk.Client) (acp.Conn, error)

type Coordinator struct {
	config    Config
	mu        sync.Mutex
	running   map[string]struct{}
	activeRun map[string]*activeRun
	pending   map[string]*pendingPermission
}
type activeRun struct {
	sessionID string
	conn      acp.Conn
}
type pendingPermission struct {
	chatID, sessionID string
	options           map[string]struct{}
	decision          chan permissionDecision
	timer             *time.Timer
}
type permissionDecision struct {
	option    string
	cancelled bool
}

var ErrNoActiveRun = errors.New("no active run")
var ErrRunInProgress = errors.New("chat already has an active run")
var ErrNoPendingPermission = errors.New("no pending permission")
var ErrPermissionOptionNotOffered = errors.New("permission option was not offered")

func New(config Config) (*Coordinator, error) {
	if config.GooseURL == "" || config.GooseSecret == "" || config.Workspace == "" {
		return nil, fmt.Errorf("GOOSE_ACP_URL, GOOSE_SERVER__SECRET_KEY, and GOOSE_WORKSPACE are required")
	}
	if config.Dial == nil {
		config.Dial = func(ctx context.Context, client acpsdk.Client) (acp.Conn, error) {
			return acp.Dial(ctx, acp.DialConfig{URL: config.GooseURL, Secret: config.GooseSecret}, client)
		}
	}
	return &Coordinator{config: config, running: map[string]struct{}{}, activeRun: map[string]*activeRun{}, pending: map[string]*pendingPermission{}}, nil
}

func (c *Coordinator) Reserve(chatID string) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	if _, ok := c.running[chatID]; ok {
		return ErrRunInProgress
	}
	c.running[chatID] = struct{}{}
	return nil
}
func (c *Coordinator) release(chatID string) { c.mu.Lock(); delete(c.running, chatID); c.mu.Unlock() }

func (c *Coordinator) Cancel(ctx context.Context, chatID string) error {
	c.mu.Lock()
	run := c.activeRun[chatID]
	var p *pendingPermission
	for id, v := range c.pending {
		if v.chatID == chatID {
			p = v
			delete(c.pending, id)
			if v.timer != nil {
				v.timer.Stop()
			}
			break
		}
	}
	c.mu.Unlock()
	if run == nil {
		return ErrNoActiveRun
	}
	if err := run.conn.Cancel(ctx, acpsdk.CancelNotification{SessionId: acpsdk.SessionId(run.sessionID)}); err != nil {
		return err
	}
	if p != nil {
		select {
		case p.decision <- permissionDecision{cancelled: true}:
		default:
		}
	}
	return nil
}

func (c *Coordinator) Approve(_ context.Context, chatID, requestID, optionID string) error {
	c.mu.Lock()
	p := c.pending[requestID]
	if p == nil || p.chatID != chatID {
		c.mu.Unlock()
		return ErrNoPendingPermission
	}
	if _, ok := p.options[optionID]; !ok {
		c.mu.Unlock()
		return ErrPermissionOptionNotOffered
	}
	delete(c.pending, requestID)
	if p.timer != nil {
		p.timer.Stop()
	}
	c.mu.Unlock()
	select {
	case p.decision <- permissionDecision{option: optionID}:
	default:
	}
	return nil
}

type sessionClient struct {
	c                 *Coordinator
	chatID, sessionID string
	bridge            *agui.Bridge
	emit              Emit
	accepting         atomic.Bool
	emitMu            sync.Mutex
}

func (s *sessionClient) SessionUpdate(_ context.Context, n acpsdk.SessionNotification) error {
	if !s.accepting.Load() {
		return nil
	}
	s.emitMu.Lock()
	defer s.emitMu.Unlock()
	updates, err := s.bridge.Update(n.Update)
	if err != nil {
		return err
	}
	for _, e := range updates {
		if err := s.emit(e); err != nil {
			return err
		}
	}
	return nil
}
func unsupported() error {
	return errors.New("c1 does not provide filesystem or terminal capabilities")
}
func (s *sessionClient) ReadTextFile(context.Context, acpsdk.ReadTextFileRequest) (acpsdk.ReadTextFileResponse, error) {
	return acpsdk.ReadTextFileResponse{}, unsupported()
}
func (s *sessionClient) WriteTextFile(context.Context, acpsdk.WriteTextFileRequest) (acpsdk.WriteTextFileResponse, error) {
	return acpsdk.WriteTextFileResponse{}, unsupported()
}
func (s *sessionClient) CreateTerminal(context.Context, acpsdk.CreateTerminalRequest) (acpsdk.CreateTerminalResponse, error) {
	return acpsdk.CreateTerminalResponse{}, unsupported()
}
func (s *sessionClient) KillTerminal(context.Context, acpsdk.KillTerminalRequest) (acpsdk.KillTerminalResponse, error) {
	return acpsdk.KillTerminalResponse{}, unsupported()
}
func (s *sessionClient) TerminalOutput(context.Context, acpsdk.TerminalOutputRequest) (acpsdk.TerminalOutputResponse, error) {
	return acpsdk.TerminalOutputResponse{}, unsupported()
}
func (s *sessionClient) ReleaseTerminal(context.Context, acpsdk.ReleaseTerminalRequest) (acpsdk.ReleaseTerminalResponse, error) {
	return acpsdk.ReleaseTerminalResponse{}, unsupported()
}
func (s *sessionClient) WaitForTerminalExit(context.Context, acpsdk.WaitForTerminalExitRequest) (acpsdk.WaitForTerminalExitResponse, error) {
	return acpsdk.WaitForTerminalExitResponse{}, unsupported()
}

func (s *sessionClient) RequestPermission(ctx context.Context, req acpsdk.RequestPermissionRequest) (acpsdk.RequestPermissionResponse, error) {
	id := uuid.NewString()
	options := map[string]struct{}{}
	for _, o := range req.Options {
		options[string(o.OptionId)] = struct{}{}
	}
	p := &pendingPermission{chatID: s.chatID, sessionID: s.sessionID, options: options, decision: make(chan permissionDecision, 1)}
	s.c.mu.Lock()
	s.c.pending[id] = p
	s.c.mu.Unlock()
	if s.c.config.PermissionTimeout > 0 {
		p.timer = time.AfterFunc(s.c.config.PermissionTimeout, func() { s.resolveExpired(id, p) })
	}
	s.emitMu.Lock()
	_ = s.emit(s.bridge.PermissionPending(id, req.Options))
	s.emitMu.Unlock()
	select {
	case d := <-p.decision:
		if d.cancelled {
			return acpsdk.RequestPermissionResponse{Outcome: acpsdk.RequestPermissionOutcome{Cancelled: &acpsdk.RequestPermissionOutcomeCancelled{Outcome: "cancelled"}}}, nil
		}
		return acpsdk.RequestPermissionResponse{Outcome: acpsdk.RequestPermissionOutcome{Selected: &acpsdk.RequestPermissionOutcomeSelected{Outcome: "selected", OptionId: acpsdk.PermissionOptionId(d.option)}}}, nil
	case <-ctx.Done():
		s.removePending(id, p)
		return acpsdk.RequestPermissionResponse{Outcome: acpsdk.RequestPermissionOutcome{Cancelled: &acpsdk.RequestPermissionOutcomeCancelled{Outcome: "cancelled"}}}, nil
	}
}
func (s *sessionClient) removePending(id string, expected *pendingPermission) {
	s.c.mu.Lock()
	if s.c.pending[id] == expected {
		delete(s.c.pending, id)
	}
	s.c.mu.Unlock()
	if expected.timer != nil {
		expected.timer.Stop()
	}
}
func (s *sessionClient) resolveExpired(id string, expected *pendingPermission) {
	s.removePending(id, expected)
	select {
	case expected.decision <- permissionDecision{cancelled: true}:
	default:
	}
}

func (c *Coordinator) Replay(ctx context.Context, chatID, sessionID string, emit Emit) error {
	if err := c.Reserve(chatID); err != nil {
		return err
	}
	return c.ReplayReserved(ctx, chatID, sessionID, emit)
}
func (c *Coordinator) ReplayReserved(ctx context.Context, chatID, sessionID string, emit Emit) error {
	defer c.release(chatID)
	bridge := agui.NewBridge(chatID, uuid.NewString())
	if err := emit(bridge.Started()); err != nil {
		return err
	}
	if sessionID == "" {
		return emitAll(emit, bridge.Finished())
	}
	sc := &sessionClient{c: c, chatID: chatID, sessionID: sessionID, bridge: bridge, emit: emit}
	conn, err := c.config.Dial(ctx, sc)
	if err != nil {
		return err
	}
	defer conn.Close()
	if _, err = conn.Initialize(ctx, initializeRequest()); err != nil {
		return err
	}
	sc.accepting.Store(true)
	if _, err = conn.LoadSession(ctx, acpsdk.LoadSessionRequest{SessionId: acpsdk.SessionId(sessionID), Cwd: c.config.Workspace, McpServers: []acpsdk.McpServer{}}); err != nil {
		return fmt.Errorf("load Goose session: %w", err)
	}
	return emitAll(emit, bridge.Finished())
}
func initializeRequest() acpsdk.InitializeRequest {
	return acpsdk.InitializeRequest{ProtocolVersion: acpsdk.ProtocolVersionNumber, ClientCapabilities: acpsdk.ClientCapabilities{}}
}
func emitAll(emit Emit, values []events.Event) error {
	for _, v := range values {
		if err := emit(v); err != nil {
			return err
		}
	}
	return nil
}

func (c *Coordinator) Run(ctx context.Context, req RunRequest, emit Emit, resolve ResolveSession, created OnSessionCreated) error {
	if err := c.Reserve(req.ChatID); err != nil {
		return err
	}
	return c.RunReserved(ctx, req, emit, resolve, created)
}
func (c *Coordinator) RunReserved(ctx context.Context, req RunRequest, emit Emit, resolve ResolveSession, created OnSessionCreated) error {
	defer c.release(req.ChatID)
	sessionID, err := resolve(ctx)
	if err != nil {
		return fmt.Errorf("load Goose session mapping: %w", err)
	}
	had := sessionID != ""
	bridge := agui.NewBridge(req.ChatID, uuid.NewString())
	sc := &sessionClient{c: c, chatID: req.ChatID, sessionID: sessionID, bridge: bridge, emit: emit}
	conn, err := c.config.Dial(ctx, sc)
	if err != nil {
		return err
	}
	defer conn.Close()
	if _, err = conn.Initialize(ctx, initializeRequest()); err != nil {
		return err
	}
	if !had {
		result, e := conn.NewSession(ctx, acpsdk.NewSessionRequest{Cwd: c.config.Workspace, McpServers: []acpsdk.McpServer{}})
		if e != nil {
			return e
		}
		sessionID = string(result.SessionId)
		if sessionID == "" {
			return errors.New("session/new response missing sessionId")
		}
		sc.sessionID = sessionID
		if e = created(ctx, sessionID); e != nil {
			return fmt.Errorf("persist Goose session mapping: %w", e)
		}
	} else {
		if _, err = conn.LoadSession(ctx, acpsdk.LoadSessionRequest{SessionId: acpsdk.SessionId(sessionID), Cwd: c.config.Workspace, McpServers: []acpsdk.McpServer{}}); err != nil {
			return err
		}
	}
	if _, err = conn.SetSessionMode(ctx, acpsdk.SetSessionModeRequest{SessionId: acpsdk.SessionId(sessionID), ModeId: acpsdk.SessionModeId("approve")}); err != nil {
		return err
	}
	sc.accepting.Store(true)
	if err = emit(bridge.Started()); err != nil {
		return err
	}
	if err = c.startRun(req.ChatID, sessionID, conn); err != nil {
		return err
	}
	defer c.finishRun(req.ChatID, conn)
	defer c.dropPendingForChat(req.ChatID)
	_, err = conn.Prompt(ctx, acpsdk.PromptRequest{SessionId: acpsdk.SessionId(sessionID), Prompt: []acpsdk.ContentBlock{{Text: &acpsdk.ContentBlockText{Type: "text", Text: req.Prompt}}}})
	if err != nil {
		c.cancelOnClientDisconnect(ctx, req.ChatID)
		return err
	}
	return emitAll(emit, bridge.Finished())
}
func (c *Coordinator) cancelOnClientDisconnect(ctx context.Context, chatID string) {
	if ctx.Err() == nil {
		return
	}
	cc, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_ = c.Cancel(cc, chatID)
}
func (c *Coordinator) startRun(chat, sid string, conn acp.Conn) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.activeRun[chat] != nil {
		return ErrRunInProgress
	}
	c.activeRun[chat] = &activeRun{sessionID: sid, conn: conn}
	return nil
}
func (c *Coordinator) finishRun(chat string, conn acp.Conn) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if r := c.activeRun[chat]; r != nil && r.conn == conn {
		delete(c.activeRun, chat)
	}
}
func (c *Coordinator) dropPendingForChat(chat string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	for id, p := range c.pending {
		if p.chatID == chat {
			delete(c.pending, id)
			if p.timer != nil {
				p.timer.Stop()
			}
			select {
			case p.decision <- permissionDecision{cancelled: true}:
			default:
			}
		}
	}
}
func (c *Coordinator) Shutdown(ctx context.Context) {
	c.mu.Lock()
	runs := map[string]*activeRun{}
	for id, r := range c.activeRun {
		runs[id] = r
	}
	pending := []*pendingPermission{}
	for id, p := range c.pending {
		delete(c.pending, id)
		if p.timer != nil {
			p.timer.Stop()
		}
		pending = append(pending, p)
	}
	c.mu.Unlock()
	for _, r := range runs {
		_ = r.conn.Cancel(ctx, acpsdk.CancelNotification{SessionId: acpsdk.SessionId(r.sessionID)})
	}
	for _, p := range pending {
		select {
		case p.decision <- permissionDecision{cancelled: true}:
		default:
		}
	}
}
