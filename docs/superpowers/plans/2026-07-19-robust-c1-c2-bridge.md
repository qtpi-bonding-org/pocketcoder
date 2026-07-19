# Robust c1↔c2 (ACP) Bridge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn today's single-turn, happy-path coordinator into a durable, concurrent, fully-wired ACP bridge: runs survive client disconnect, any number of subscribers can join late and resume via a cursor without ever stalling the run, and every contract method (prompt, cancel, set_mode, set_config_option, permission, elicitation) plus lifecycle path is wired.

**Architecture:** Three phases. **Phase A** builds a pure, Goose-free run hub (`ChatHub` + `Subscriber` + chat-global seq log + injectable clock) — the keystone, deterministically testable and shippable on its own. **Phase B** reworks the coordinator so a run is detached (owns a `context.Background()`-derived ctx that is also the Goose dial ctx), publishes into its hub, and tears down idempotently. **Phase C** rewires the HTTP routes to the `prompt`(202)+`stream`(cursor) split, adds set_mode/set_config/elicitation, and hooks `chats` delete → `session/delete`.

**Tech Stack:** Go, PocketBase (`core`/`apis`), `coder/acp-go-sdk@v0.13.5`, `ag-ui-protocol/ag-ui` Go SDK, `coder/websocket`. Tests: stdlib `testing` (no new deps).

**Spec:** `docs/superpowers/specs/2026-07-19-robust-c1-c2-bridge-spec.md` (hardened per Opus review). Read it before starting.

## Global Constraints

- **Security (never violate):** c2 (Goose) must never receive a PocketBase token; the Goose secret (`GOOSE_SERVER__SECRET_KEY`) must never reach Flutter/browser; c2 has no DB path. AG-UI is a response *format*, not a second public service. Never log the Goose secret or a URL containing `?token=`.
- **Consumes the translation unit** `internal/agent/agui.Bridge` (sibling plan `2026-07-19-acp-agui-translation.md`). This plan **depends on that plan being merged first** — it uses `Bridge.{NewBridge,SeedSession,Started,Update,PermissionPending,ElicitationPending,ResolvePermission,ResolveElicitation,Snapshot,Finished}`. This plan additionally **changes** `Finished()` → `Finished(stopReason)` (Task 7) — the only translation-unit modification it owns.
- **`Snapshot()` is one merged `STATE_SNAPSHOT`** over all `/pocketcoder/*` namespaces (already true in the translation plan). The hub calls it; it does not reshape it.
- **Chat-global monotonic `seq`** (never per-run-from-1). The SSE `id:` is the seq. The stream cursor is the seq (`Last-Event-ID` / `?cursor=`). `runId` identifies a run for cancel/status only.
- **Keystone:** publishing a *live* event to a subscriber never blocks the run; a full live channel → drop that subscriber (close its channel). Backlog is a subscriber-owned unbounded slice and is never dropped.
- **Detached:** a run's lifetime is independent of any client connection. Client disconnect must NOT cancel a run.
- **Idempotent teardown** (`sync.Once`); `Reserve` released last; run goroutine `recover()`s and releases on panic.
- **Deterministic timers:** linger/max-run/elicitation timers go through an injectable `Clock` seam; no `time.Sleep` in unit tests.
- **Configurable (env, with defaults):** linger 30s (`GOOSE_LINGER_WINDOW`), max-run 15m (`GOOSE_MAX_RUN`), permission/elicitation timeout 5m (`GOOSE_PERMISSION_TIMEOUT`), per-run event cap 50000 (`GOOSE_MAX_RUN_EVENTS`).
- **Build/test dir:** all Go commands run from `services/pocketbase`. Package for hub/run: `internal/agent/coordinator`.
- **TDD:** every task is RED → GREEN → commit. Watch each test fail first.

---

## File Structure

- `internal/agent/coordinator/clock.go` (new) — `Clock`/`Timer` seam + real-clock impl.
- `internal/agent/coordinator/hub.go` (new) — `ChatHub`, `Subscriber`, chat-global seq log, subscriber-owned backlog + bounded live channel, fan-out, linger, teardown.
- `internal/agent/coordinator/hub_test.go` (new) — deterministic hub unit tests.
- `internal/agent/coordinator/run.go` (rework) — detached run lifecycle: background/dial ctx, publish-to-hub, `sync.Once` teardown, panic-recover, cancel triggers, orphan compensation.
- `internal/agent/coordinator/coordinator.go` (new, split from run.go) — `Coordinator` struct, `Reserve`/`release`/dispatch/`Shutdown`, hub registry.
- `internal/agent/coordinator/session.go` (new) — ACP init sequence (incl. `Elicitation` capability), modes/config seeding, elicitation handler, session `new`/`load`/`delete`.
- `internal/agent/coordinator/*_test.go` — lifecycle/method tests (fake `acp.Conn`).
- `internal/agent/acp/websocket.go` (modify) — extend `Conn` interface: `SetSessionConfigOption`, `UnstableDeleteSession`.
- `internal/agent/acp/client.go` or an added method on the client type — `UnstableCreateElicitation` handler wiring (see Task 12).
- `internal/agent/agui/bridge.go` (modify, Task 7) — `Finished(stopReason acpsdk.StopReason)`.
- `internal/api/agent.go` (rework) — routes: `POST …/session/prompt` (202), `GET …/stream?cursor=` (SSE `id:`), `POST …/session/cancel`, `…/set_mode`, `…/set_config_option`, `…/request_permission/{id}`, `…/elicitation/{id}`; `chats` delete hook.

---

## Phase A — The run hub (pure, deterministic, no Goose)

Ships and tests entirely standalone. No ACP, no Goose, no HTTP.

### Task 1: Clock seam

**Files:**
- Create: `internal/agent/coordinator/clock.go`
- Test: `internal/agent/coordinator/clock_test.go`

**Interfaces:**
- Produces: `type Clock interface { Now() time.Time; AfterFunc(d time.Duration, f func()) Timer }`, `type Timer interface { Stop() bool }`, `func RealClock() Clock`, and a test double `type fakeClock` with `Advance(d time.Duration)` and `func NewFakeClock(t time.Time) *fakeClock`.

- [ ] **Step 1: Write the failing test**

```go
package coordinator

import (
	"testing"
	"time"
)

func TestFakeClockFiresAfterFuncOnAdvance(t *testing.T) {
	clk := NewFakeClock(time.Unix(0, 0))
	fired := false
	timer := clk.AfterFunc(10*time.Second, func() { fired = true })
	clk.Advance(9 * time.Second)
	if fired {
		t.Fatal("timer fired before its deadline")
	}
	clk.Advance(1 * time.Second)
	if !fired {
		t.Fatal("timer did not fire at its deadline")
	}
	if timer.Stop() {
		t.Fatal("Stop() on an already-fired timer should return false")
	}
}

func TestFakeClockStopPreventsFire(t *testing.T) {
	clk := NewFakeClock(time.Unix(0, 0))
	fired := false
	timer := clk.AfterFunc(5*time.Second, func() { fired = true })
	if !timer.Stop() {
		t.Fatal("Stop() before deadline should return true")
	}
	clk.Advance(10 * time.Second)
	if fired {
		t.Fatal("stopped timer fired")
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/pocketbase && go test ./internal/agent/coordinator/ -run TestFakeClock -v`
Expected: FAIL — `undefined: NewFakeClock`.

- [ ] **Step 3: Write minimal implementation**

```go
package coordinator

import (
	"sync"
	"time"
)

type Timer interface{ Stop() bool }

type Clock interface {
	Now() time.Time
	AfterFunc(d time.Duration, f func()) Timer
}

// realClock delegates to the stdlib.
type realClock struct{}

func RealClock() Clock { return realClock{} }

func (realClock) Now() time.Time { return time.Now() }

func (realClock) AfterFunc(d time.Duration, f func()) Timer {
	return time.AfterFunc(d, f)
}

// fakeClock is a deterministic clock for tests. Advance drives all timers.
type fakeClock struct {
	mu     sync.Mutex
	now    time.Time
	timers []*fakeTimer
}

type fakeTimer struct {
	clk      *fakeClock
	deadline time.Time
	fn       func()
	done     bool
}

func NewFakeClock(t time.Time) *fakeClock { return &fakeClock{now: t} }

func (c *fakeClock) Now() time.Time {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.now
}

func (c *fakeClock) AfterFunc(d time.Duration, f func()) Timer {
	c.mu.Lock()
	defer c.mu.Unlock()
	t := &fakeTimer{clk: c, deadline: c.now.Add(d), fn: f}
	c.timers = append(c.timers, t)
	return t
}

// Advance moves time forward and fires every timer whose deadline has passed.
func (c *fakeClock) Advance(d time.Duration) {
	c.mu.Lock()
	c.now = c.now.Add(d)
	var due []*fakeTimer
	for _, t := range c.timers {
		if !t.done && !t.deadline.After(c.now) {
			t.done = true
			due = append(due, t)
		}
	}
	c.mu.Unlock()
	for _, t := range due {
		t.fn()
	}
}

func (t *fakeTimer) Stop() bool {
	t.clk.mu.Lock()
	defer t.clk.mu.Unlock()
	if t.done {
		return false
	}
	t.done = true
	return true
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd services/pocketbase && go test ./internal/agent/coordinator/ -run TestFakeClock -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add services/pocketbase/internal/agent/coordinator/clock.go services/pocketbase/internal/agent/coordinator/clock_test.go
git commit -m "feat(agent): injectable clock seam for deterministic timers"
```

---

### Task 2: Hub skeleton — chat-global seq, publish under lock, one subscriber

**Files:**
- Create: `internal/agent/coordinator/hub.go`
- Test: `internal/agent/coordinator/hub_test.go`

**Interfaces:**
- Consumes: `Clock` (Task 1); `events.Event` (AG-UI, `github.com/ag-ui-protocol/ag-ui/sdks/community/go/pkg/core/events`).
- Produces:
  - `type seqEvent struct { Seq int; Ev events.Event }`
  - `type Attachment struct { Snapshot []events.Event; Buffered []seqEvent; Live <-chan seqEvent; ColdReplayNeeded bool; Unsubscribe func() }`
  - `func NewChatHub(clock Clock, lingerWindow time.Duration, liveBuf int) *ChatHub`
  - `func (h *ChatHub) Publish(ev events.Event) int` — appends to the active run's log under the lock, assigns the next chat-global seq, fans out to live subscribers non-blocking, returns the assigned seq.
  - `func (h *ChatHub) StartRun(runID string, snapshot func() []events.Event)` — opens a new active run (chat-global seq continues).
  - `func (h *ChatHub) Attach(cursor int) Attachment` — Task 3.

- [ ] **Step 1: Write the failing test**

```go
package coordinator

import (
	"testing"
	"time"

	"github.com/ag-ui-protocol/ag-ui/sdks/community/go/pkg/core/events"
)

func textEv(s string) events.Event { return events.NewTextMessageContentEvent("m", s) }

func TestPublishAssignsChatGlobalSeqStartingAtOne(t *testing.T) {
	h := NewChatHub(NewFakeClock(time.Unix(0, 0)), 30*time.Second, 8)
	h.StartRun("run-1", func() []events.Event { return nil })
	if got := h.Publish(textEv("a")); got != 1 {
		t.Fatalf("first seq = %d, want 1", got)
	}
	if got := h.Publish(textEv("b")); got != 2 {
		t.Fatalf("second seq = %d, want 2", got)
	}
}

func TestSeqContinuesAcrossRuns(t *testing.T) {
	h := NewChatHub(NewFakeClock(time.Unix(0, 0)), 30*time.Second, 8)
	h.StartRun("run-1", func() []events.Event { return nil })
	h.Publish(textEv("a")) // 1
	h.Publish(textEv("b")) // 2
	h.StartRun("run-2", func() []events.Event { return nil })
	if got := h.Publish(textEv("c")); got != 3 {
		t.Fatalf("run-2 first seq = %d, want 3 (chat-global, not reset)", got)
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/pocketbase && go test ./internal/agent/coordinator/ -run 'TestPublishAssigns|TestSeqContinues' -v`
Expected: FAIL — `undefined: NewChatHub`.

- [ ] **Step 3: Write minimal implementation**

```go
package coordinator

import (
	"sync"
	"time"

	"github.com/ag-ui-protocol/ag-ui/sdks/community/go/pkg/core/events"
)

type seqEvent struct {
	Seq int
	Ev  events.Event
}

type subscriber struct {
	live   chan seqEvent
	cursor int
}

type run struct {
	id          string
	log         []seqEvent          // this run's events only (bounded by run length)
	snapshot    func() []events.Event
	finished    bool
	lingerTimer Timer
}

type ChatHub struct {
	mu           sync.Mutex
	seq          int // chat-global monotonic, never reset
	active       *run
	subs         map[*subscriber]struct{}
	clock        Clock
	lingerWindow time.Duration
	liveBuf      int
}

func NewChatHub(clock Clock, lingerWindow time.Duration, liveBuf int) *ChatHub {
	return &ChatHub{
		subs:         map[*subscriber]struct{}{},
		clock:        clock,
		lingerWindow: lingerWindow,
		liveBuf:      liveBuf,
	}
}

func (h *ChatHub) StartRun(runID string, snapshot func() []events.Event) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.active != nil && h.active.lingerTimer != nil {
		h.active.lingerTimer.Stop()
	}
	h.active = &run{id: runID, snapshot: snapshot}
}

func (h *ChatHub) Publish(ev events.Event) int {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.seq++
	item := seqEvent{Seq: h.seq, Ev: ev}
	if h.active != nil {
		h.active.log = append(h.active.log, item)
	}
	for s := range h.subs {
		select {
		case s.live <- item:
		default:
			// Full live channel: drop the subscriber (keystone). Its SSE
			// goroutine sees a closed channel and returns; client reconnects.
			close(s.live)
			delete(h.subs, s)
		}
	}
	return h.seq
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd services/pocketbase && go test ./internal/agent/coordinator/ -run 'TestPublishAssigns|TestSeqContinues' -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add services/pocketbase/internal/agent/coordinator/hub.go services/pocketbase/internal/agent/coordinator/hub_test.go
git commit -m "feat(agent): run hub skeleton with chat-global seq"
```

---

### Task 3: Atomic attach — subscriber-owned backlog + live tail, no gap/dup

**Files:**
- Modify: `internal/agent/coordinator/hub.go`
- Test: `internal/agent/coordinator/hub_test.go`

**Interfaces:**
- Produces: `func (h *ChatHub) Attach(cursor int) Attachment`. Under one lock hold: captures `Snapshot()` (from the active run, else nil) + this run's log entries with `Seq > cursor`, registers a live channel, releases. Sets `ColdReplayNeeded` when `cursor` precedes the buffered base (a gap was evicted) or there is no active run but the chat has emitted events (`cursor < h.seq`). Ordering invariant: every event delivered on `Live` has `Seq` strictly greater than every `Buffered` entry, because registration + capture are atomic.

- [ ] **Step 1: Write the failing test**

```go
func drain(ch <-chan seqEvent) []int {
	var out []int
	for e := range ch {
		out = append(out, e.Seq)
	}
	return out
}

func TestAttachBacklogLargerThanLiveBufferIsNotDropped(t *testing.T) {
	// Live buffer is tiny (2), but a 100-event backlog must survive intact:
	// backlog is subscriber-owned, only live delivery is drop-on-full.
	h := NewChatHub(NewFakeClock(time.Unix(0, 0)), 30*time.Second, 2)
	h.StartRun("run-1", func() []events.Event { return nil })
	for i := 0; i < 100; i++ {
		h.Publish(textEv("x"))
	}
	att := h.Attach(0) // cursor 0 => wants everything
	if att.ColdReplayNeeded {
		t.Fatal("buffered run present; cold replay must not be needed")
	}
	if len(att.Buffered) != 100 {
		t.Fatalf("buffered = %d, want 100 (backlog must not drop)", len(att.Buffered))
	}
	if att.Buffered[0].Seq != 1 || att.Buffered[99].Seq != 100 {
		t.Fatalf("backlog seq range = [%d..%d], want [1..100]", att.Buffered[0].Seq, att.Buffered[99].Seq)
	}
	att.Unsubscribe()
}

func TestAttachThenLiveHasNoGapOrDup(t *testing.T) {
	h := NewChatHub(NewFakeClock(time.Unix(0, 0)), 30*time.Second, 16)
	h.StartRun("run-1", func() []events.Event { return nil })
	h.Publish(textEv("a")) // 1
	h.Publish(textEv("b")) // 2
	att := h.Attach(0)
	// live events after attach:
	h.Publish(textEv("c")) // 3
	h.Publish(textEv("d")) // 4
	att.Unsubscribe()      // closes live channel so drain terminates
	var seqs []int
	for _, b := range att.Buffered {
		seqs = append(seqs, b.Seq)
	}
	seqs = append(seqs, drain(att.Live)...)
	want := []int{1, 2, 3, 4}
	if len(seqs) != 4 {
		t.Fatalf("got seqs %v, want %v", seqs, want)
	}
	for i := range want {
		if seqs[i] != want[i] {
			t.Fatalf("got seqs %v, want %v", seqs, want)
		}
	}
}

func TestAttachCursorAheadOfLogGetsOnlyLive(t *testing.T) {
	h := NewChatHub(NewFakeClock(time.Unix(0, 0)), 30*time.Second, 16)
	h.StartRun("run-1", func() []events.Event { return nil })
	h.Publish(textEv("a")) // 1
	h.Publish(textEv("b")) // 2
	att := h.Attach(2) // caller already saw up to seq 2
	if len(att.Buffered) != 0 {
		t.Fatalf("buffered = %d, want 0 (cursor up to date)", len(att.Buffered))
	}
	if att.ColdReplayNeeded {
		t.Fatal("cursor within buffered range must not need cold replay")
	}
	att.Unsubscribe()
}

func TestAttachEvictedGapNeedsColdReplay(t *testing.T) {
	h := NewChatHub(NewFakeClock(time.Unix(0, 0)), 30*time.Second, 16)
	h.StartRun("run-1", func() []events.Event { return nil })
	h.Publish(textEv("a")) // 1
	h.Publish(textEv("b")) // 2
	// Simulate run 2 whose log base is seq 5 (events 3,4 evicted with run 1).
	h.StartRun("run-2", func() []events.Event { return nil })
	h.seqForTest(4) // advance chat-global seq to 4 without buffering (test helper)
	h.Publish(textEv("e")) // 5
	att := h.Attach(2)     // wants > 2, but log base is 5 => gap at 3,4
	if !att.ColdReplayNeeded {
		t.Fatal("cursor precedes buffered base; cold replay required")
	}
	att.Unsubscribe()
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/pocketbase && go test ./internal/agent/coordinator/ -run TestAttach -v`
Expected: FAIL — `undefined: (*ChatHub).Attach` / `seqForTest`.

- [ ] **Step 3: Write minimal implementation**

Add to `hub.go`:

```go
type Attachment struct {
	Snapshot         []events.Event // Bridge.Snapshot() at join; flushed first
	Buffered         []seqEvent     // in-memory log with Seq > cursor
	Live             <-chan seqEvent
	ColdReplayNeeded bool // caller must Goose-replay history before flushing
	Unsubscribe      func()
}

func (h *ChatHub) Attach(cursor int) Attachment {
	h.mu.Lock()
	defer h.mu.Unlock()

	s := &subscriber{live: make(chan seqEvent, h.liveBuf), cursor: cursor}
	h.subs[s] = struct{}{}

	att := Attachment{Live: s.live, Unsubscribe: func() { h.unsubscribe(s) }}

	if h.active == nil {
		// No buffered run. If the chat has emitted anything past the cursor,
		// the only source of that history is Goose.
		att.ColdReplayNeeded = cursor < h.seq
		return att
	}

	att.Snapshot = h.active.snapshot()

	log := h.active.log
	if len(log) == 0 {
		// Active run with no events yet: nothing buffered, nothing evicted.
		return att
	}
	base := log[0].Seq
	if cursor < base-1 {
		// Gap: events (cursor, base) were evicted with a prior run.
		att.ColdReplayNeeded = true
		return att
	}
	for _, e := range log {
		if e.Seq > cursor {
			att.Buffered = append(att.Buffered, e)
		}
	}
	return att
}

func (h *ChatHub) unsubscribe(s *subscriber) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if _, ok := h.subs[s]; ok {
		delete(h.subs, s)
		close(s.live)
	}
}

// seqForTest advances the chat-global seq without buffering, simulating events
// evicted with a prior run. Test-only.
func (h *ChatHub) seqForTest(to int) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if to > h.seq {
		h.seq = to
	}
}
```

Note: `Unsubscribe` calling `close(s.live)` is safe against `Publish`'s drop-close because both hold `h.mu` and both check membership in `h.subs` before closing — no double close.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd services/pocketbase && go test ./internal/agent/coordinator/ -run TestAttach -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add services/pocketbase/internal/agent/coordinator/hub.go services/pocketbase/internal/agent/coordinator/hub_test.go
git commit -m "feat(agent): atomic hub attach with subscriber-owned backlog"
```

---

### Task 4: Slow-subscriber drop + cursor resume

**Files:**
- Modify: `internal/agent/coordinator/hub_test.go` (behavior already implemented in Task 2's `Publish`; this task proves it and adds resume).

**Interfaces:**
- Consumes: `Publish`, `Attach`, `Unsubscribe`.

- [ ] **Step 1: Write the failing test**

```go
func TestSlowSubscriberDroppedWhenLiveFull(t *testing.T) {
	h := NewChatHub(NewFakeClock(time.Unix(0, 0)), 30*time.Second, 2) // tiny live buffer
	h.StartRun("run-1", func() []events.Event { return nil })
	att := h.Attach(0) // subscriber never drains
	// Publish more than the buffer can hold; the subscriber must be dropped,
	// and the run (Publish) must keep working and keep assigning seq.
	var last int
	for i := 0; i < 10; i++ {
		last = h.Publish(textEv("x"))
	}
	if last != 10 {
		t.Fatalf("run stalled: last seq = %d, want 10", last)
	}
	if _, more := <-att.Live; more {
		// Channel should be closed (dropped) — a closed channel yields !more.
		t.Fatal("slow subscriber was not dropped (live channel still open)")
	}
}

func TestCursorResumeAfterDrop(t *testing.T) {
	h := NewChatHub(NewFakeClock(time.Unix(0, 0)), 30*time.Second, 2)
	h.StartRun("run-1", func() []events.Event { return nil })
	att1 := h.Attach(0)
	for i := 0; i < 10; i++ {
		h.Publish(textEv("x")) // drops att1 partway
	}
	// Reconnect with the last seq the client actually saw (say 1).
	att2 := h.Attach(1)
	if att2.ColdReplayNeeded {
		t.Fatal("run still buffered; resume must be from memory")
	}
	if len(att2.Buffered) != 9 { // seqs 2..10
		t.Fatalf("resume buffered = %d, want 9", len(att2.Buffered))
	}
	if att2.Buffered[0].Seq != 2 {
		t.Fatalf("resume starts at seq %d, want 2", att2.Buffered[0].Seq)
	}
	att2.Unsubscribe()
	_ = att1
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/pocketbase && go test ./internal/agent/coordinator/ -run 'TestSlowSubscriber|TestCursorResume' -v`
Expected: The drop test should already PASS (Task 2 implemented drop-on-full); the resume test should PASS too. If either fails, the drop/close logic in `Publish` or `Attach` buffered-range is wrong — fix it before proceeding. (This task is a proof task; if both already pass, note that in the commit.)

- [ ] **Step 3: Confirm implementation (no new code expected)**

Task 2/3 already implement drop-on-full and cursor-range buffering. If a test fails, the minimal fix is in `Publish` (drop-close) or `Attach` (`e.Seq > cursor`). Make it pass.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd services/pocketbase && go test ./internal/agent/coordinator/ -run 'TestSlowSubscriber|TestCursorResume' -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add services/pocketbase/internal/agent/coordinator/hub_test.go
git commit -m "test(agent): prove slow-subscriber drop and cursor resume"
```

---

### Task 5: Snapshot injection on join

**Files:**
- Modify: `internal/agent/coordinator/hub_test.go`

**Interfaces:**
- Consumes: `StartRun(runID, snapshot)`, `Attach`.

- [ ] **Step 1: Write the failing test**

```go
func TestAttachIncludesSnapshotFromActiveRun(t *testing.T) {
	snap := []events.Event{events.NewStateSnapshotEvent(map[string]any{
		"pocketcoder": map[string]any{"modes": "x"},
	})}
	h := NewChatHub(NewFakeClock(time.Unix(0, 0)), 30*time.Second, 8)
	h.StartRun("run-1", func() []events.Event { return snap })
	h.Publish(textEv("a"))
	att := h.Attach(0)
	if len(att.Snapshot) != 1 || att.Snapshot[0].Type() != events.EventTypeStateSnapshot {
		t.Fatalf("attach must carry one STATE_SNAPSHOT from the active run, got %v", att.Snapshot)
	}
	att.Unsubscribe()
}
```

(Verify the constant name for the snapshot event type at impl time: `grep -rn "EventTypeStateSnapshot\|STATE_SNAPSHOT" $(go env GOMODCACHE)/github.com/ag-ui-protocol/ag-ui*/.../pkg/core/events/`. If the SDK exposes it as a string only, assert `att.Snapshot[0].Type() == events.EventType("STATE_SNAPSHOT")`.)

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/pocketbase && go test ./internal/agent/coordinator/ -run TestAttachIncludesSnapshot -v`
Expected: PASS immediately IF Task 3 wired `att.Snapshot = h.active.snapshot()`. If it fails, wire it. (Proof task confirming the snapshot seam.)

- [ ] **Step 3: Confirm/fix implementation**

`Attach` already sets `att.Snapshot = h.active.snapshot()` (Task 3). Ensure the constant used in the assertion matches the SDK.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd services/pocketbase && go test ./internal/agent/coordinator/ -run TestAttachIncludesSnapshot -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add services/pocketbase/internal/agent/coordinator/hub_test.go
git commit -m "test(agent): attach injects active-run STATE_SNAPSHOT"
```

---

### Task 6: Linger, evict, and hub emptiness

**Files:**
- Modify: `internal/agent/coordinator/hub.go`
- Test: `internal/agent/coordinator/hub_test.go`

**Interfaces:**
- Produces:
  - `func (h *ChatHub) FinishRun()` — marks the active run finished and starts the linger timer (via `h.clock.AfterFunc`); on expiry the run's log is evicted (`h.active = nil`), so post-eviction attaches fall to cold replay.
  - `func (h *ChatHub) IsEmpty() bool` — true when there are no subscribers and no active/lingering run (used by the coordinator to remove the hub).
  - `func (h *ChatHub) evictNow()` — test-only: force the linger timer to fire immediately.

- [ ] **Step 1: Write the failing test**

```go
func TestLingerThenEvictFallsToColdReplay(t *testing.T) {
	clk := NewFakeClock(time.Unix(0, 0))
	h := NewChatHub(clk, 30*time.Second, 8)
	h.StartRun("run-1", func() []events.Event { return nil })
	h.Publish(textEv("a")) // 1
	h.FinishRun()

	// Within the linger window, a tail reconnect still resumes from memory.
	att := h.Attach(0)
	if att.ColdReplayNeeded {
		t.Fatal("within linger window, reconnect must resume from buffer")
	}
	if len(att.Buffered) != 1 {
		t.Fatalf("linger buffered = %d, want 1", len(att.Buffered))
	}
	att.Unsubscribe()

	// After the window, the run is evicted; reconnect needs cold replay.
	clk.Advance(31 * time.Second)
	att2 := h.Attach(0)
	if !att2.ColdReplayNeeded {
		t.Fatal("after eviction, reconnect must fall to cold replay")
	}
	att2.Unsubscribe()
}

func TestIsEmptyAfterEvictionAndNoSubscribers(t *testing.T) {
	clk := NewFakeClock(time.Unix(0, 0))
	h := NewChatHub(clk, 30*time.Second, 8)
	h.StartRun("run-1", func() []events.Event { return nil })
	h.Publish(textEv("a"))
	h.FinishRun()
	if h.IsEmpty() {
		t.Fatal("hub with a lingering run is not empty")
	}
	clk.Advance(31 * time.Second)
	if !h.IsEmpty() {
		t.Fatal("hub with no run and no subscribers should be empty")
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/pocketbase && go test ./internal/agent/coordinator/ -run 'TestLinger|TestIsEmpty' -v`
Expected: FAIL — `undefined: (*ChatHub).FinishRun`.

- [ ] **Step 3: Write minimal implementation**

Add to `hub.go`:

```go
func (h *ChatHub) FinishRun() {
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.active == nil || h.active.finished {
		return
	}
	h.active.finished = true
	r := h.active
	r.lingerTimer = h.clock.AfterFunc(h.lingerWindow, func() {
		h.mu.Lock()
		defer h.mu.Unlock()
		if h.active == r { // still the same lingering run
			h.active = nil
		}
	})
}

func (h *ChatHub) IsEmpty() bool {
	h.mu.Lock()
	defer h.mu.Unlock()
	return len(h.subs) == 0 && h.active == nil
}

// evictNow forces the lingering run to be evicted immediately. Test-only.
func (h *ChatHub) evictNow() {
	h.mu.Lock()
	r := h.active
	h.mu.Unlock()
	if r != nil && r.lingerTimer != nil {
		r.lingerTimer.Stop()
	}
	h.mu.Lock()
	if h.active == r {
		h.active = nil
	}
	h.mu.Unlock()
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd services/pocketbase && go test ./internal/agent/coordinator/ -run 'TestLinger|TestIsEmpty' -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add services/pocketbase/internal/agent/coordinator/hub.go services/pocketbase/internal/agent/coordinator/hub_test.go
git commit -m "feat(agent): hub linger-then-evict and emptiness"
```

---

## Phase B — Detached run lifecycle

Phase B consumes Phase A's hub and the translation `Bridge`. It **requires the translation plan merged first** (so `bridge.go` is the translation unit's version, with `SeedSession`/`Snapshot`/`Resolve*`/`ElicitationPending`). Unit tests use a fake `acp.Conn`; live Goose is Task 16.

**Green-build discipline (read before starting Phase B):** the current `internal/api/agent.go` (lines 71, 119) calls `service.RunReserved`/`service.ReplayReserved`, and `internal/agent/coordinator/live_test.go` (`//go:build live_acp`) calls `service.Run`/`RunRequest`. To keep `go build ./...` and `go test ./...` green at **every** commit, Phase B **adds the detached path alongside** the legacy `Run`/`Replay`/`RunReserved`/`ReplayReserved`/`activeRun`/`startRun`/`finishRun`/`cancelOnClientDisconnect` — it deletes none of them. All legacy removal happens in **one coherent commit at Task 14** (the transport cutover), which rewrites the API routes, deletes the now-dead coordinator methods, and fixes the two legacy unit tests together. Task 16 replaces the legacy `live_test.go`.

### Task 7: Extend `acp.Conn` (config-option, delete)

Done first because Task 11/12 production code calls these methods through the `Conn` interface, and `fakeConn` must implement them before the interface requires them.

**Files:**
- Modify: `internal/agent/acp/websocket.go`
- Modify: `internal/agent/coordinator/run_test.go` (add the two methods to the existing `fakeConn` so it keeps satisfying `acp.Conn`)

**Interfaces:**
- Produces on `Conn`: `SetSessionConfigOption(context.Context, acpsdk.SetSessionConfigOptionRequest) (acpsdk.SetSessionConfigOptionResponse, error)` and `UnstableDeleteSession(context.Context, acpsdk.UnstableDeleteSessionRequest) (acpsdk.UnstableDeleteSessionResponse, error)`. `sdkConn` satisfies both by embedding `*acpsdk.ClientSideConnection` (methods exist at `client_gen.go:304`, `:271`) — no method bodies needed on `sdkConn`.

- [ ] **Step 1: Write the failing state (compile assertion)**

Add to `websocket.go` (after the `Conn` interface):

```go
var _ Conn = (*sdkConn)(nil)
```

And add the two methods to the existing `fakeConn` in `run_test.go` (delegating to nothing — the fake records/returns zero values):

```go
func (f *fakeConn) SetSessionConfigOption(context.Context, acpsdk.SetSessionConfigOptionRequest) (acpsdk.SetSessionConfigOptionResponse, error) {
	return acpsdk.SetSessionConfigOptionResponse{}, nil
}
func (f *fakeConn) UnstableDeleteSession(_ context.Context, req acpsdk.UnstableDeleteSessionRequest) (acpsdk.UnstableDeleteSessionResponse, error) {
	f.mu.Lock()
	f.deletedSession = string(req.SessionId)
	f.mu.Unlock()
	return acpsdk.UnstableDeleteSessionResponse{}, nil
}
```

(Add a `deletedSession string` field to `fakeConn` now — it is used again in Task 12.)

- [ ] **Step 2: Run to verify it fails**

Run: `cd services/pocketbase && go vet ./internal/agent/acp/ ./internal/agent/coordinator/`
Expected: FAIL — before adding the two methods to the `Conn` interface, `*fakeConn` now has extra methods (harmless) but `sdkConn` does NOT yet need them; the real RED is that removing the old interface and adding the new methods must compile. Simpler RED: temporarily reference `var _ interface{ UnstableDeleteSession(context.Context, acpsdk.UnstableDeleteSessionRequest) (acpsdk.UnstableDeleteSessionResponse, error) } = (Conn)(nil)` in a scratch test — it fails until the interface gains the method. (This task's true verification is that the package compiles with the extended interface AND `sdkConn` still satisfies it via embedding.)

- [ ] **Step 3: Write the implementation**

Extend the `Conn` interface in `websocket.go`:

```go
type Conn interface {
	Initialize(context.Context, acpsdk.InitializeRequest) (acpsdk.InitializeResponse, error)
	NewSession(context.Context, acpsdk.NewSessionRequest) (acpsdk.NewSessionResponse, error)
	LoadSession(context.Context, acpsdk.LoadSessionRequest) (acpsdk.LoadSessionResponse, error)
	SetSessionMode(context.Context, acpsdk.SetSessionModeRequest) (acpsdk.SetSessionModeResponse, error)
	SetSessionConfigOption(context.Context, acpsdk.SetSessionConfigOptionRequest) (acpsdk.SetSessionConfigOptionResponse, error)
	Prompt(context.Context, acpsdk.PromptRequest) (acpsdk.PromptResponse, error)
	Cancel(context.Context, acpsdk.CancelNotification) error
	UnstableDeleteSession(context.Context, acpsdk.UnstableDeleteSessionRequest) (acpsdk.UnstableDeleteSessionResponse, error)
	Close() error
}

var _ Conn = (*sdkConn)(nil)
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd services/pocketbase && go build ./... && go test ./internal/agent/acp/ ./internal/agent/coordinator/ -run TestReserve -v`
Expected: PASS (whole module still builds; `sdkConn` satisfies the extended interface by embedding; `fakeConn` satisfies it with the two added methods).

- [ ] **Step 5: Commit**

```bash
git add services/pocketbase/internal/agent/acp/websocket.go services/pocketbase/internal/agent/coordinator/run_test.go
git commit -m "feat(agent): extend acp.Conn with config-option and delete"
```

---

### Task 8: `Bridge.Finished(stopReason)`

**Files:**
- Modify: `internal/agent/agui/bridge.go`
- Modify: `internal/agent/agui/bridge_test.go` (update existing arg-less `Finished()` call sites)
- Modify: `internal/agent/coordinator/run.go` (update legacy `Finished()` call sites so the coordinator package still builds — these lines are rewritten/removed in Task 14)

**Interfaces:**
- Produces: `func (b *Bridge) Finished(stopReason acpsdk.StopReason) []events.Event` — `StopReasonEndTurn` → `RUN_FINISHED` with success outcome; any other stop → `RUN_FINISHED` carrying `{"stopReason": <value>}` as its result (non-success).

**Critical (Sonnet): update ALL call sites in this one commit** or the build breaks between here and Task 14. After the translation unit is merged, call sites of `Finished()` are: the translation unit's `bridge_test.go` (grep to find them), and `run.go` (the legacy `Run`/`Replay` paths — current lines ~241, ~256, ~328). Update every one to pass a `StopReason`; the legacy paths pass `acpsdk.StopReasonEndTurn` as a stopgap.

- [ ] **Step 1: Write the failing test**

```go
package agui

import (
	"testing"

	"github.com/ag-ui-protocol/ag-ui/sdks/community/go/pkg/core/events"
	acpsdk "github.com/coder/acp-go-sdk"
)

func TestFinishedSuccessOnEndTurn(t *testing.T) {
	b := NewBridge("chat", "run")
	evs := b.Finished(acpsdk.StopReasonEndTurn)
	if len(evs) == 0 || evs[len(evs)-1].Type() != events.EventTypeRunFinished {
		t.Fatalf("expected trailing RUN_FINISHED, got %v", evs)
	}
}

func TestFinishedCarriesStopReasonOnNonEndTurn(t *testing.T) {
	b := NewBridge("chat", "run")
	evs := b.Finished(acpsdk.StopReasonRefusal)
	if len(evs) == 0 || evs[len(evs)-1].Type() != events.EventTypeRunFinished {
		t.Fatalf("expected RUN_FINISHED on refusal, got %v", evs)
	}
	fin := evs[len(evs)-1].(*events.RunFinishedEvent)
	if fin.Result == nil {
		t.Fatal("non-end_turn stop must attach a Result carrying the stopReason")
	}
}
```

(Confirm the field is `RunFinishedEvent.Result` at impl time: `grep -n "Result" $(go env GOMODCACHE)/github.com/ag-ui-protocol/ag-ui*/.../pkg/core/events/run_events.go`.)

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/pocketbase && go test ./internal/agent/agui/ -run TestFinished -v`
Expected: FAIL — `not enough arguments in call to b.Finished` (signature is still arg-less).

- [ ] **Step 3: Write minimal implementation**

Update `Finished` in `bridge.go` (current construction is at ~`bridge.go:135`, using `NewRunFinishedEventWithOptions(... WithSuccessOutcome())` in the translation unit). Keep its existing close-message/close-reasoning/close-open-tools prologue; only change the terminal event:

```go
func (b *Bridge) Finished(stopReason acpsdk.StopReason) []events.Event {
	out := b.closeMessage()
	out = append(out, b.closeReasoning()...)
	for id := range b.openTools {
		out = append(out, events.NewToolCallEndEvent(id))
	}
	opts := []events.RunFinishedOption{events.WithSuccessOutcome()}
	if stopReason != acpsdk.StopReasonEndTurn {
		opts = []events.RunFinishedOption{events.WithResult(map[string]any{"stopReason": string(stopReason)})}
	}
	return append(out, events.NewRunFinishedEventWithOptions(b.threadID, b.runID, opts...))
}
```

(`NewRunFinishedEvent` takes NO options — use `NewRunFinishedEventWithOptions` (`run_events.go:133`). Field names `threadID`/`runID`/`openTools`/`closeMessage`/`closeReasoning` must match the translation unit's actual `bridge.go`; verify at impl.)

Then update every remaining call site:

```bash
cd services/pocketbase
grep -rn "\.Finished()" internal/agent
# In bridge_test.go: replace `.Finished()` -> `.Finished(acpsdk.StopReasonEndTurn)` (add the acpsdk import if absent).
# In run.go legacy paths: replace `.Finished()` -> `.Finished(acpsdk.StopReasonEndTurn)`.
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd services/pocketbase && go build ./... && go test ./internal/agent/agui/ -run TestFinished -v && go test ./internal/agent/coordinator/ -run TestReserve -v`
Expected: PASS, and the whole module still builds (all call sites updated).

- [ ] **Step 5: Commit**

```bash
git add services/pocketbase/internal/agent/agui/bridge.go services/pocketbase/internal/agent/agui/bridge_test.go services/pocketbase/internal/agent/coordinator/run.go
git commit -m "feat(agui): Finished maps stopReason to run outcome"
```

---

### Task 9: Coordinator plumbing — Config, hub registry, run registry

Builds all the Coordinator-level state the detached run needs, as a tested unit, so Task 10 is pure lifecycle wiring (fixes Sonnet's "Task 9 boils the ocean").

**Files:**
- Modify: `internal/agent/coordinator/run.go` (or a new `coordinator.go` — either is fine; keep `New`/`Config` where they are)
- Test: `internal/agent/coordinator/registry_test.go`

**Interfaces:**
- `Config` gains: `Clock Clock`, `LingerWindow, MaxRun, ElicitationTimeout time.Duration`, `MaxRunEvents, LiveBuffer int`. `New` applies defaults: `Clock`→`RealClock()`, `LingerWindow`→30s, `MaxRun`→15m, `ElicitationTimeout`→`PermissionTimeout` (or 5m), `MaxRunEvents`→50000, `LiveBuffer`→256. Store `clock`, the durations, and caps on `Coordinator`; init `hubs map[string]*ChatHub{}` and `runs map[string]*runHandle{}`.
- `type runHandle struct { runID, sessionID string; cancel context.CancelFunc; conn acp.Conn; accepting *atomic.Bool; events atomic.Int64; timers []Timer; teardown func(release bool) }`
- `func (c *Coordinator) hubFor(chatID string) *ChatHub` / `func (c *Coordinator) reapHub(chatID string)` (as specified earlier).
- `func (c *Coordinator) Attach(chatID string, cursor int) Attachment` — pass-through to `c.hubFor(chatID).Attach(cursor)` (consumed by the stream route, Task 14).
- Run registry (all guarded by `c.mu`): `registerRun(chatID string, h *runHandle)`, `runFor(chatID string) *runHandle`, `clearRun(chatID, runID string)` (delete only if `runID` matches), `trackTimer(chatID, runID string, t Timer)`, `stopTimers(h *runHandle)`.
- `func (c *Coordinator) isReserved(chatID string) bool` (test/introspection: is `chatID` in `running`).

- [ ] **Step 1: Write the failing test**

```go
package coordinator

import (
	"testing"
	"time"
)

func newTestCoordinatorClk(t *testing.T, clk Clock) *Coordinator {
	t.Helper()
	c, err := New(Config{GooseURL: "ws://x", GooseSecret: "s", Workspace: "/w", Clock: clk})
	if err != nil {
		t.Fatal(err)
	}
	return c
}

func TestHubForReturnsSameHubPerChat(t *testing.T) {
	c := newTestCoordinatorClk(t, NewFakeClock(time.Unix(0, 0)))
	if c.hubFor("A") != c.hubFor("A") {
		t.Fatal("same chat must map to the same hub")
	}
	if c.hubFor("A") == c.hubFor("B") {
		t.Fatal("different chats must map to different hubs")
	}
}

func TestReapHubRemovesEmptyHub(t *testing.T) {
	c := newTestCoordinatorClk(t, NewFakeClock(time.Unix(0, 0)))
	h := c.hubFor("A")
	c.reapHub("A")
	if c.hubFor("A") == h {
		t.Fatal("empty hub should have been reaped")
	}
}

func TestRunRegistryRegisterFindClear(t *testing.T) {
	c := newTestCoordinatorClk(t, NewFakeClock(time.Unix(0, 0)))
	h := &runHandle{runID: "r1", sessionID: "s1"}
	c.registerRun("A", h)
	if c.runFor("A") != h {
		t.Fatal("runFor must return the registered handle")
	}
	c.clearRun("A", "other") // wrong runID: must NOT delete
	if c.runFor("A") != h {
		t.Fatal("clearRun with a mismatched runID must not delete")
	}
	c.clearRun("A", "r1")
	if c.runFor("A") != nil {
		t.Fatal("clearRun with the matching runID must delete")
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/pocketbase && go test ./internal/agent/coordinator/ -run 'TestHubFor|TestReapHub|TestRunRegistry' -v`
Expected: FAIL — `Config` has no `Clock` / `undefined: runHandle` / `undefined: (*Coordinator).hubFor`.

- [ ] **Step 3: Write minimal implementation**

Extend `Config`/`New` (defaults above), add fields to `Coordinator` (`clock Clock`, `hubs map[string]*ChatHub`, `runs map[string]*runHandle`, `lingerWindow/maxRun/elicitationTimeout time.Duration`, `maxRunEvents/liveBuf int`), and:

```go
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
```

Add `import "sync/atomic"` if not present (it already is, `run.go:8`). Define `runHandle` as above.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd services/pocketbase && go test ./internal/agent/coordinator/ -run 'TestHubFor|TestReapHub|TestRunRegistry' -v && go build ./...`
Expected: PASS + module builds.

- [ ] **Step 5: Commit**

```bash
git add services/pocketbase/internal/agent/coordinator/
git commit -m "feat(agent): coordinator hub registry, run registry, clock config"
```

---

### Task 10: Detached run — `StartPrompt`/`runLoop`, idempotent teardown, panic-recover

Adds the detached path **alongside** legacy (no deletions). Extends the existing `fakeConn` additively.

**Files:**
- Modify: `internal/agent/coordinator/run.go`
- Modify: `internal/agent/coordinator/run_test.go` (extend `fakeConn`; add helpers)
- Modify: `internal/agent/coordinator/session.go` (new file — `initializeRequest` already exists in run.go; move the init sequence here or keep in run.go)

**Interfaces:**
- Produces: `func (c *Coordinator) StartPrompt(chatID, prompt string, resolve ResolveSession, created OnSessionCreated) (runID string, err error)` — `Reserve`, spawn `runLoop` on a `context.Background()`-derived ctx (also the Goose dial ctx), return `runID` immediately.
- `func (c *Coordinator) waitRunDone(t *testing.T, chatID string)` (test helper) — polls `!isReserved(chatID)` with a 2s timeout (teardown releases `Reserve` last, so this is the "fully torn down" signal).
- Consumes: `hubFor`, run registry (Task 9), `Bridge` (`NewBridge`, `Snapshot`, `Started`, `Finished`, `SeedSession`), `acp.Conn`.

**Extend `fakeConn`** (additive — existing zero-value construction in legacy tests still works). Add fields `closeCount int`, `blockPrompt chan struct{}`, `panicOnPrompt bool`, `promptCalled chan struct{}`, `emitElicitation bool`, `elicitationResolved bool`, `lastMode string` (`deletedSession` added in Task 7). Rewrite `Prompt`/`Close`/`SetSessionMode`:

```go
func (f *fakeConn) SetSessionMode(_ context.Context, req acpsdk.SetSessionModeRequest) (acpsdk.SetSessionModeResponse, error) {
	f.mu.Lock()
	f.lastMode = string(req.ModeId)
	f.mu.Unlock()
	return acpsdk.SetSessionModeResponse{}, nil
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
func (f *fakeConn) Close() error {
	f.mu.Lock()
	f.closeCount++
	f.mu.Unlock()
	return nil
}
```

The dial closure in tests must capture the client: `Dial: func(_ context.Context, client acpsdk.Client) (acp.Conn, error) { f.client = client; return f, nil }`. Add a helper:

```go
func testCoordinatorWithConn(t *testing.T, f *fakeConn, clk Clock) *Coordinator {
	t.Helper()
	c, err := New(Config{GooseURL: "ws://x", GooseSecret: "s", Workspace: "/w", Clock: clk,
		Dial: func(_ context.Context, client acpsdk.Client) (acp.Conn, error) { f.client = client; return f, nil }})
	if err != nil {
		t.Fatal(err)
	}
	return c
}
func newFakeConn() *fakeConn { return &fakeConn{promptCalled: make(chan struct{}, 1)} }
func (f *fakeConn) waitForPrompt(t *testing.T) {
	t.Helper()
	select {
	case <-f.promptCalled:
	case <-time.After(2 * time.Second):
		t.Fatal("Prompt was not called")
	}
}
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
```

- [ ] **Step 1: Write the failing test**

```go
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/pocketbase && go test ./internal/agent/coordinator/ -run 'TestStartPromptDetached|TestTeardownIdempotent|TestPanicInProduce' -v`
Expected: FAIL — `undefined: (*Coordinator).StartPrompt`.

- [ ] **Step 3: Write minimal implementation**

Add to `run.go` (do NOT remove legacy methods):

```go
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

	sc := &sessionClient{c: c, chatID: chatID, runID: runID, sessionID: sessionID, bridge: bridge,
		accepting: h.accepting, hub: hub, maxEvents: c.maxRunEvents, cancel: h.cancel}
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
```

Extend `sessionClient` (additive fields, keep the legacy `emit`): add `runID string`, `accepting *atomic.Bool` (replace the value `atomic.Bool` — see note), `hub *ChatHub`, `maxEvents int`, `cancel context.CancelFunc`, `events atomic.Int64`. **Note:** the existing `sessionClient.accepting` is a value `atomic.Bool` (`run.go:137`) used by legacy `RunReserved`. To avoid disturbing legacy, keep that field and ADD a pointer field `acceptingP *atomic.Bool` used by the detached path — or, cleaner, have `SessionUpdate` publish through `s.hub` when set and fall back to `s.emit` otherwise. Minimal change to `SessionUpdate`:

```go
func (s *sessionClient) SessionUpdate(_ context.Context, n acpsdk.SessionNotification) error {
	if s.acceptingP != nil { // detached path
		if !s.acceptingP.Load() {
			return nil
		}
		if s.maxEvents > 0 && int(s.events.Add(1)) > s.maxEvents {
			s.hub.Publish(events.NewRunErrorEvent("run too large", events.WithErrorCode("run_too_large")))
			s.cancel()
			return nil
		}
		updates, err := s.bridge.Update(n.Update)
		if err != nil {
			// Soft-miss handling is the bridge's job (RAW to client); a hard
			// error here is logged by the SDK. Publish what we have.
			for _, e := range updates {
				s.hub.Publish(e)
			}
			return nil
		}
		for _, e := range updates {
			s.hub.Publish(e)
		}
		return nil
	}
	// ... legacy path unchanged (existing body) ...
}
```

(Wire `sc.acceptingP = h.accepting` in `runLoop` instead of `accepting: h.accepting`; adjust field names to whatever you choose — keep them consistent.) Provide a temporary `initSession` stub that does the current `RunReserved` init sequence (initialize → new/load → set_mode) returning `sessionID`; Task 11/12 flesh it out with capability advertisement, seeding, and orphan compensation.

Update `Cancel` to prefer the detached run: at the top, `if h := c.runFor(chatID); h != nil { h.cancel(); if h.conn != nil { _ = h.conn.Cancel(ctx, acpsdk.CancelNotification{SessionId: acpsdk.SessionId(h.sessionID)}) }; ... resolve pending ...; return nil }`, else fall through to the existing legacy `activeRun` path.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd services/pocketbase && go test ./internal/agent/coordinator/ -run 'TestStartPromptDetached|TestTeardownIdempotent|TestPanicInProduce' -v && go build ./...`
Expected: PASS + module builds. Also run the whole coordinator package to confirm legacy tests still pass: `go test ./internal/agent/coordinator/ -v`.

- [ ] **Step 5: Commit**

```bash
git add services/pocketbase/internal/agent/coordinator/
git commit -m "feat(agent): detached run lifecycle with idempotent teardown"
```

---

### Task 11: Cancel triggers + orphan-session compensation

**Files:**
- Modify: `internal/agent/coordinator/run.go`, `session.go`
- Test: `internal/agent/coordinator/run_test.go`

**Interfaces:**
- Consumes: `StartPrompt`, `Cancel`, extended `fakeConn`, `clock`, `initSession`.
- Produces: explicit-cancel sends ACP `Cancel`; max-run fires via the fake clock; `session/new` → mapping-persist failure compensates via `conn.UnstableDeleteSession`.

- [ ] **Step 1: Write the failing test**

```go
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/pocketbase && go test ./internal/agent/coordinator/ -run 'TestExplicitCancelSends|TestMaxRunTimeout|TestOrphanSession' -v`
Expected: FAIL — cancel wiring / compensation incomplete.

- [ ] **Step 3: Write minimal implementation**

- `Cancel`: the detached branch added in Task 10 already calls `h.cancel()` + `h.conn.Cancel(...)`; verify it sends `SessionId(h.sessionID)`.
- Max-run: the `maxTimer` from Task 10 calls `h.cancel()`, which unblocks `Prompt` via `runCtx.Done()` → `run_timeout` → teardown. This test exercises it.
- Orphan compensation in `initSession` (`session.go`): on the `session/new` path, after `created(runCtx, sessionID)` returns an error, best-effort `conn.UnstableDeleteSession(runCtx, acpsdk.UnstableDeleteSessionRequest{SessionId: acpsdk.SessionId(sessionID)})` (log on delete failure), then return the persist error.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd services/pocketbase && go test ./internal/agent/coordinator/ -run 'TestExplicitCancelSends|TestMaxRunTimeout|TestOrphanSession' -v && go build ./...`
Expected: PASS + module builds.

- [ ] **Step 5: Commit**

```bash
git add services/pocketbase/internal/agent/coordinator/
git commit -m "feat(agent): cancel triggers and orphan-session compensation"
```

---

## Phase C — capability wiring, transport cutover, integration

### Task 12: Elicitation handler + modes/config seeding + set_mode/set_config dispatch

**Files:**
- Modify: `internal/agent/coordinator/session.go`, `run.go`
- Test: `internal/agent/coordinator/session_test.go`

**Interfaces:**
- `initializeRequest()` advertises `ClientCapabilities{Elicitation: &acpsdk.ElicitationCapabilities{Form: &acpsdk.ElicitationFormCapabilities{}}}`.
- `initSession` seeds: after `new`/`load`, `hub.Publish` each event from `bridge.SeedSession(resp.Modes, resp.ConfigOptions)`.
- `sessionClient.UnstableCreateElicitation(ctx, req) (acpsdk.UnstableCreateElicitationResponse, error)` — mirror `RequestPermission`: emit `bridge.ElicitationPending(id, message, mode, schema)`, block on a `pendingElicitation` channel (SEPARATE map from permissions — spec N5), resolve on `ResolveElicitation` or elicitation-timeout (`c.clock.AfterFunc(c.elicitationTimeout, …)` → cancel).
- `func (c *Coordinator) ResolveElicitation(chatID, id string, resp acpsdk.UnstableCreateElicitationResponse) error`.
- `func (c *Coordinator) SetMode(ctx, chatID, modeID string) error` / `func (c *Coordinator) SetConfigOption(ctx, chatID string, req acpsdk.SetSessionConfigOptionRequest) error` — dispatch to `c.runFor(chatID).conn`; the resulting `CurrentModeUpdate`/`ConfigOptionUpdate` flows back through `bridge.Update` (closed loop, no extra code).

- [ ] **Step 1: Write the failing test**

```go
func TestElicitationResolveResumes(t *testing.T) {
	f := newFakeConn()
	f.emitElicitation = true
	c := testCoordinatorWithConn(t, f, NewFakeClock(time.Unix(0, 0)))
	c.StartPrompt("A", "need input",
		func(context.Context) (string, error) { return "s1", nil },
		func(context.Context, string) error { return nil })
	id := c.waitForPendingElicitation(t, "A")
	if err := c.ResolveElicitation("A", id, acpsdk.UnstableCreateElicitationResponse{
		Accept: &acpsdk.UnstableCreateElicitationAccept{},
	}); err != nil {
		t.Fatal(err)
	}
	c.waitRunDone(t, "A")
	f.mu.Lock()
	resolved := f.elicitationResolved
	f.mu.Unlock()
	if !resolved {
		t.Fatal("elicitation handler must return after ResolveElicitation")
	}
}

func TestElicitationTimeoutResolvesCancel(t *testing.T) {
	f := newFakeConn()
	f.emitElicitation = true
	clk := NewFakeClock(time.Unix(0, 0))
	c := testCoordinatorWithConn(t, f, clk)
	c.StartPrompt("A", "need input",
		func(context.Context) (string, error) { return "s1", nil },
		func(context.Context, string) error { return nil })
	c.waitForPendingElicitation(t, "A")
	clk.Advance(6 * time.Minute)
	c.waitRunDone(t, "A")
}

func TestSetModeDispatchesToConn(t *testing.T) {
	f := newFakeConn()
	f.blockPrompt = make(chan struct{})
	c := testCoordinatorWithConn(t, f, NewFakeClock(time.Unix(0, 0)))
	c.StartPrompt("A", "hi",
		func(context.Context) (string, error) { return "s1", nil },
		func(context.Context, string) error { return nil })
	f.waitForPrompt(t)
	if err := c.SetMode(context.Background(), "A", "plan"); err != nil {
		t.Fatal(err)
	}
	f.mu.Lock()
	got := f.lastMode
	f.mu.Unlock()
	if got != "plan" {
		t.Fatalf("SetMode dispatched %q, want plan", got)
	}
	close(f.blockPrompt)
	c.waitRunDone(t, "A")
}
```

Add helper `waitForPendingElicitation(t, chatID)` (polls the new `pendingElicitation` map for an entry for the chat, returns its id, 2s timeout). Note: the fake's `Prompt` sets `lastMode` only via `SetSessionMode`; `initSession` already calls `SetSessionMode("approve")`, so reset/assert against the explicit `SetMode` call — have the test read `lastMode` AFTER calling `SetMode` (init's "approve" is overwritten by "plan").

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/pocketbase && go test ./internal/agent/coordinator/ -run 'TestElicitation|TestSetModeDispatches' -v`
Expected: FAIL — `undefined: (*Coordinator).ResolveElicitation` / `sessionClient.UnstableCreateElicitation` / `SetMode`.

- [ ] **Step 3: Write minimal implementation**

Add a `pendingElicitation` struct + `c.elicits map[string]*pendingElicitation` (guarded by `c.mu`, separate from `c.pending`), the `UnstableCreateElicitation` handler on `sessionClient` (mirror `RequestPermission`, timeout via `c.clock`), `ResolveElicitation`, `SetMode`/`SetConfigOption` (look up `c.runFor(chatID).conn`; error if no active run), the `bridge.SeedSession` publish in `initSession`, and the `Elicitation` capability in `initializeRequest()`. For `ElicitationPending`, extract `message`/`mode`/`schema` from the `UnstableCreateElicitationRequest.Form` fields (verify field names at impl: `sed -n '6900,6945p' $(go env GOMODCACHE)/github.com/coder/acp-go-sdk@v0.13.5/types_gen.go`).

- [ ] **Step 4: Run test to verify it passes**

Run: `cd services/pocketbase && go test ./internal/agent/coordinator/ -run 'TestElicitation|TestSetModeDispatches' -v && go build ./...`
Expected: PASS + module builds. Full package: `go test ./internal/agent/coordinator/ -v`.

- [ ] **Step 5: Commit**

```bash
git add services/pocketbase/internal/agent/coordinator/
git commit -m "feat(agent): elicitation, modes/config seeding and dispatch"
```

---

### Task 13: SSE frame writer (seq `id:`)

Isolated so the framing has its own RED/GREEN before the route wiring uses it. The AG-UI `sse.SSEWriter` hardcodes `id: <Type>_<timestamp>` (`writer.go:176`), which is NOT our seq — so the stream route writes frames itself.

**Files:**
- Create: `internal/api/sse_frame.go`
- Test: `internal/api/sse_frame_test.go`

**Interfaces:**
- Produces: `func writeSeqFrame(w io.Writer, seq int, ev events.Event) error` — writes `id: <seq>\ndata: <json>\n\n` using `ev.ToJSON()` with newlines escaped (mirrors the SDK's `createSSEFrame` escaping). For snapshot events (which carry no seq of their own), the caller passes the current cursor so the client's `Last-Event-ID` doesn't regress.

- [ ] **Step 1: Write the failing test**

```go
package api

import (
	"strings"
	"testing"

	"github.com/ag-ui-protocol/ag-ui/sdks/community/go/pkg/core/events"
)

func TestWriteSeqFrameEmitsSeqIdAndData(t *testing.T) {
	var b strings.Builder
	ev := events.NewTextMessageContentEvent("m", "hello")
	if err := writeSeqFrame(&b, 7, ev); err != nil {
		t.Fatal(err)
	}
	out := b.String()
	if !strings.Contains(out, "id: 7\n") {
		t.Fatalf("frame missing seq id line: %q", out)
	}
	if !strings.Contains(out, "data: ") || !strings.HasSuffix(out, "\n\n") {
		t.Fatalf("frame malformed: %q", out)
	}
	if strings.Count(out, "\n\ndata") > 0 {
		t.Fatalf("data must be single-line (newlines escaped): %q", out)
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/pocketbase && go test ./internal/api/ -run TestWriteSeqFrame -v`
Expected: FAIL — `undefined: writeSeqFrame`.

- [ ] **Step 3: Write minimal implementation**

```go
package api

import (
	"fmt"
	"io"
	"strings"

	"github.com/ag-ui-protocol/ag-ui/sdks/community/go/pkg/core/events"
)

func writeSeqFrame(w io.Writer, seq int, ev events.Event) error {
	data, err := ev.ToJSON()
	if err != nil {
		return err
	}
	escaped := strings.ReplaceAll(string(data), "\n", "\\n")
	escaped = strings.ReplaceAll(escaped, "\r", "\\r")
	_, err = fmt.Fprintf(w, "id: %d\ndata: %s\n\n", seq, escaped)
	return err
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd services/pocketbase && go test ./internal/api/ -run TestWriteSeqFrame -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add services/pocketbase/internal/api/sse_frame.go services/pocketbase/internal/api/sse_frame_test.go
git commit -m "feat(api): SSE frame writer with seq id"
```

---

### Task 14: Transport cutover — prompt(202)/stream(cursor)/cancel; remove legacy

The single coherent commit that deletes legacy. Before this task, both transports exist and the module builds; after it, only the new transport exists and the module builds. This is where the legacy coordinator methods and their two unit tests are removed.

**Files:**
- Modify: `internal/api/agent.go` (replace `/runs` + `/events` with `/session/prompt` + `/stream`; keep `/cancel`)
- Modify: `internal/agent/coordinator/run.go` (delete `Run`, `Replay`, `RunReserved`, `ReplayReserved`, `RunRequest`, `activeRun`, `startRun`, `finishRun`, `cancelOnClientDisconnect`; simplify `Cancel` to the detached path only; drop the legacy branch of `sessionClient.SessionUpdate`)
- Modify: `internal/agent/coordinator/run_test.go` (delete `TestCancelForwardsToActiveSession` and `TestUnmappedReplayDoesNotDial` — they exercise removed legacy methods; the detached equivalents live in Tasks 10–11)
- Test: `internal/api/agent_test.go`

**Interfaces:**
- `POST /api/pocketcoder/chats/{chatId}/session/prompt` — `{"prompt"}` → `202 {"runId"}`; `409` active; `503` unconfigured.
- `GET /api/pocketcoder/chats/{chatId}/stream?cursor=N` — SSE; no `Reserve`; `att := service.Attach(chatID, cursor)`; flush `att.Snapshot` (each with `id:` = cursor) then `att.Buffered` (each `writeSeqFrame(w, e.Seq, e.Ev)`) then loop `att.Live` until `ctx.Done()` or close; `att.Unsubscribe()` on exit. On `att.ColdReplayNeeded`, first run a Goose bounded replay (reuse the `session/load`→bridge walk, no `Reserve`) writing frames, then Buffered+Live. `cursor` from `?cursor=` or the `Last-Event-ID` header.
- `POST …/session/cancel` unchanged (202).

- [ ] **Step 1: Write the failing test**

```go
func TestPromptReturns202WithRunId(t *testing.T) { /* boot test app + auth, POST session/prompt, assert 202 + JSON {"runId": non-empty}; inject a fake dial via the api test seam */ }
func TestStreamAttachesWithoutReserveAndEmitsSeqIds(t *testing.T) { /* start a run, GET stream?cursor=0, assert id: lines ascend by seq; a second concurrent GET stream also 200s (no 409) */ }
func TestSecondPromptWhileActiveReturns409(t *testing.T) { /* two prompts without finishing; second is 409 */ }
```

(Model on the existing `internal/api/agent_test.go` harness — same app bootstrap, auth token, and the fake-dial injection point. If the API constructs the coordinator internally with no seam, add one: e.g. an exported `RegisterAgentApiWithDial(app, e, dial)` used by tests, with `RegisterAgentApi` delegating with the real dial. Confirm the current test file's setup before writing.)

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/pocketbase && go test ./internal/api/ -run 'TestPromptReturns202|TestStreamAttaches|TestSecondPrompt' -v`
Expected: FAIL — new routes absent.

- [ ] **Step 3: Write minimal implementation**

Replace the `/runs` handler with `session/prompt`:

```go
e.Router.POST("/api/pocketcoder/chats/{chatId}/session/prompt", func(re *core.RequestEvent) error {
	if configErr != nil {
		return apis.NewApiError(http.StatusServiceUnavailable, "Agent service is not configured", nil)
	}
	chatID := re.Request.PathValue("chatId")
	chat, err := app.FindRecordById("chats", chatID)
	if err != nil || chat.GetString("user") != re.Auth.Id {
		return re.NotFoundError("Chat not found", err)
	}
	var input struct{ Prompt string `json:"prompt"` }
	if err := re.BindBody(&input); err != nil {
		return re.BadRequestError("Invalid run request", err)
	}
	if input.Prompt = strings.TrimSpace(input.Prompt); input.Prompt == "" {
		return re.BadRequestError("prompt is required", nil)
	}
	runID, err := service.StartPrompt(chatID, input.Prompt,
		func(context.Context) (string, error) { return gooseSessionForChat(app, chatID, re.Auth.Id) },
		func(ctx context.Context, sid string) error { return saveGooseSession(ctx, app, chatID, re.Auth.Id, sid) })
	if err != nil {
		if errors.Is(err, coordinator.ErrRunInProgress) {
			return apis.NewApiError(http.StatusConflict, "A run is already active for this chat", nil)
		}
		return apis.NewApiError(http.StatusInternalServerError, "Unable to start agent run", err)
	}
	return re.JSON(http.StatusAccepted, map[string]string{"runId": runID})
}).Bind(apis.RequireAuth())
```

Replace `/events` with `/stream`:

```go
e.Router.GET("/api/pocketcoder/chats/{chatId}/stream", func(re *core.RequestEvent) error {
	if configErr != nil {
		return apis.NewApiError(http.StatusServiceUnavailable, "Agent service is not configured", nil)
	}
	chatID := re.Request.PathValue("chatId")
	chat, err := app.FindRecordById("chats", chatID)
	if err != nil || chat.GetString("user") != re.Auth.Id {
		return re.NotFoundError("Chat not found", err)
	}
	cursor := parseCursor(re) // ?cursor= or Last-Event-ID header; default 0
	att := service.Attach(chatID, cursor)
	defer att.Unsubscribe()

	re.Response.Header().Set("Content-Type", "text/event-stream")
	re.Response.Header().Set("Cache-Control", "no-cache")
	re.Response.Header().Set("Connection", "keep-alive")
	re.Response.WriteHeader(http.StatusOK)
	flusher, _ := re.Response.(http.Flusher)

	if att.ColdReplayNeeded {
		// Goose bounded replay into the stream, no Reserve. Reuse the
		// session/load->bridge walk; write each event as a frame with its seq.
		if err := service.StreamColdReplay(re.Request.Context(), chatID, re.Auth.Id, func(seq int, ev events.Event) error {
			return writeFlush(re.Response, flusher, seq, ev)
		}); err != nil {
			_ = writeSeqFrame(re.Response, cursor, events.NewRunErrorEvent("replay failed", events.WithErrorCode("goose_replay_failed")))
		}
	}
	for _, ev := range att.Snapshot {
		_ = writeFlush(re.Response, flusher, cursor, ev)
	}
	for _, e := range att.Buffered {
		_ = writeFlush(re.Response, flusher, e.Seq, e.Ev)
	}
	for {
		select {
		case <-re.Request.Context().Done():
			return nil
		case e, ok := <-att.Live:
			if !ok {
				return nil // dropped or run ended + unsubscribed
			}
			if err := writeFlush(re.Response, flusher, e.Seq, e.Ev); err != nil {
				return nil
			}
		}
	}
}).Bind(apis.RequireAuth())
```

Add `writeFlush` (calls `writeSeqFrame` then `flusher.Flush()`), `parseCursor`, and a thin `Coordinator.StreamColdReplay(ctx, chatID, userID, emit func(seq int, ev events.Event) error) error` that resolves the session and does a no-Reserve `session/load` replay (adapt the legacy `ReplayReserved` body, assigning ascending seqs from 1). Then **delete** the legacy methods/tests listed in Files, and simplify `Cancel` + `SessionUpdate` to the detached-only path. Confirm `go build ./...` is green (this is the commit that closes the api gap).

- [ ] **Step 4: Run test to verify it passes**

Run: `cd services/pocketbase && go build ./... && go test ./internal/api/ ./internal/agent/coordinator/ -v`
Expected: PASS across both packages; module builds with no legacy references.

- [ ] **Step 5: Commit**

```bash
git add services/pocketbase/internal/api/agent.go services/pocketbase/internal/agent/coordinator/
git commit -m "feat(api): cut over to prompt(202)+stream(cursor); remove legacy run path"
```

---

### Task 15: set_mode / set_config / permission / elicitation routes + chats delete hook

**Files:**
- Modify: `internal/api/agent.go`
- Test: `internal/api/agent_test.go`

**Interfaces:**
- `POST …/session/set_mode` — `{"modeId"}` → `service.SetMode`; 202.
- `POST …/session/set_config_option` — binds `acpsdk.SetSessionConfigOptionRequest` (a discriminated union; `SessionId` lives inside each variant — set it from `{chatId}` on whichever variant is non-nil after bind) → `service.SetConfigOption`; 202.
- `POST …/session/request_permission/{id}` — `{"optionId"}` → `service.Approve` (rename of `/approvals/{id}`); 202.
- `POST …/session/elicitation/{id}` — `{"outcome":"accept|decline|cancel"}` (+ optional form content) → map to `acpsdk.UnstableCreateElicitationResponse{Accept|Decline|Cancel}` → `service.ResolveElicitation`; 202.
- `OnRecordAfterDeleteSuccess("chats")` → `go service.DeleteSession(ctx, app, chatID)` (best-effort `UnstableDeleteSession` + remove `goose_sessions` row; on failure log `session_delete_failed` and leave the row for a reconcile sweep; never blocks the delete).

- [ ] **Step 1: Write the failing test**

```go
func TestSetModeRoute202(t *testing.T) { /* active run; POST set_mode {"modeId":"plan"} -> 202; fake conn saw "plan" */ }
func TestElicitationRoute202(t *testing.T) { /* pending elicitation; POST elicitation/{id} {"outcome":"accept"} -> 202; handler resumes */ }
func TestChatDeleteTriggersSessionDelete(t *testing.T) { /* chat + goose_sessions row; delete chat; fake conn saw UnstableDeleteSession; row gone */ }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/pocketbase && go test ./internal/api/ -run 'TestSetModeRoute|TestElicitationRoute|TestChatDeleteTriggers' -v`
Expected: FAIL — routes/hook absent.

- [ ] **Step 3: Write minimal implementation**

Add the four routes (mirror the existing approvals handler for ownership + error mapping). Register the delete hook in `RegisterAgentApi`:

```go
app.OnRecordAfterDeleteSuccess("chats").BindFunc(func(e *core.RecordEvent) error {
	chatID := e.Record.Id
	go func() {
		if err := service.DeleteSession(context.Background(), app, chatID); err != nil {
			app.Logger().Error("goose session delete failed; left for reconcile", "chat_id", chatID, "error", err)
		}
	}()
	return e.Next()
})
```

`Coordinator.DeleteSession(ctx, app core.App, chatID string) error`: resolve the mapping (any user — it's a system cleanup), dial a short-lived conn, `UnstableDeleteSession`, then delete the `goose_sessions` row on success. On failure, return the error (the hook logs it; the row remains for a future reconcile pass — documented v1 floor).

- [ ] **Step 4: Run test to verify it passes**

Run: `cd services/pocketbase && go build ./... && go test ./internal/api/ -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add services/pocketbase/internal/api/agent.go services/pocketbase/internal/api/agent_test.go services/pocketbase/internal/agent/coordinator/
git commit -m "feat(api): set_mode/set_config/permission/elicitation routes + chat-delete hook"
```

---

### Task 16: Live-Goose integration (replace legacy live test)

**Files:**
- Modify (replace contents of): `internal/agent/coordinator/live_test.go` (still `//go:build live_acp`, same package) — it currently calls the removed `c.Run`/`RunRequest`; rewrite it to the `StartPrompt`+`Attach` stream path.
- Modify: `tests/agent-c1/*` — update to POST `session/prompt` and GET `session/stream?cursor=`.

**Interfaces:**
- Consumes the full stack against a real Goose container.

- [ ] **Step 1: Rewrite the live test (RED against a live env)**

Replace `live_test.go`'s `TestLiveRunNewSession`/`TestLiveWrongSecretRejected` bodies to: `StartPrompt` a turn, `Attach(chatID, 0)`, drain `Snapshot`+`Buffered`+`Live` collecting `EventType`s, assert `RUN_STARTED … RUN_FINISHED` with a real tool/diff turn through the translation unit; reconnect mid-turn with the last seq and assert no gap; wrong secret → dial fails and the run publishes `RUN_ERROR`. Keep the `t.Skip` when `GOOSE_ACP_URL`/secret are unset.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/pocketbase && go test -tags live_acp ./internal/agent/coordinator/ -run TestLive -v`
Expected: FAIL or SKIP (SKIP when Goose env absent). With env set, FAIL until the stack is up.

- [ ] **Step 3: Bring the stack up**

No schema change → skip the `CLAUDE.md` model-generation pipeline. Rebuild + start c1/c2: `docker compose build pocketbase opencode && docker compose up -d pocketbase opencode`. Update `tests/agent-c1` scripts to the new endpoints.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd services/pocketbase && GOOSE_ACP_URL=... GOOSE_SERVER__SECRET_KEY=... go test -tags live_acp ./internal/agent/coordinator/ -run TestLive -v`
Expected: PASS against live Goose.

- [ ] **Step 5: Commit**

```bash
git add services/pocketbase/internal/agent/coordinator/live_test.go tests/agent-c1
git commit -m "test(agent): live_acp integration for the detached stream bridge"
```

---

## Self-Review

**Spec coverage** (§ → task):
- §4 hub (seq, atomic attach, drop-slow, snapshot, linger/evict, teardown) → Tasks 2–6. ✓
- §4a build-in-house → Tasks 1–6 add no dependency (stdlib only). ✓
- §5 detached lifecycle (bg/dial ctx, 202 runId, idempotent `sync.Once` teardown, cancel triggers, Reserve-last, panic-recover) → Tasks 10, 11. ✓
- §6 Goose conn (dial-per-run owned by run, `Elicitation` capability, init sequence, orphan compensation) → Tasks 10, 11, 12. ✓
- §7 endpoint table → Tasks 14, 15. ✓
- §8 elicitation + set_mode/set_config → Tasks 12, 15. ✓
- §9 session lifecycle (new/load kept, delete hook + reconcile floor; close/fork deferred) → Tasks 11, 15. ✓
- §10 error taxonomy (`goose_unavailable`/`run_timeout`/`run_too_large`/`protocol_error`/`goose_replay_failed`/`session_delete_failed`) → Tasks 10, 11, 14, 15. ✓
- §11 decisions (chat-global seq, subscriber-owned backlog, merged Snapshot, sync.Once) → Tasks 2, 3, 8, 10. ✓
- §12 testing (deterministic hub, lifecycle, method, live_acp) → all tasks + Task 16. ✓
- §13 module structure → matches File Structure. ✓

**Green-build guarantee:** every task ends with `go build ./...` green. The legacy transport is kept intact through Phase B and removed in one coherent commit (Task 14) that simultaneously lands the replacement routes and fixes the two dependent unit tests; the `live_acp`-tagged `live_test.go` (excluded from default builds) is rewritten in Task 16.

**No orphaned references:** `Finished(stopReason)` (Task 8) updates all call sites in its own commit. `Conn` additions (Task 7) precede the code (Tasks 11/12) that calls them and are mirrored on `fakeConn`. `Attach`/`Attachment` (Task 3) → `Coordinator.Attach` (Task 9) → stream route (Task 14). `writeSeqFrame` (Task 13) → stream route (Task 14). Legacy `Run`/`Replay`/`RunReserved`/`ReplayReserved`/`activeRun`/`startRun`/`finishRun`/`cancelOnClientDisconnect` and `TestCancelForwardsToActiveSession`/`TestUnmappedReplayDoesNotDial` are all removed together in Task 14; `live_test.go`'s use of `Run`/`RunRequest` is fixed in Task 16.

**Verify-at-impl-time (intentional, TDD RED catches mismatches):** translation-unit internal field names (`threadID`/`runID`/`openTools`/`closeMessage`/`closeReasoning`) and AG-UI accessors (`RunFinishedEvent.Result`); the `UnstableCreateElicitationForm` field names for message/mode/schema extraction; the existing `internal/api/agent_test.go` bootstrap + dial-injection seam. Pinned against `acp-go-sdk@v0.13.5` / AG-UI SDK by this plan: `NewRunFinishedEventWithOptions`+`WithResult`/`WithSuccessOutcome` (NOT `NewRunFinishedEvent`, which takes no options), `NewRunErrorEvent`+`WithErrorCode`, `NewToolCallEndEvent`, `NewTextMessageContentEvent`, `NewStateSnapshotEvent`, `event.ToJSON()`, the SSE writer's hardcoded `id: <Type>_<ts>` (why Task 13 hand-writes frames), `PromptResponse.StopReason`, `StopReason*`, `ClientCapabilities.Elicitation`/`ElicitationCapabilities.Form`, `SetSessionConfigOptionRequest` (union; `SessionId` inside each variant), `UnstableDeleteSessionRequest`, `UnstableCreateElicitation{Request,Response,Accept,Decline,Cancel}`, `NewSessionResponse.{Modes,ConfigOptions}`, `ClientSideConnection.{SetSessionConfigOption,UnstableDeleteSession}` (so `sdkConn` satisfies the extended `Conn` by embedding), and the `UnstableCreateElicitation` dispatch-by-type-assertion (`client_gen.go:37`) — so the handler method on `sessionClient` is routed correctly.

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-07-19-robust-c1-c2-bridge.md`.** Phase A (Tasks 1–6) is a self-contained, deterministic, Goose-free unit — a clean first checkpoint. Phase B (7–12) and Phase C (13–16) build on it and consume the merged translation unit; every task keeps `go build ./...` green.
