package coordinator

import (
	"context"
	"errors"
	"fmt"
	"log"
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
	Clock                            Clock
	LingerWindow                     time.Duration
	MaxRun                           time.Duration
	ElicitationTimeout               time.Duration
	MaxRunEvents                     int
	LiveBuffer                       int
}
type RunRequest struct{ ChatID, Prompt string }
type Emit func(events.Event) error
type ResolveSession func(context.Context) (string, error)
type OnSessionCreated func(context.Context, string) error
type DialFunc func(context.Context, acpsdk.Client) (acp.Conn, error)

type runHandle struct {
	runID, sessionID string
	cancel           context.CancelFunc
	conn             acp.Conn
	accepting        *atomic.Bool
	events           atomic.Int64
	timers           []Timer
	teardown         func(release bool)
}

type Coordinator struct {
	config    Config
	mu        sync.Mutex
	running   map[string]struct{}
	activeRun map[string]*activeRun
	pending   map[string]*pendingPermission
	clock              Clock
	hubs               map[string]*ChatHub
	runs               map[string]*runHandle
	lingerWindow       time.Duration
	maxRun             time.Duration
	elicitationTimeout time.Duration
	maxRunEvents       int
	liveBuf            int
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
	if config.Clock == nil {
		config.Clock = RealClock()
	}
	orElseD := func(d, def time.Duration) time.Duration {
		if d <= 0 {
			return def
		}
		return d
	}
	orElseI := func(n, def int) int {
		if n <= 0 {
			return def
		}
		return n
	}
	c := &Coordinator{
		config: config, clock: config.Clock,
		running: map[string]struct{}{}, activeRun: map[string]*activeRun{}, pending: map[string]*pendingPermission{},
		hubs: map[string]*ChatHub{}, runs: map[string]*runHandle{},
		lingerWindow:       orElseD(config.LingerWindow, 30*time.Second),
		maxRun:             orElseD(config.MaxRun, 15*time.Minute),
		elicitationTimeout: orElseD(config.ElicitationTimeout, orElseD(config.PermissionTimeout, 5*time.Minute)),
		maxRunEvents:       orElseI(config.MaxRunEvents, 50000),
		liveBuf:            orElseI(config.LiveBuffer, 256),
	}
	return c, nil
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

func (c *Coordinator) hubFor(chatID string) *ChatHub {
	c.mu.Lock()
	defer c.mu.Unlock()
	h := c.hubs[chatID]
	if h == nil {
		h = NewChatHub(c.clock, c.lingerWindow, c.liveBuf)
		c.hubs[chatID] = h
	}
	return h
}

func (c *Coordinator) reapHub(chatID string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if h := c.hubs[chatID]; h != nil && h.IsEmpty() {
		delete(c.hubs, chatID)
	}
}

func (c *Coordinator) Attach(chatID string, cursor int) Attachment {
	return c.hubFor(chatID).Attach(cursor)
}

func (c *Coordinator) registerRun(chatID string, h *runHandle) {
	c.mu.Lock()
	c.runs[chatID] = h
	c.mu.Unlock()
}

func (c *Coordinator) runFor(chatID string) *runHandle {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.runs[chatID]
}

func (c *Coordinator) clearRun(chatID, runID string) {
	c.mu.Lock()
	if h := c.runs[chatID]; h != nil && h.runID == runID {
		delete(c.runs, chatID)
	}
	c.mu.Unlock()
}

func (c *Coordinator) trackTimer(chatID, runID string, t Timer) {
	c.mu.Lock()
	if h := c.runs[chatID]; h != nil && h.runID == runID {
		h.timers = append(h.timers, t)
	}
	c.mu.Unlock()
}

func (c *Coordinator) stopTimers(h *runHandle) {
	for _, t := range h.timers {
		t.Stop()
	}
}

func (c *Coordinator) isReserved(chatID string) bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	_, ok := c.running[chatID]
	return ok
}

func (c *Coordinator) Cancel(ctx context.Context, chatID string) error {
	// Detached-run path: prefer the registry entry over the legacy activeRun so
	// a StartPrompt-launched run is cancelled even when no legacy bookkeeping
	// was attached to it.
	if h := c.runFor(chatID); h != nil {
		if h.conn != nil {
			_ = h.conn.Cancel(ctx, acpsdk.CancelNotification{SessionId: acpsdk.SessionId(h.sessionID)})
		}
		h.cancel()
		c.mu.Lock()
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
		if p != nil {
			select {
			case p.decision <- permissionDecision{cancelled: true}:
			default:
			}
		}
		return nil
	}

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
	runID             string
	bridge            *agui.Bridge
	emit              Emit
	accepting         *atomic.Bool
	events            atomic.Int64
	maxEvents         int
	cancel            context.CancelFunc
	emitMu            sync.Mutex
}

func (s *sessionClient) SessionUpdate(_ context.Context, n acpsdk.SessionNotification) error {
	if !s.accepting.Load() {
		return nil
	}
	if s.maxEvents > 0 && int(s.events.Add(1)) > s.maxEvents {
		_ = s.emit(events.NewRunErrorEvent("run too large", events.WithErrorCode("run_too_large")))
		if s.cancel != nil {
			s.cancel()
		}
		return nil
	}
	s.emitMu.Lock()
	defer s.emitMu.Unlock()
	updates, err := s.bridge.Update(n.Update)
	// Soft-miss: the bridge already emitted redacted RAW for unmapped shapes;
	// a returned error is non-fatal, so publish what we have and keep going.
	_ = err
	for _, e := range updates {
		if emitErr := s.emit(e); emitErr != nil {
			return emitErr
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
		return emitAll(emit, bridge.Finished(acpsdk.StopReasonEndTurn))
	}
	sc := &sessionClient{c: c, chatID: chatID, sessionID: sessionID, bridge: bridge, emit: emit, accepting: &atomic.Bool{}}
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
	return emitAll(emit, bridge.Finished(acpsdk.StopReasonEndTurn))
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
	sc := &sessionClient{c: c, chatID: req.ChatID, sessionID: sessionID, bridge: bridge, emit: emit, accepting: &atomic.Bool{}}
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
	return emitAll(emit, bridge.Finished(acpsdk.StopReasonEndTurn))
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

// StartPrompt reserves chatID, spawns a detached run goroutine on a fresh
// context.Background()-derived ctx (which also doubles as the Goose dial ctx,
// spec N1), and returns the run id immediately. The run survives the caller
// returning: teardown fires on Prompt return / cancel / panic, last in the
// gate is always the release of Reserve so a second StartPrompt can take over.
func (c *Coordinator) StartPrompt(chatID, prompt string, resolve ResolveSession, created OnSessionCreated) (string, error) {
	if err := c.Reserve(chatID); err != nil {
		return "", err
	}
	runID := uuid.NewString()
	runCtx, cancel := context.WithCancel(context.Background())
	accepting := &atomic.Bool{}
	h := &runHandle{runID: runID, cancel: cancel, accepting: accepting}
	c.registerRun(chatID, h)
	go c.runLoop(runCtx, chatID, runID, prompt, h, resolve, created)
	return runID, nil
}

// runLoop is the per-run goroutine. It owns the *one* sync.Once teardown,
// a single panic recover that publishes RUN_ERROR, and the publish-through-
// hub `emit` so RequestPermission (which also calls s.emit) remains safe on
// the detached path with no client lifetime dependency.
func (c *Coordinator) runLoop(runCtx context.Context, chatID, runID, prompt string, h *runHandle, resolve ResolveSession, created OnSessionCreated) {
	hub := c.hubFor(chatID)
	var once sync.Once
	teardown := func() {
		once.Do(func() {
			h.accepting.Store(false) // straggler SessionUpdates now return early
			c.stopTimers(h)
			if h.conn != nil {
				_ = h.conn.Close()
			}
			c.dropPendingForChat(chatID)
			hub.FinishRun()
			h.cancel()
			c.clearRun(chatID, runID)
			c.reapHub(chatID)
			c.release(chatID) // LAST
		})
	}
	h.teardown = func(bool) { teardown() }
	defer teardown()
	defer func() {
		if r := recover(); r != nil {
			hub.Publish(events.NewRunErrorEvent("internal error", events.WithErrorCode("protocol_error")))
		}
	}()

	sessionID, err := resolve(runCtx)
	if err != nil {
		hub.Publish(events.NewRunErrorEvent("session mapping", events.WithErrorCode("goose_unavailable")))
		return
	}
	bridge := agui.NewBridge(chatID, runID)
	hub.StartRun(runID, bridge.Snapshot)

	// Detached path routes ALL client callbacks (SessionUpdate AND
	// RequestPermission — both call s.emit) through the hub, so emit is never
	// nil. accepting is the SHARED pointer from the runHandle.
	sc := &sessionClient{c: c, chatID: chatID, runID: runID, sessionID: sessionID, bridge: bridge,
		emit:      func(e events.Event) error { hub.Publish(e); return nil },
		accepting: h.accepting, maxEvents: c.maxRunEvents, cancel: h.cancel}
	conn, err := c.config.Dial(runCtx, sc) // runCtx is ALSO the dial ctx (spec N1)
	if err != nil {
		hub.Publish(events.NewRunErrorEvent("goose dial", events.WithErrorCode("goose_unavailable")))
		return
	}
	h.conn = conn
	sessionID, err = c.initSession(runCtx, conn, sc, bridge, sessionID, created) // Task 11/12
	if err != nil {
		hub.Publish(events.NewRunErrorEvent("session init", events.WithErrorCode("goose_unavailable")))
		return
	}
	h.sessionID = sessionID
	sc.sessionID = sessionID
	h.accepting.Store(true)
	hub.Publish(bridge.Started())

	maxTimer := c.clock.AfterFunc(c.maxRun, func() { h.cancel() })
	c.trackTimer(chatID, runID, maxTimer)

	resp, err := conn.Prompt(runCtx, acpsdk.PromptRequest{
		SessionId: acpsdk.SessionId(sessionID),
		Prompt:    []acpsdk.ContentBlock{{Text: &acpsdk.ContentBlockText{Type: "text", Text: prompt}}},
	})
	if err != nil {
		code := "goose_unavailable"
		if runCtx.Err() != nil {
			code = "run_timeout"
		}
		hub.Publish(events.NewRunErrorEvent("goose turn failed", events.WithErrorCode(code)))
		return
	}
	for _, e := range bridge.Finished(resp.StopReason) {
		hub.Publish(e)
	}
}

// initSession runs the ACP init sequence on a freshly dialed conn: initialize,
// session/new (and persist) or session/load (by sessionID), and set_session_mode
// to "approve". On a session/new whose mapping persist fails, the freshly
// minted Goose session is deleted (orphan compensation) before returning the
// wrapped error. Tasks 11/12 extend this further.
func (c *Coordinator) initSession(ctx context.Context, conn acp.Conn, sc *sessionClient, bridge *agui.Bridge, sessionID string, created OnSessionCreated) (string, error) {
	_ = bridge
	_ = sc
	if _, err := conn.Initialize(ctx, initializeRequest()); err != nil {
		return "", err
	}
	if sessionID == "" {
		res, err := conn.NewSession(ctx, acpsdk.NewSessionRequest{Cwd: c.config.Workspace, McpServers: []acpsdk.McpServer{}})
		if err != nil {
			return "", err
		}
		sessionID = string(res.SessionId)
		if sessionID == "" {
			return "", errors.New("session/new response missing sessionId")
		}
		if err := created(ctx, sessionID); err != nil {
			// Orphan compensation (Task 11): the Goose session exists but is
			// unmapped — delete it so the next prompt does not strand history.
			if dErr := conn.UnstableDeleteSession(ctx, acpsdk.UnstableDeleteSessionRequest{SessionId: acpsdk.SessionId(sessionID)}); dErr != nil {
				log.Printf("coordinator: orphan session delete failed: %v", dErr)
			}
			return "", fmt.Errorf("persist Goose session mapping: %w", err)
		}
		// Task 12: bridge.SeedSession(res.Modes, res.ConfigOptions) -> hub.Publish
	} else {
		res, err := conn.LoadSession(ctx, acpsdk.LoadSessionRequest{SessionId: acpsdk.SessionId(sessionID), Cwd: c.config.Workspace, McpServers: []acpsdk.McpServer{}})
		if err != nil {
			return "", err
		}
		_ = res // Task 12: bridge.SeedSession(res.Modes, res.ConfigOptions) -> hub.Publish
	}
	if _, err := conn.SetSessionMode(ctx, acpsdk.SetSessionModeRequest{SessionId: acpsdk.SessionId(sessionID), ModeId: acpsdk.SessionModeId("approve")}); err != nil {
		return "", err
	}
	return sessionID, nil
}
