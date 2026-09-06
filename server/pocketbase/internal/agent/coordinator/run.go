/*
PocketCoder: An accessible, secure, and user-friendly open-source coding assistant platform.
Copyright (C) 2026 Qtpi Bonding LLC

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

// @pocketcoder-core: Run Lifecycle. Drives a single AG-UI run over the ACP session and resolves permission callbacks.
package coordinator

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/ag-ui-protocol/ag-ui/sdks/community/go/pkg/core/events"
	acpsdk "github.com/coder/acp-go-sdk"
	"github.com/google/uuid"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/agent/acp"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/agent/agui"
)

type Config struct {
	Workspace          string
	PermissionTimeout  time.Duration
	Dial               DialFunc
	Clock              Clock
	LingerWindow       time.Duration
	MaxRun             time.Duration
	ElicitationTimeout time.Duration
	MaxRunEvents       int
	LiveBuffer         int
	// OnPermissionPending fires whenever a permission request actually goes
	// pending (i.e. session-profile rules didn't auto-resolve it) -- the
	// hook point for dispatching a push notification. payload is exactly
	// what agui.PermissionPayload builds -- the same AG-UI STATE_DELTA shape
	// (requestId/status/options[].optionId,name,kind/toolCallId/title/kind)
	// the Flutter client already parses from the live SSE stream, not a
	// second ACP-shaped schema it's never had to speak. Called from a
	// goroutine by the caller; must not block or delay the permission wait.
	OnPermissionPending func(ctx context.Context, chatID string, payload map[string]any)
	// OnElicitationPending mirrors OnPermissionPending for elicitation
	// (spec N5's separate id-space): payload is agui.ElicitationPayload's
	// shape (elicitationId/message/mode/requestedSchema/url).
	OnElicitationPending func(ctx context.Context, chatID string, payload map[string]any)
}
type Emit func(events.Event) error
type ResolveSession func(context.Context) (string, error)
type OnSessionCreated func(context.Context, string) error
type OnRunFinished func(context.Context, acpsdk.StopReason) error
type RunOutcome string

const (
	RunCompleted RunOutcome = "completed"
	RunFailed    RunOutcome = "failed"
	RunCancelled RunOutcome = "cancelled"
)

type RunOption func(*runOptions)
type runOptions struct {
	onRunEnded    func(context.Context, string, RunOutcome)
	userMessageID string
}

func WithOnRunEnded(fn func(context.Context, string, RunOutcome)) RunOption {
	return func(o *runOptions) { o.onRunEnded = fn }
}

// WithUserMessageID carries the client-generated id from PromptRequest.MessageId
// (acp-go-sdk) through to runLoop, which echoes it back into the hub as a
// user-role TEXT_MESSAGE_START/CONTENT/END sequence — see runLoop's use of
// this value for why: the client already renders this id optimistically, and
// the client's ConversationReducer dedupes by exact id, so echoing the same
// id here (rather than minting a new one) is what makes the optimistic
// insert get superseded instead of duplicated once this arrives.
func WithUserMessageID(id string) RunOption {
	return func(o *runOptions) { o.userMessageID = id }
}

// WithUserMessageIDOpt is WithUserMessageID for a caller holding the
// acp-go-sdk *string shape directly (PromptRequest.MessageId) — a no-op
// RunOption when nil or empty, so call sites don't need their own branch.
func WithUserMessageIDOpt(id *string) RunOption {
	if id == nil || *id == "" {
		return func(*runOptions) {}
	}
	return WithUserMessageID(*id)
}

type DialFunc func(context.Context, acpsdk.Client, Target) (acp.Conn, error)

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
	config             Config
	mu                 sync.Mutex
	running            map[string]struct{}
	pending            map[string]*pendingPermission
	clock              Clock
	hubs               map[string]*ChatHub
	runs               map[string]*runHandle
	elicits            map[string]*pendingElicitation
	lingerWindow       time.Duration
	maxRun             time.Duration
	elicitationTimeout time.Duration
	maxRunEvents       int
	liveBuf            int
	idempotency        map[string]idempotencySlot
}
type idempotencySlot struct {
	key    string
	result any
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

// pendingElicitation mirrors pendingPermission's shape but lives in a
// separate map (spec N5): elicitation and permission are distinct ACP
// side-channels and must not share id-space or resolution paths.
type pendingElicitation struct {
	chatID, sessionID string
	decision          chan elicitationDecision
	timer             Timer
}
type elicitationDecision struct {
	resp      acpsdk.UnstableCreateElicitationResponse
	cancelled bool
}

var ErrNoActiveRun = errors.New("no active run")
var ErrRunInProgress = errors.New("chat already has an active run")
var ErrNoPendingPermission = errors.New("no pending permission")
var ErrPermissionOptionNotOffered = errors.New("permission option was not offered")
var ErrNoPendingElicitation = errors.New("no pending elicitation")

// isConnDone reports whether conn's transport has already signalled
// shutdown, distinguishing a dead pipe from an application-level harness
// error while the connection is still alive.
func isConnDone(conn acp.Conn) bool {
	select {
	case <-conn.Done():
		return true
	default:
		return false
	}
}

func New(config Config) (*Coordinator, error) {
	if config.Workspace == "" {
		return nil, fmt.Errorf("workspace is required")
	}
	if config.Dial == nil {
		config.Dial = func(ctx context.Context, client acpsdk.Client, t Target) (acp.Conn, error) {
			if t.URL == "" {
				return nil, fmt.Errorf("harness target is required")
			}
			return acp.Dial(ctx, acp.DialConfig{URL: t.URL, Secret: t.Secret}, client)
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
		running: map[string]struct{}{}, pending: map[string]*pendingPermission{},
		hubs: map[string]*ChatHub{}, runs: map[string]*runHandle{}, elicits: map[string]*pendingElicitation{},
		idempotency:        map[string]idempotencySlot{},
		lingerWindow:       orElseD(config.LingerWindow, 30*time.Second),
		maxRun:             orElseD(config.MaxRun, 15*time.Minute),
		elicitationTimeout: orElseD(config.ElicitationTimeout, orElseD(config.PermissionTimeout, 5*time.Minute)),
		maxRunEvents:       orElseI(config.MaxRunEvents, 50000),
		liveBuf:            orElseI(config.LiveBuffer, 256),
	}
	return c, nil
}

// CheckIdempotency returns the cached result for key if it matches the
// current chat's slot. A chat holds exactly one slot: the most recent
// (key, result) pair. There is no TTL — the slot is only ever replaced by
// the next legitimate mutation for that chat, never expired.
func (c *Coordinator) CheckIdempotency(chatID, key string) (any, bool) {
	if key == "" {
		return nil, false
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	slot, ok := c.idempotency[chatID]
	if !ok || slot.key != key {
		return nil, false
	}
	return slot.result, true
}

// RecordIdempotency stores result under key for chatID, replacing whatever
// was there. Call this after successfully performing the mutation.
func (c *Coordinator) RecordIdempotency(chatID, key string, result any) {
	if key == "" {
		return
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	c.idempotency[chatID] = idempotencySlot{key: key, result: result}
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

// NextSeq allocates the next hub-global monotonic sequence number for
// chatID, shared between cold replay and live publish so a stream's ids are
// strictly increasing regardless of which path produced them.
func (c *Coordinator) NextSeq(chatID string) int {
	return c.hubFor(chatID).nextSeq()
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

// Cancel sends an ACP session/cancel for chatID's active detached run (if
// any) and resolves any pending permission/elicitation for that chat as
// cancelled, so a blocked ACP callback unblocks instead of stalling
// teardown. There is no legacy fallback path: every run is now started via
// StartPrompt and lives in the run registry.
func (c *Coordinator) Cancel(ctx context.Context, chatID string) error {
	h := c.runFor(chatID)
	if h == nil {
		return ErrNoActiveRun
	}
	if h.conn != nil {
		_ = h.conn.Cancel(ctx, acpsdk.CancelNotification{SessionId: acpsdk.SessionId(h.sessionID)})
	}
	h.cancel()
	c.dropPendingForChat(chatID)
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

// DenyPermission cancels a pending permission decision (the ACP "cancelled"
// outcome) without requiring an offered option, mirroring dropPendingForChat's
// cancellation but scoped to a single requestID.
func (c *Coordinator) DenyPermission(chatID, requestID string) error {
	c.mu.Lock()
	p := c.pending[requestID]
	if p == nil || p.chatID != chatID {
		c.mu.Unlock()
		return ErrNoPendingPermission
	}
	delete(c.pending, requestID)
	if p.timer != nil {
		p.timer.Stop()
	}
	c.mu.Unlock()
	select {
	case p.decision <- permissionDecision{cancelled: true}:
	default:
	}
	return nil
}

// ResolveElicitation delivers the user's response to a pending elicitation
// (identified by id, scoped to chatID) so the blocked
// sessionClient.UnstableCreateElicitation call can return.
func (c *Coordinator) ResolveElicitation(chatID, id string, resp acpsdk.UnstableCreateElicitationResponse) error {
	c.mu.Lock()
	p := c.elicits[id]
	if p == nil || p.chatID != chatID {
		c.mu.Unlock()
		return ErrNoPendingElicitation
	}
	delete(c.elicits, id)
	if p.timer != nil {
		p.timer.Stop()
	}
	c.mu.Unlock()
	select {
	case p.decision <- elicitationDecision{resp: resp}:
	default:
	}
	return nil
}

// SetMode dispatches session/set_mode to the active run's connection.
func (c *Coordinator) SetMode(ctx context.Context, chatID, modeID string) error {
	h := c.runFor(chatID)
	if h == nil || h.conn == nil {
		return ErrNoActiveRun
	}
	_, err := h.conn.SetSessionMode(ctx, acpsdk.SetSessionModeRequest{SessionId: acpsdk.SessionId(h.sessionID), ModeId: acpsdk.SessionModeId(modeID)})
	return err
}

// SetConfigOption dispatches session/set_config_option to the active run's
// connection. The caller is expected to have already set SessionId on
// whichever variant of the union is populated.
func (c *Coordinator) SetConfigOption(ctx context.Context, chatID string, req acpsdk.SetSessionConfigOptionRequest) error {
	h := c.runFor(chatID)
	if h == nil || h.conn == nil {
		return ErrNoActiveRun
	}
	// The Goose session id is server-resolved from the active run, never
	// trusted from the request body: the client only supplies configId/value.
	switch {
	case req.Boolean != nil:
		req.Boolean.SessionId = acpsdk.SessionId(h.sessionID)
	case req.ValueId != nil:
		req.ValueId.SessionId = acpsdk.SessionId(h.sessionID)
	}
	_, err := h.conn.SetSessionConfigOption(ctx, req)
	return err
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
	permissionRules   []ToolPermissionRule
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
	if err != nil {
		log.Printf("coordinator: session update bridge failed: %v", err)
	}
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
	tool, values := permissionToolIdentity(req.ToolCall)
	action := SessionProfile{PermissionRules: s.permissionRules}.PermissionDecision(tool, values...)
	if action == ToolPermissionAllow || action == ToolPermissionDeny {
		return automaticPermissionResponse(req.Options, action), nil
	}
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
	_ = s.emit(s.bridge.PermissionPending(id, req.Options, string(req.ToolCall.ToolCallId), req.ToolCall.Title, req.ToolCall.Kind))
	s.emitMu.Unlock()
	if s.c.config.OnPermissionPending != nil {
		payload := agui.PermissionPayload(id, req.Options, string(req.ToolCall.ToolCallId), req.ToolCall.Title, req.ToolCall.Kind)
		go s.c.config.OnPermissionPending(ctx, s.chatID, payload)
	}
	select {
	case d := <-p.decision:
		s.emitMu.Lock()
		_ = emitAll(s.emit, s.bridge.ResolvePermission(id))
		s.emitMu.Unlock()
		if d.cancelled {
			return acpsdk.RequestPermissionResponse{Outcome: acpsdk.RequestPermissionOutcome{Cancelled: &acpsdk.RequestPermissionOutcomeCancelled{Outcome: "cancelled"}}}, nil
		}
		return acpsdk.RequestPermissionResponse{Outcome: acpsdk.RequestPermissionOutcome{Selected: &acpsdk.RequestPermissionOutcomeSelected{Outcome: "selected", OptionId: acpsdk.PermissionOptionId(d.option)}}}, nil
	case <-ctx.Done():
		s.emitMu.Lock()
		_ = emitAll(s.emit, s.bridge.ResolvePermission(id))
		s.emitMu.Unlock()
		s.removePending(id, p)
		return acpsdk.RequestPermissionResponse{Outcome: acpsdk.RequestPermissionOutcome{Cancelled: &acpsdk.RequestPermissionOutcomeCancelled{Outcome: "cancelled"}}}, nil
	}
}

func permissionToolIdentity(call acpsdk.ToolCallUpdate) (string, []string) {
	values := make([]string, 0, 4)
	tool := ""
	for _, key := range []string{"toolName", "tool_name", "name", "tool"} {
		if v, ok := call.Meta[key].(string); ok && strings.TrimSpace(v) != "" {
			tool = strings.ToLower(strings.TrimSpace(v))
			values = append(values, v)
			break
		}
	}
	if call.Title != nil {
		values = append(values, *call.Title)
		if tool == "" {
			fields := strings.Fields(*call.Title)
			if len(fields) > 0 {
				tool = strings.ToLower(fields[0])
			}
		}
	}
	if call.Kind != nil {
		values = append(values, string(*call.Kind))
		if tool == "" {
			tool = string(*call.Kind)
		}
	}
	if call.RawInput != nil {
		if raw, err := json.Marshal(call.RawInput); err == nil {
			values = append(values, string(raw))
		}
		if input, ok := call.RawInput.(map[string]any); ok && tool == "" {
			for _, key := range []string{"toolName", "tool_name", "name", "tool"} {
				if v, ok := input[key].(string); ok && strings.TrimSpace(v) != "" {
					tool = strings.ToLower(strings.TrimSpace(v))
					break
				}
			}
		}
	}
	if tool == "" {
		tool = "*"
	}
	return tool, values
}

func automaticPermissionResponse(options []acpsdk.PermissionOption, action ToolPermissionAction) acpsdk.RequestPermissionResponse {
	preferred := acpsdk.PermissionOptionKindAllowOnce
	fallback := acpsdk.PermissionOptionKindAllowAlways
	if action == ToolPermissionDeny {
		preferred, fallback = acpsdk.PermissionOptionKindRejectOnce, acpsdk.PermissionOptionKindRejectAlways
	}
	for _, option := range options {
		if option.Kind == preferred {
			return selectedPermission(option.OptionId)
		}
	}
	for _, option := range options {
		if option.Kind == fallback {
			return selectedPermission(option.OptionId)
		}
	}
	return acpsdk.RequestPermissionResponse{Outcome: acpsdk.RequestPermissionOutcome{Cancelled: &acpsdk.RequestPermissionOutcomeCancelled{Outcome: "cancelled"}}}
}

func selectedPermission(id acpsdk.PermissionOptionId) acpsdk.RequestPermissionResponse {
	return acpsdk.RequestPermissionResponse{Outcome: acpsdk.RequestPermissionOutcome{Selected: &acpsdk.RequestPermissionOutcomeSelected{Outcome: "selected", OptionId: id}}}
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

// UnstableCreateElicitation mirrors RequestPermission's block-until-resolved
// shape but lives in its own map (pendingElicitation, spec N5) and its
// timeout runs through the injectable Clock so tests are deterministic.
func (s *sessionClient) UnstableCreateElicitation(ctx context.Context, req acpsdk.UnstableCreateElicitationRequest) (acpsdk.UnstableCreateElicitationResponse, error) {
	id := uuid.NewString()
	p := &pendingElicitation{chatID: s.chatID, sessionID: s.sessionID, decision: make(chan elicitationDecision, 1)}
	s.c.mu.Lock()
	s.c.elicits[id] = p
	if s.c.elicitationTimeout > 0 {
		// Set the timer inside the same critical section that publishes p
		// into the map: removePendingElicitation/ResolveElicitation always
		// read/write p.timer under c.mu, so this avoids a data race between
		// this assignment and a concurrent expiry firing on another
		// goroutine (notably the fake clock in tests, which invokes the
		// AfterFunc callback synchronously from Advance).
		p.timer = s.c.clock.AfterFunc(s.c.elicitationTimeout, func() { s.resolveExpiredElicitation(id, p) })
	}
	s.c.mu.Unlock()
	var message, mode, url string
	var schema any
	switch {
	case req.Form != nil:
		message, mode, schema = req.Form.Message, req.Form.Mode, req.Form.RequestedSchema
	case req.Url != nil:
		message, mode, url = req.Url.Message, "url", req.Url.Url
	}
	s.emitMu.Lock()
	_ = s.emit(s.bridge.ElicitationPending(id, message, mode, schema, url))
	s.emitMu.Unlock()
	if s.c.config.OnElicitationPending != nil {
		payload := agui.ElicitationPayload(id, message, mode, schema, url)
		go s.c.config.OnElicitationPending(ctx, s.chatID, payload)
	}
	select {
	case d := <-p.decision:
		s.emitMu.Lock()
		_ = emitAll(s.emit, s.bridge.ResolveElicitation(id))
		s.emitMu.Unlock()
		if d.cancelled {
			return acpsdk.UnstableCreateElicitationResponse{Cancel: &acpsdk.UnstableCreateElicitationCancel{Action: "cancel"}}, nil
		}
		return d.resp, nil
	case <-ctx.Done():
		s.emitMu.Lock()
		_ = emitAll(s.emit, s.bridge.ResolveElicitation(id))
		s.emitMu.Unlock()
		s.removePendingElicitation(id, p)
		return acpsdk.UnstableCreateElicitationResponse{Cancel: &acpsdk.UnstableCreateElicitationCancel{Action: "cancel"}}, nil
	}
}
func (s *sessionClient) removePendingElicitation(id string, expected *pendingElicitation) {
	s.c.mu.Lock()
	if s.c.elicits[id] == expected {
		delete(s.c.elicits, id)
	}
	s.c.mu.Unlock()
	if expected.timer != nil {
		expected.timer.Stop()
	}
}
func (s *sessionClient) resolveExpiredElicitation(id string, expected *pendingElicitation) {
	s.removePendingElicitation(id, expected)
	select {
	case expected.decision <- elicitationDecision{cancelled: true}:
	default:
	}
}

// establishSession is the resolve+pin-check+capability-check+dial+init
// prefix shared by runLoop and StreamColdReplay. It does NOT call
// SeedSession, ProfileApplier.Apply, or Prompt — those are each caller's
// own job, done with the conn/sessionID/modes/configOptions this returns. See design
// spec §5.6 for why the split is drawn exactly here.
//
// wasNew reports whether this call minted a brand-new session (sessionID
// was empty) — callers need this to decide whether to persist a new
// agent_sessions row; sessionID's own emptiness can no longer be used for
// that check once establishSession owns both branches internally.
func (c *Coordinator) establishSession(
	ctx context.Context, client acpsdk.Client, profile SessionProfile, sessionID string,
	beforeSessionCall func(),
) (conn acp.Conn, newSessionID string, modes *acpsdk.SessionModeState, configOptions []acpsdk.SessionConfigOption, initResp *acpsdk.InitializeResponse, wasNew bool, err error) {

	// Pin check: compare resolved vs. pinned harness identity, not Targets
	// (an unresolved Target and the pinned default Target are both the
	// zero value and would otherwise compare equal).
	if profile.PinnedInstanceID != "" && profile.ResolvedInstanceID != "" &&
		profile.PinnedInstanceID != profile.ResolvedInstanceID {
		return nil, "", nil, nil, nil, false, fmt.Errorf("this chat's harness changed after its session was created — start a new chat")
	}

	dialedConn, dialErr := c.config.Dial(ctx, client, profile.Target)
	if dialErr != nil {
		return nil, "", nil, nil, nil, false, fmt.Errorf("dial harness: %w", dialErr)
	}
	initRespVal, err := dialedConn.Initialize(ctx, initializeRequest())
	if err != nil {
		dialedConn.Close()
		return nil, "", nil, nil, nil, false, fmt.Errorf("initialize harness: %w", err)
	}
	initResp = &initRespVal

	if err := selectProviderBootstrap(profile).Bootstrap(ctx, dialedConn, profile); err != nil {
		dialedConn.Close()
		return nil, "", nil, nil, nil, false, fmt.Errorf("bootstrap provider: %w", err)
	}

	cwd := profile.Cwd
	if cwd == "" {
		cwd = c.config.Workspace
	}

	if sessionID == "" {
		beforeSessionCall()
		res, err := dialedConn.NewSession(ctx, acpsdk.NewSessionRequest{
			Meta: profile.sessionMeta(), Cwd: cwd, AdditionalDirectories: profile.additionalDirectories(), McpServers: profile.mcpServers(),
		})
		if err != nil {
			dialedConn.Close()
			return nil, "", nil, nil, nil, false, err
		}
		if string(res.SessionId) == "" {
			dialedConn.Close()
			return nil, "", nil, nil, nil, false, errors.New("session/new response missing sessionId")
		}
		return dialedConn, string(res.SessionId), res.Modes, res.ConfigOptions, initResp, true, nil
	}

	if initResp.AgentCapabilities.SessionCapabilities.Resume != nil {
		beforeSessionCall()
		res, err := dialedConn.ResumeSession(ctx, acpsdk.ResumeSessionRequest{
			Meta: profile.sessionMeta(), SessionId: acpsdk.SessionId(sessionID), Cwd: cwd, AdditionalDirectories: profile.additionalDirectories(), McpServers: profile.mcpServers(),
		})
		if err != nil {
			dialedConn.Close()
			return nil, "", nil, nil, nil, false, fmt.Errorf("resume harness session: %w", err)
		}
		return dialedConn, sessionID, res.Modes, res.ConfigOptions, initResp, false, nil
	}

	if !initResp.AgentCapabilities.LoadSession {
		dialedConn.Close()
		return nil, "", nil, nil, nil, false, fmt.Errorf("harness does not support resuming a session (AgentCapabilities.LoadSession is false)")
	}
	beforeSessionCall()
	res, err := dialedConn.LoadSession(ctx, acpsdk.LoadSessionRequest{
		Meta: profile.sessionMeta(), SessionId: acpsdk.SessionId(sessionID), Cwd: cwd, AdditionalDirectories: profile.additionalDirectories(), McpServers: profile.mcpServers(),
	})
	if err != nil {
		dialedConn.Close()
		return nil, "", nil, nil, nil, false, fmt.Errorf("load harness session: %w", err)
	}
	return dialedConn, sessionID, res.Modes, res.ConfigOptions, initResp, false, nil
}

// StreamColdReplay runs a bounded, no-Reserve Goose replay for a subscriber
// whose Attach reported ColdReplayNeeded (the buffered run was evicted or
// never existed for this chat-global cursor). It dials a short-lived conn,
// walks session/load through a fresh Bridge exactly like the old
// ReplayReserved body, and hands each resulting event to emit with
// ascending seqs starting at 1 — the caller (the stream route) writes these
// as SSE frames before falling through to the hub's Buffered/Live tail.
func (c *Coordinator) StreamColdReplay(ctx context.Context, chatID, sessionID string, profileFn ProfileFunc, emit func(seq int, ev events.Event) error) error {
	bridge := agui.NewBridge(chatID, uuid.NewString())
	emitSeq := func(ev events.Event) error {
		return emit(c.NextSeq(chatID), ev)
	}
	if err := emitSeq(bridge.ReplayStarted()); err != nil {
		return err
	}
	if err := emitSeq(bridge.Started()); err != nil {
		return err
	}
	if sessionID == "" {
		return emitAll(emitSeq, bridge.Finished(acpsdk.StopReasonEndTurn))
	}
	profile, err := profileFn(ctx)
	if err != nil {
		return fmt.Errorf("resolve session profile: %w", err)
	}
	sc := &sessionClient{c: c, chatID: chatID, sessionID: sessionID, bridge: bridge, emit: emitSeq, accepting: &atomic.Bool{}}
	conn, _, _, _, _, _, err := c.establishSession(ctx, sc, profile, sessionID, func() { sc.accepting.Store(true) })
	if err != nil {
		return err
	}
	defer conn.Close()
	return emitAll(emitSeq, bridge.Finished(acpsdk.StopReasonEndTurn))
}
func initializeRequest() acpsdk.InitializeRequest {
	return acpsdk.InitializeRequest{
		ProtocolVersion: acpsdk.ProtocolVersionNumber,
		ClientCapabilities: acpsdk.ClientCapabilities{
			Elicitation: &acpsdk.ElicitationCapabilities{Form: &acpsdk.ElicitationFormCapabilities{}},
		},
	}
}
func emitAll(emit Emit, values []events.Event) error {
	for _, v := range values {
		if err := emit(v); err != nil {
			return err
		}
	}
	return nil
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
	for id, p := range c.elicits {
		if p.chatID == chat {
			delete(c.elicits, id)
			if p.timer != nil {
				p.timer.Stop()
			}
			select {
			case p.decision <- elicitationDecision{cancelled: true}:
			default:
			}
		}
	}
}

// Shutdown cancels every in-flight detached run and resolves every pending
// permission/elicitation as cancelled, so no ACP callback is left blocked
// when the process is asked to terminate.
func (c *Coordinator) Shutdown(ctx context.Context) {
	c.mu.Lock()
	runs := make([]*runHandle, 0, len(c.runs))
	for _, h := range c.runs {
		runs = append(runs, h)
	}
	pending := make([]*pendingPermission, 0, len(c.pending))
	for id, p := range c.pending {
		delete(c.pending, id)
		if p.timer != nil {
			p.timer.Stop()
		}
		pending = append(pending, p)
	}
	elicits := make([]*pendingElicitation, 0, len(c.elicits))
	for id, p := range c.elicits {
		delete(c.elicits, id)
		if p.timer != nil {
			p.timer.Stop()
		}
		elicits = append(elicits, p)
	}
	c.mu.Unlock()
	for _, h := range runs {
		if h.conn != nil {
			_ = h.conn.Cancel(ctx, acpsdk.CancelNotification{SessionId: acpsdk.SessionId(h.sessionID)})
		}
		h.cancel()
	}
	for _, p := range pending {
		select {
		case p.decision <- permissionDecision{cancelled: true}:
		default:
		}
	}
	for _, p := range elicits {
		select {
		case p.decision <- elicitationDecision{cancelled: true}:
		default:
		}
	}
}

// StartPrompt reserves chatID, spawns a detached run goroutine on a fresh
// context.Background()-derived ctx (which also doubles as the Goose dial ctx,
// spec N1), and returns the run id immediately. The run survives the caller
// returning: teardown fires on Prompt return / cancel / panic, last in the
// gate is always the release of Reserve so a second StartPrompt can take over.
func (c *Coordinator) StartPrompt(chatID, prompt string, resolve ResolveSession, profileFn ProfileFunc, created OnSessionCreated, finished OnRunFinished, opts ...RunOption) (string, error) {
	options := &runOptions{}
	for _, opt := range opts {
		opt(options)
	}
	if err := c.Reserve(chatID); err != nil {
		return "", err
	}
	runID := uuid.NewString()
	runCtx, cancel := context.WithCancel(context.Background())
	accepting := &atomic.Bool{}
	h := &runHandle{runID: runID, cancel: cancel, accepting: accepting}
	c.registerRun(chatID, h)
	go c.runLoop(runCtx, chatID, runID, prompt, h, resolve, profileFn, created, finished, options.onRunEnded, options.userMessageID)
	return runID, nil
}

// runLoop is the per-run goroutine. It owns the *one* sync.Once teardown,
// a single panic recover that publishes RUN_ERROR, and the publish-through-
// hub `emit` so RequestPermission (which also calls s.emit) remains safe on
// the detached path with no client lifetime dependency.
func (c *Coordinator) runLoop(runCtx context.Context, chatID, runID, prompt string, h *runHandle, resolve ResolveSession, profileFn ProfileFunc, created OnSessionCreated, finished OnRunFinished, onRunEnded func(context.Context, string, RunOutcome), userMessageID string) {
	hub := c.hubFor(chatID)
	outcome := RunFailed
	defer func() {
		// outcome is set inline in the function body (RunCompleted/
		// RunCancelled right before the pre-existing `finished` call, at
		// the true end of the happy path). Do NOT re-derive it from
		// runCtx.Err() here: teardown() (deferred below, so it runs
		// BEFORE this defer per LIFO order) unconditionally calls
		// h.cancel(), so runCtx is always already cancelled by the time
		// this fires -- re-checking it here would misclassify every
		// completed and every failed run as "cancelled".
		if onRunEnded != nil {
			onRunEnded(runCtx, chatID, outcome)
		}
	}()
	var bridge *agui.Bridge
	var once sync.Once
	teardown := func() {
		once.Do(func() {
			h.accepting.Store(false) // straggler SessionUpdates now return early
			c.stopTimers(h)
			if h.conn != nil {
				_ = h.conn.Close()
			}
			c.dropPendingForChat(chatID)
			if bridge != nil {
				for _, e := range bridge.CloseOpenTools() {
					hub.Publish(e)
				}
			}
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
			log.Printf("coordinator: run %s panicked: %v", runID, r)
			hub.Publish(events.NewRunErrorEvent("internal error", events.WithErrorCode("protocol_error")))
		}
	}()

	bridge = agui.NewBridge(chatID, runID)
	hub.StartRun(runID, bridge.Snapshot)

	if userMessageID != "" {
		hub.Publish(events.NewTextMessageStartEvent(userMessageID, events.WithRole("user")))
		hub.Publish(events.NewTextMessageContentEvent(userMessageID, prompt))
		hub.Publish(events.NewTextMessageEndEvent(userMessageID))
	}

	sessionID, err := resolve(runCtx)
	if err != nil {
		log.Printf("coordinator: session mapping failed for chat %s run %s: %v", chatID, runID, err)
		hub.Publish(events.NewRunErrorEvent("session mapping", events.WithErrorCode("goose_unavailable")))
		return
	}
	profile, err := profileFn(runCtx)
	if err != nil {
		log.Printf("coordinator: profile resolution failed for chat %s run %s: %v", chatID, runID, err)
		hub.Publish(events.NewRunErrorEvent("profile resolution", events.WithErrorCode("goose_unavailable")))
		return
	}

	// Detached path routes ALL client callbacks (SessionUpdate AND
	// RequestPermission — both call s.emit) through the hub, so emit is never
	// nil. accepting is the SHARED pointer from the runHandle.
	sc := &sessionClient{c: c, chatID: chatID, runID: runID, sessionID: sessionID, bridge: bridge,
		emit:      func(e events.Event) error { hub.Publish(e); return nil },
		accepting: h.accepting, maxEvents: c.maxRunEvents, cancel: h.cancel}

	conn, sessionID, modes, configOptions, _, wasNew, err := c.establishSession(runCtx, sc, profile, sessionID, func() {})
	if err != nil {
		log.Printf("coordinator: establishSession failed for chat %s run %s (provider %s): %v", chatID, runID, profile.Provider, err)
		hub.Publish(providerRunError(profile.AccountLogin, profile.HarnessName, "session init", err))
		return
	}
	h.conn = conn
	h.sessionID = sessionID
	sc.sessionID = sessionID
	sc.permissionRules = profile.PermissionRules

	if wasNew {
		if err := created(runCtx, sessionID); err != nil {
			if _, dErr := conn.UnstableDeleteSession(runCtx, acpsdk.UnstableDeleteSessionRequest{SessionId: acpsdk.SessionId(sessionID)}); dErr != nil {
				log.Printf("coordinator: orphan session delete failed: %v", dErr)
			}
			log.Printf("coordinator: created() failed for chat %s run %s (provider %s): %v", chatID, runID, profile.Provider, err)
			hub.Publish(events.NewRunErrorEvent("session init", events.WithErrorCode("goose_unavailable")))
			return
		}
	}

	for _, e := range bridge.SeedSession(modes, configOptions) {
		hub.Publish(e)
	}
	applier := selectApplier(profile)
	if err := applier.Apply(runCtx, conn, sessionID, profile, modes); err != nil {
		log.Printf("coordinator: applier.Apply failed for chat %s run %s (provider %s): %v", chatID, runID, profile.Provider, err)
		hub.Publish(providerRunError(profile.AccountLogin, profile.HarnessName, "session init", err))
		return
	}
	h.accepting.Store(true)
	hub.Publish(bridge.Started())

	maxTimer := c.clock.AfterFunc(c.maxRun, func() { h.cancel() })
	c.trackTimer(chatID, runID, maxTimer)

	promptReq := acpsdk.PromptRequest{
		SessionId: acpsdk.SessionId(sessionID),
		Prompt:    []acpsdk.ContentBlock{{Text: &acpsdk.ContentBlockText{Type: "text", Text: prompt}}},
	}
	if userMessageID != "" {
		promptReq.MessageId = &userMessageID
	}
	resp, err := conn.Prompt(runCtx, promptReq)
	if err != nil {
		code := "goose_unavailable"
		message := "goose turn failed"
		switch {
		case providerAuthFailure(profile.AccountLogin, err):
			code = providerAuthRequiredCode
			message = reauthRequiredMessage(profile.HarnessName)
		case providerApiKeyFailure(profile.AccountLogin, err):
			code = providerApiKeyInvalidCode
			message = apiKeyInvalidMessage(profile.HarnessName)
		}
		switch {
		case runCtx.Err() != nil:
			code = "run_timeout"
			// conn.Prompt erroring because runCtx was cancelled is exactly
			// what happens on both an explicit user Cancel and the
			// max-run timeout firing -- either way this is a cancelled
			// run, not a failed one, for onRunEnded's purposes.
			outcome = RunCancelled
		case isConnDone(conn):
			code = "connection_interrupted"
		}
		log.Printf("coordinator: conn.Prompt failed for chat %s run %s (provider %s, code %s): %v", chatID, runID, profile.Provider, code, err)
		hub.Publish(events.NewRunErrorEvent(message, events.WithErrorCode(code)))
		return
	}
	for _, e := range bridge.Finished(resp.StopReason) {
		hub.Publish(e)
	}
	if resp.StopReason == acpsdk.StopReasonCancelled || runCtx.Err() != nil {
		outcome = RunCancelled
	} else {
		outcome = RunCompleted
	}
	if finished != nil && resp.StopReason != acpsdk.StopReasonCancelled && runCtx.Err() == nil {
		_ = finished(runCtx, resp.StopReason)
	}
}

func providerRunError(accountLogin bool, harnessName, fallback string, err error) events.Event {
	switch {
	case providerAuthFailure(accountLogin, err):
		return events.NewRunErrorEvent(
			reauthRequiredMessage(harnessName),
			events.WithErrorCode(providerAuthRequiredCode),
		)
	case providerApiKeyFailure(accountLogin, err):
		return events.NewRunErrorEvent(
			apiKeyInvalidMessage(harnessName),
			events.WithErrorCode(providerApiKeyInvalidCode),
		)
	}
	return events.NewRunErrorEvent(fallback, events.WithErrorCode("goose_unavailable"))
}

// reauthRequiredMessage builds the reauth-required copy for whichever
// account-login harness actually failed, rather than a name hardcoded for
// one harness -- the client only keys off the event's error code today (see
// chat_cubit.dart), but this message is still surfaced through logs and any
// future client that reads it, so it should name the right harness.
func reauthRequiredMessage(harnessName string) string {
	if harnessName == "" {
		harnessName = "Your provider"
	}
	return harnessName + " reauthentication required. Your saved login was kept."
}
