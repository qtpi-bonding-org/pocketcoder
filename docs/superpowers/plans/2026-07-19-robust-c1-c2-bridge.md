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

Phase B consumes Phase A's hub and the translation `Bridge`. It requires the translation plan merged. Uses a fake `acp.Conn` (no real Goose) for unit tests; live Goose is Phase C's integration tag.

### Task 7: `Bridge.Finished(stopReason)`

**Files:**
- Modify: `internal/agent/agui/bridge.go`
- Test: `internal/agent/agui/bridge_test.go`

**Interfaces:**
- Consumes: existing `Bridge` (translation unit).
- Produces: `func (b *Bridge) Finished(stopReason acpsdk.StopReason) []events.Event` — maps `StopReasonEndTurn` → success `RUN_FINISHED`; every other stop (`cancelled`/`refusal`/`max_tokens`/`max_turn_requests`) → non-success outcome on the `RUN_FINISHED` event. (This is the only translation-unit change this plan owns; update the sibling's call sites in `run.go` in Task 9.)

- [ ] **Step 1: Write the failing test**

```go
package agui

import (
	"testing"

	acpsdk "github.com/coder/acp-go-sdk"
)

func TestFinishedSuccessOnEndTurn(t *testing.T) {
	b := NewBridge("chat", "run")
	evs := b.Finished(acpsdk.StopReasonEndTurn)
	if len(evs) == 0 || evs[len(evs)-1].Type() != events.EventTypeRunFinished {
		t.Fatalf("expected trailing RUN_FINISHED, got %v", evs)
	}
	// Inspect the finished event's outcome/result field for success — verify the
	// exact accessor against the AG-UI SDK at impl time (RunFinishedEvent.Result).
}

func TestFinishedNonSuccessOnRefusal(t *testing.T) {
	b := NewBridge("chat", "run")
	evs := b.Finished(acpsdk.StopReasonRefusal)
	if len(evs) == 0 {
		t.Fatal("expected a RUN_FINISHED event on refusal")
	}
	// Assert the outcome is NOT the success outcome (distinct Result payload).
}
```

(At impl time, confirm the AG-UI `RunFinishedEvent` shape: `grep -n "RunFinishedEvent\|WithSuccessOutcome\|func NewRunFinishedEvent" $(go env GOMODCACHE)/github.com/ag-ui-protocol/ag-ui*/.../pkg/core/events/*.go`. Match the existing `bridge.go:135` construction and add a result/outcome distinguishing success from non-success — a `RAW`-free `RUN_FINISHED` with a `stopReason` field in its payload is acceptable if the SDK lacks a typed outcome.)

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/pocketbase && go test ./internal/agent/agui/ -run TestFinished -v`
Expected: FAIL — `too many arguments in call to b.Finished` / signature mismatch.

- [ ] **Step 3: Write minimal implementation**

Update `Finished` in `bridge.go` (starting at `bridge.go:135`):

```go
func (b *Bridge) Finished(stopReason acpsdk.StopReason) []events.Event {
	out := b.closeMessage()
	out = append(out, b.closeReasoning()...)
	for id := range b.openTools { // close any open tool calls (existing behavior)
		out = append(out, events.NewToolCallEndEvent(id))
	}
	fin := events.NewRunFinishedEvent(b.threadID, b.runID)
	if stopReason != acpsdk.StopReasonEndTurn {
		// Non-success: surface the stop reason so the client can distinguish
		// refusal/cancel/limit from a clean end_turn.
		fin = events.NewRunFinishedEvent(b.threadID, b.runID,
			events.WithResult(map[string]any{"stopReason": string(stopReason)}))
	}
	return append(out, fin)
}
```

(Field/option names — `threadID`/`runID`/`openTools`/`WithResult`/`NewRunFinishedEvent` — must match the translation unit's actual `bridge.go` and the AG-UI SDK. Verify each at impl time; the translation plan defines `openTools map[string]toolMeta` and the `threadID`/`runID` fields.)

- [ ] **Step 4: Run test to verify it passes**

Run: `cd services/pocketbase && go test ./internal/agent/agui/ -run TestFinished -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add services/pocketbase/internal/agent/agui/bridge.go services/pocketbase/internal/agent/agui/bridge_test.go
git commit -m "feat(agui): Finished maps stopReason to run outcome"
```

---

### Task 8: Split coordinator state; hub registry

**Files:**
- Create: `internal/agent/coordinator/coordinator.go` (move the `Coordinator` struct, `New`, `Reserve`, `release`, `Cancel`, `Approve`, `Shutdown` out of `run.go`)
- Modify: `internal/agent/coordinator/run.go` (leave run-specific code)
- Test: `internal/agent/coordinator/coordinator_test.go`

**Interfaces:**
- Produces on `Coordinator`:
  - a `hubs map[string]*ChatHub` guarded by `mu`, `clock Clock`, and the new config durations.
  - `func (c *Coordinator) hubFor(chatID string) *ChatHub` — returns the existing hub or creates one (`NewChatHub(c.clock, c.lingerWindow, c.liveBuf)`).
  - `func (c *Coordinator) reapHub(chatID string)` — removes the hub if `IsEmpty()`.
  - `Config` gains `Clock Clock`, `LingerWindow, MaxRun, ElicitationTimeout time.Duration`, `MaxRunEvents, LiveBuffer int` (defaults applied in `New`).

- [ ] **Step 1: Write the failing test**

```go
func TestHubForReturnsSameHubPerChat(t *testing.T) {
	c := testCoordinator(t)
	h1 := c.hubFor("chat-A")
	h2 := c.hubFor("chat-A")
	if h1 != h2 {
		t.Fatal("hubFor must return the same hub for the same chat")
	}
	if c.hubFor("chat-B") == h1 {
		t.Fatal("different chats must get different hubs")
	}
}

func TestReapHubRemovesEmptyHub(t *testing.T) {
	c := testCoordinator(t)
	h := c.hubFor("chat-A")
	if !h.IsEmpty() {
		t.Fatal("fresh hub should be empty")
	}
	c.reapHub("chat-A")
	if c.hubFor("chat-A") == h {
		t.Fatal("reaped hub should have been removed (new instance expected)")
	}
}
```

Add a helper in the test file:

```go
func testCoordinator(t *testing.T) *Coordinator {
	t.Helper()
	c, err := New(Config{
		GooseURL: "ws://x", GooseSecret: "s", Workspace: "/w",
		Clock: NewFakeClock(time.Unix(0, 0)),
		Dial:  func(context.Context, acpsdk.Client) (acp.Conn, error) { return nil, nil },
	})
	if err != nil {
		t.Fatal(err)
	}
	return c
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/pocketbase && go test ./internal/agent/coordinator/ -run 'TestHubFor|TestReapHub' -v`
Expected: FAIL — `undefined: (*Coordinator).hubFor` / `Config` has no `Clock`.

- [ ] **Step 3: Write minimal implementation**

In `coordinator.go`, extend `Config` and `New` (fold in defaults), and add:

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
```

`New` defaults: if `config.Clock == nil { config.Clock = RealClock() }`; `LingerWindow` default 30s; `MaxRun` 15m; `ElicitationTimeout` = `PermissionTimeout` if unset; `MaxRunEvents` 50000; `LiveBuffer` 256. Initialize `hubs: map[string]*ChatHub{}` and store `clock/lingerWindow/liveBuf/...` on the struct.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd services/pocketbase && go test ./internal/agent/coordinator/ -run 'TestHubFor|TestReapHub' -v`
Expected: PASS. Also run the full package to confirm the split didn't break existing tests: `go test ./internal/agent/coordinator/ -v`.

- [ ] **Step 5: Commit**

```bash
git add services/pocketbase/internal/agent/coordinator/coordinator.go services/pocketbase/internal/agent/coordinator/run.go services/pocketbase/internal/agent/coordinator/coordinator_test.go
git commit -m "refactor(agent): split coordinator state, add hub registry"
```

---

### Task 9: Detached run — background/dial ctx, publish-to-hub, idempotent teardown, panic-recover

**Files:**
- Modify: `internal/agent/coordinator/run.go`
- Test: `internal/agent/coordinator/run_test.go`

**Interfaces:**
- Produces:
  - `func (c *Coordinator) StartPrompt(chatID, prompt string, resolve ResolveSession, created OnSessionCreated) (runID string, err error)` — reserves, spawns the detached run on a `context.Background()`-derived ctx (also the Goose dial ctx), returns `202`-able `runId` immediately; does not stream.
  - internal `func (c *Coordinator) runLoop(runCtx context.Context, cancel context.CancelFunc, chatID, runID, prompt string, hub *ChatHub, resolve ResolveSession, created OnSessionCreated)` — the goroutine body, with `sync.Once` teardown and `recover()`.
- Consumes: `hubFor`, `Bridge`, `acp.Conn` (via `config.Dial`).
- **Removed:** `cancelOnClientDisconnect` (the disconnect-cancels bug), `RunReserved`/`ReplayReserved` request-ctx emit path.

- [ ] **Step 1: Write the failing test**

```go
func TestStartPromptReturnsRunIdAndDoesNotCancelOnCallerCtx(t *testing.T) {
	fake := newFakeConn() // see helper below
	c := testCoordinatorWithDial(t, fake)
	runID, err := c.StartPrompt("chat-A", "hello",
		func(context.Context) (string, error) { return "sess-1", nil },
		func(context.Context, string) error { return nil })
	if err != nil {
		t.Fatal(err)
	}
	if runID == "" {
		t.Fatal("StartPrompt must return a runId")
	}
	// The run is detached: it proceeds to Prompt even though StartPrompt's
	// caller has already returned. Wait for the fake to observe a Prompt call.
	fake.waitForPrompt(t)
	if fake.cancelled {
		t.Fatal("run must not be cancelled by the caller returning")
	}
}

func TestTeardownIdempotentOnConcurrentFinishAndCancel(t *testing.T) {
	fake := newFakeConn()
	c := testCoordinatorWithDial(t, fake)
	fake.blockPrompt = make(chan struct{}) // hold the turn open
	runID, _ := c.StartPrompt("chat-A", "hi",
		func(context.Context) (string, error) { return "sess-1", nil },
		func(context.Context, string) error { return nil })
	_ = runID
	fake.waitForPrompt(t)
	// Fire cancel and finish concurrently.
	go c.Cancel(context.Background(), "chat-A")
	close(fake.blockPrompt) // let the turn finish
	c.waitRunDone(t, "chat-A")
	if fake.closeCount != 1 {
		t.Fatalf("conn.Close called %d times, want exactly 1 (sync.Once teardown)", fake.closeCount)
	}
	if c.isReserved("chat-A") {
		t.Fatal("Reserve must be released exactly once after teardown")
	}
}

func TestPanicInProduceReleasesReserve(t *testing.T) {
	fake := newFakeConn()
	fake.panicOnPrompt = true
	c := testCoordinatorWithDial(t, fake)
	c.StartPrompt("chat-A", "boom",
		func(context.Context) (string, error) { return "sess-1", nil },
		func(context.Context, string) error { return nil })
	c.waitRunDone(t, "chat-A")
	if c.isReserved("chat-A") {
		t.Fatal("panic in produce must still release Reserve")
	}
}
```

Add fake/helpers in `run_test.go`: a `fakeConn` implementing `acp.Conn` (Initialize/NewSession/LoadSession/SetSessionMode/Prompt/Cancel/Close, plus the Task 11 additions once they exist) with `cancelled bool`, `closeCount int`, `blockPrompt chan struct{}`, `panicOnPrompt bool`, `waitForPrompt`, and Prompt returning `acpsdk.PromptResponse{StopReason: acpsdk.StopReasonEndTurn}`. Add `Coordinator` test-only helpers `isReserved(chatID)`, `waitRunDone(chatID)` (poll a per-run done channel).

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/pocketbase && go test ./internal/agent/coordinator/ -run 'TestStartPrompt|TestTeardownIdempotent|TestPanicInProduce' -v`
Expected: FAIL — `undefined: (*Coordinator).StartPrompt`.

- [ ] **Step 3: Write minimal implementation**

Rework `run.go`. Core shape (fill against the current `RunReserved` body, keeping the ACP init sequence):

```go
func (c *Coordinator) StartPrompt(chatID, prompt string, resolve ResolveSession, created OnSessionCreated) (string, error) {
	if err := c.Reserve(chatID); err != nil {
		return "", err
	}
	runID := uuid.NewString()
	runCtx, cancel := context.WithCancel(context.Background())
	hub := c.hubFor(chatID)
	c.registerRunCancel(chatID, runID, cancel) // stored so Cancel/Shutdown/timeout can trigger
	go c.runLoop(runCtx, cancel, chatID, runID, prompt, hub, resolve, created)
	return runID, nil
}

func (c *Coordinator) runLoop(runCtx context.Context, cancel context.CancelFunc, chatID, runID, prompt string, hub *ChatHub, resolve ResolveSession, created OnSessionCreated) {
	var conn acp.Conn
	var once sync.Once
	teardown := func(release bool) {
		once.Do(func() {
			c.markNotAccepting(chatID, runID) // flip accepting=false, detach hub active-run pointer publish path
			c.stopRunTimers(chatID, runID)    // permission/elicitation/max-run timers
			if conn != nil {
				_ = conn.Close()
			}
			c.dropPendingForChat(chatID)
			hub.FinishRun()
			cancel()
			c.clearRunCancel(chatID, runID)
			if release {
				c.release(chatID) // LAST
			}
			c.reapHub(chatID)
			c.signalRunDone(chatID) // test hook
		})
	}
	defer teardown(true)
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
		emit: func(e events.Event) error { hub.Publish(e); return nil }}
	conn, err = c.config.Dial(runCtx, sc) // runCtx is ALSO the dial ctx (N1)
	if err != nil {
		hub.Publish(events.NewRunErrorEvent("goose dial", events.WithErrorCode("goose_unavailable")))
		return
	}
	// ... initialize (with Elicitation capability, Task 12), new/load + orphan
	//     compensation (Task 10), seed modes/config into bridge (Task 12),
	//     set_mode, publish bridge.Started(), accepting=true ...
	maxRunTimer := c.clock.AfterFunc(c.maxRun, func() { cancel() })
	c.trackRunTimer(chatID, runID, maxRunTimer)

	resp, err := conn.Prompt(runCtx, acpsdk.PromptRequest{
		SessionId: acpsdk.SessionId(sessionID),
		Prompt:    []acpsdk.ContentBlock{{Text: &acpsdk.ContentBlockText{Type: "text", Text: prompt}}},
	})
	if err != nil {
		if runCtx.Err() != nil {
			hub.Publish(events.NewRunErrorEvent("run cancelled", events.WithErrorCode("run_timeout")))
		} else {
			hub.Publish(events.NewRunErrorEvent("goose turn failed", events.WithErrorCode("goose_unavailable")))
		}
		return
	}
	for _, e := range bridge.Finished(resp.StopReason) {
		hub.Publish(e)
	}
}
```

Add the supporting run-registry helpers (`registerRunCancel`/`clearRunCancel`/`markNotAccepting`/`stopRunTimers`/`trackRunTimer`/`signalRunDone`/`isReserved`/`waitRunDone`) and per-run cap enforcement inside `sessionClient.SessionUpdate` (increment a counter; on exceeding `c.maxRunEvents` publish `RUN_ERROR(run_too_large)` and `cancel()`). Rewire `Cancel`/`Shutdown` to call the stored `cancel()` for the chat's run instead of touching the removed `activeRun` map. Delete `cancelOnClientDisconnect`, `RunReserved`, `startRun`/`finishRun`/`activeRun`.

**Straggler safety:** `sessionClient.SessionUpdate` must check `accepting` (already does) — `markNotAccepting` flips it under the coordinator lock before `hub.FinishRun()`, so a late `SessionUpdate` returns early and never publishes into a subsequent run.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd services/pocketbase && go test ./internal/agent/coordinator/ -run 'TestStartPrompt|TestTeardownIdempotent|TestPanicInProduce' -v`
Expected: PASS. Then full package: `go test ./internal/agent/coordinator/ -v`.

- [ ] **Step 5: Commit**

```bash
git add services/pocketbase/internal/agent/coordinator/run.go services/pocketbase/internal/agent/coordinator/run_test.go services/pocketbase/internal/agent/coordinator/coordinator.go
git commit -m "feat(agent): detached run lifecycle with idempotent teardown"
```

---

### Task 10: Cancel triggers + orphan-session compensation

**Files:**
- Modify: `internal/agent/coordinator/run.go`, `session.go`
- Test: `internal/agent/coordinator/run_test.go`

**Interfaces:**
- Consumes: `StartPrompt`, `Cancel`, fake `acp.Conn`, `clock`.
- Produces: explicit-cancel and max-run paths verified; `session/new` persist-failure → `UnstableDeleteSession` compensation (needs the Conn extension from Task 11 — if executing Task 10 before Task 11, stub `UnstableDeleteSession` on the fake and add it to the interface first).

- [ ] **Step 1: Write the failing test**

```go
func TestExplicitCancelStopsRun(t *testing.T) {
	fake := newFakeConn()
	fake.blockPrompt = make(chan struct{})
	c := testCoordinatorWithDial(t, fake)
	c.StartPrompt("chat-A", "hi",
		func(context.Context) (string, error) { return "sess-1", nil },
		func(context.Context, string) error { return nil })
	fake.waitForPrompt(t)
	if err := c.Cancel(context.Background(), "chat-A"); err != nil {
		t.Fatal(err)
	}
	c.waitRunDone(t, "chat-A")
	if !fake.cancelled {
		t.Fatal("explicit cancel must send ACP Cancel")
	}
}

func TestMaxRunTimeoutFires(t *testing.T) {
	fake := newFakeConn()
	fake.blockPrompt = make(chan struct{}) // never unblocked
	clk := NewFakeClock(time.Unix(0, 0))
	c := testCoordinatorWithDialAndClock(t, fake, clk, 15*time.Minute)
	c.StartPrompt("chat-A", "hi",
		func(context.Context) (string, error) { return "sess-1", nil },
		func(context.Context, string) error { return nil })
	fake.waitForPrompt(t)
	clk.Advance(15*time.Minute + time.Second)
	c.waitRunDone(t, "chat-A")
	if c.isReserved("chat-A") {
		t.Fatal("max-run timeout must tear down and release")
	}
}

func TestOrphanSessionCompensatedOnPersistFailure(t *testing.T) {
	fake := newFakeConn()
	fake.newSessionID = "orphan-1"
	c := testCoordinatorWithDial(t, fake)
	c.StartPrompt("chat-A", "hi",
		func(context.Context) (string, error) { return "", nil }, // unmapped => session/new
		func(context.Context, string) error { return errors.New("db down") })
	c.waitRunDone(t, "chat-A")
	if fake.deletedSession != "orphan-1" {
		t.Fatalf("persist failure must compensate via session/delete, deleted=%q", fake.deletedSession)
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/pocketbase && go test ./internal/agent/coordinator/ -run 'TestExplicitCancel|TestMaxRunTimeout|TestOrphanSession' -v`
Expected: FAIL — cancel wiring / compensation not implemented.

- [ ] **Step 3: Write minimal implementation**

- `Cancel(ctx, chatID)`: look up the stored run `cancel()` and invoke it (plus resolve any pending permission as today). It no longer needs `activeRun`; it needs the `sessionID` to send ACP `Cancel` — store `sessionID` in the run-cancel registry entry.
- Max-run: already wired in Task 9 (`maxRunTimer` → `cancel()`); this test just exercises it via the fake clock.
- Orphan compensation in `session.go`'s new/load helper: after `conn.NewSession`, if `created(runCtx, sessionID)` returns an error, call `conn.UnstableDeleteSession(runCtx, acpsdk.UnstableDeleteSessionRequest{SessionId: result.SessionId})` (best-effort, log on failure) before returning the error.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd services/pocketbase && go test ./internal/agent/coordinator/ -run 'TestExplicitCancel|TestMaxRunTimeout|TestOrphanSession' -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add services/pocketbase/internal/agent/coordinator/run.go services/pocketbase/internal/agent/coordinator/session.go services/pocketbase/internal/agent/coordinator/run_test.go
git commit -m "feat(agent): cancel triggers and orphan-session compensation"
```

---

## Phase C — Endpoint + session-lifecycle wiring

### Task 11: Extend `acp.Conn` (config-option, delete)

**Files:**
- Modify: `internal/agent/acp/websocket.go`
- Test: `internal/agent/acp/conn_test.go`

**Interfaces:**
- Produces on `Conn`: `SetSessionConfigOption(context.Context, acpsdk.SetSessionConfigOptionRequest) (acpsdk.SetSessionConfigOptionResponse, error)` and `UnstableDeleteSession(context.Context, acpsdk.UnstableDeleteSessionRequest) (acpsdk.UnstableDeleteSessionResponse, error)`. Both delegate to the embedded `*acpsdk.ClientSideConnection` (methods exist: `client_gen.go:304`, `:271`), so `sdkConn` satisfies them by embedding — the only change is adding them to the `Conn` interface.

- [ ] **Step 1: Write the failing test**

```go
package acp

import "testing"

func TestConnInterfaceIncludesConfigAndDelete(t *testing.T) {
	// Compile-time assertion: *sdkConn satisfies the extended Conn interface.
	var _ Conn = (*sdkConn)(nil)
	// And the interface names the new methods (guards accidental removal).
	var c Conn
	_ = c // presence checked by the method set below via interface embedding
}
```

Because the real proof is compilation, add a build-time assertion in `websocket.go` itself: `var _ Conn = (*sdkConn)(nil)`. The failing state is the interface lacking the methods while a caller (Task 10/12) references them.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/pocketbase && go build ./internal/agent/acp/ && go test ./internal/agent/acp/ -run TestConnInterface -v`
Expected: Before adding methods, a caller referencing `conn.UnstableDeleteSession` fails to compile. Add the interface methods to make the package build.

- [ ] **Step 3: Write minimal implementation**

In `websocket.go`, extend the `Conn` interface:

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

No method bodies needed — `sdkConn` embeds `*acpsdk.ClientSideConnection`, which already implements both.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd services/pocketbase && go test ./internal/agent/acp/ -v`
Expected: PASS (compiles + assertion holds).

- [ ] **Step 5: Commit**

```bash
git add services/pocketbase/internal/agent/acp/websocket.go services/pocketbase/internal/agent/acp/conn_test.go
git commit -m "feat(agent): extend acp.Conn with config-option and delete"
```

---

### Task 12: Elicitation capability + handler; modes/config seeding; set_mode/set_config dispatch

**Files:**
- Modify: `internal/agent/coordinator/session.go`, `run.go`, `coordinator.go`
- Test: `internal/agent/coordinator/session_test.go`

**Interfaces:**
- Produces:
  - `initializeRequest()` advertises `ClientCapabilities{Elicitation: &acpsdk.ElicitationCapabilities{Form: &acpsdk.ElicitationFormCapabilities{}}}`.
  - `sessionClient.UnstableCreateElicitation(ctx, req) (acpsdk.UnstableCreateElicitationResponse, error)` — mirrors `RequestPermission`: emit `bridge.ElicitationPending(...)`, block on a `pendingElicitation` channel (separate keyspace from permissions), resolve on `POST …/elicitation/{id}` or an elicitation-timeout (`c.clock.AfterFunc`, resolve cancel).
  - `func (c *Coordinator) ResolveElicitation(chatID, id string, resp acpsdk.UnstableCreateElicitationResponse) error`.
  - `func (c *Coordinator) SetMode(ctx, chatID, modeID string) error` and `func (c *Coordinator) SetConfigOption(ctx, chatID string, req acpsdk.SetSessionConfigOptionRequest) error` — dispatch to the active run's conn; the resulting `CurrentModeUpdate`/`ConfigOptionUpdate` flow back through the bridge (closed loop, no extra code).
  - Seeding: after `new`/`load`, call `bridge.SeedSession(resp.Modes, resp.ConfigOptions)` and publish the returned events.

- [ ] **Step 1: Write the failing test**

```go
func TestElicitationRequestResponseResumes(t *testing.T) {
	fake := newFakeConn()
	fake.emitElicitation = true // fake calls sc.UnstableCreateElicitation during Prompt
	c := testCoordinatorWithDial(t, fake)
	c.StartPrompt("chat-A", "need input",
		func(context.Context) (string, error) { return "sess-1", nil },
		func(context.Context, string) error { return nil })
	id := c.waitForPendingElicitation(t, "chat-A")
	err := c.ResolveElicitation("chat-A", id, acpsdk.UnstableCreateElicitationResponse{
		Accept: &acpsdk.UnstableCreateElicitationAccept{},
	})
	if err != nil {
		t.Fatal(err)
	}
	c.waitRunDone(t, "chat-A")
	if !fake.elicitationResolved {
		t.Fatal("elicitation handler must return after ResolveElicitation")
	}
}

func TestElicitationTimeoutResolvesCancel(t *testing.T) {
	fake := newFakeConn()
	fake.emitElicitation = true
	clk := NewFakeClock(time.Unix(0, 0))
	c := testCoordinatorWithDialAndClock(t, fake, clk, 15*time.Minute)
	c.StartPrompt("chat-A", "need input",
		func(context.Context) (string, error) { return "sess-1", nil },
		func(context.Context, string) error { return nil })
	c.waitForPendingElicitation(t, "chat-A")
	clk.Advance(6 * time.Minute) // past the 5m elicitation timeout
	c.waitRunDone(t, "chat-A")
	if !fake.elicitationResolved {
		t.Fatal("elicitation timeout must unblock the handler (cancel)")
	}
}

func TestSetModeDispatchesToConn(t *testing.T) {
	fake := newFakeConn()
	fake.blockPrompt = make(chan struct{})
	c := testCoordinatorWithDial(t, fake)
	c.StartPrompt("chat-A", "hi",
		func(context.Context) (string, error) { return "sess-1", nil },
		func(context.Context, string) error { return nil })
	fake.waitForPrompt(t)
	if err := c.SetMode(context.Background(), "chat-A", "plan"); err != nil {
		t.Fatal(err)
	}
	if fake.lastMode != "plan" {
		t.Fatalf("SetMode dispatched %q, want plan", fake.lastMode)
	}
	close(fake.blockPrompt)
	c.waitRunDone(t, "chat-A")
}
```

Extend `fakeConn` with `emitElicitation`, `elicitationResolved`, `lastMode`, and (from Task 10) `newSessionID`/`deletedSession`. Add coordinator test helper `waitForPendingElicitation`.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/pocketbase && go test ./internal/agent/coordinator/ -run 'TestElicitation|TestSetMode' -v`
Expected: FAIL — `undefined: (*Coordinator).ResolveElicitation` / `sessionClient.UnstableCreateElicitation`.

- [ ] **Step 3: Write minimal implementation**

Add a `pendingElicitation` struct + map on `Coordinator` (separate from `pending` permissions — N5), the `UnstableCreateElicitation` handler on `sessionClient` (mirror `RequestPermission`, timeout via `c.clock`), `ResolveElicitation`, `SetMode`/`SetConfigOption` (look up the run's conn from the run-cancel registry — store the conn there, or add a `runConn map[string]acp.Conn`), and the `SeedSession` seeding call in the new/load path. Update `initializeRequest()` to advertise `Elicitation`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd services/pocketbase && go test ./internal/agent/coordinator/ -run 'TestElicitation|TestSetMode' -v`
Expected: PASS. Full package: `go test ./internal/agent/coordinator/ -v`.

- [ ] **Step 5: Commit**

```bash
git add services/pocketbase/internal/agent/coordinator/session.go services/pocketbase/internal/agent/coordinator/run.go services/pocketbase/internal/agent/coordinator/coordinator.go services/pocketbase/internal/agent/coordinator/session_test.go
git commit -m "feat(agent): elicitation, modes/config seeding and dispatch"
```

---

### Task 13: Rewire routes — prompt(202) + stream(cursor, SSE id:)

**Files:**
- Modify: `internal/api/agent.go`
- Test: `internal/api/agent_test.go` (extend existing)

**Interfaces:**
- Produces routes (all `RequireAuth`, ownership-checked):
  - `POST /api/pocketcoder/chats/{chatId}/session/prompt` — body `{"prompt": string}`; `202 {"runId": string}`; `409` if run active; `503` if unconfigured.
  - `GET /api/pocketcoder/chats/{chatId}/stream?cursor=N` — SSE; does NOT `Reserve`; attaches to the hub; flushes `Snapshot` then `Buffered` then live, each with `id:` = seq; on `ColdReplayNeeded` runs a Goose bounded replay first (reuse the old `ReplayReserved` history walk, but without reserving) then flushes + live.
  - `POST …/session/cancel` — `202`.
- **Removed:** `POST …/runs` and `GET …/events` (the reserve-and-409 replay). Keep `gooseSessionForChat`/`saveGooseSession`.

- [ ] **Step 1: Write the failing test**

```go
func TestPromptReturns202WithRunId(t *testing.T) {
	// Boot a test PocketBase app with the agent API registered and a fake
	// coordinator dial; POST session/prompt; assert 202 and a JSON runId.
	// (Follow the existing agent_test.go harness for app setup + auth token.)
}

func TestStreamDoesNotReserveAndEmitsSeqIds(t *testing.T) {
	// Start a run via prompt, then GET stream?cursor=0; assert the response
	// carries `id:` lines matching the published seq order, and that a second
	// concurrent stream also attaches (no 409 on stream).
}

func TestSecondPromptWhileActiveReturns409(t *testing.T) {
	// POST prompt twice without finishing; second returns 409.
}
```

(These are HTTP-level tests. Model them on the current `internal/api/agent_test.go` setup — same app bootstrap, auth, and a `Config.Dial` fake injected via a test seam. If the current tests construct the coordinator internally, add a package-level hook to inject a fake dial for tests, mirroring how `coordinator.Config.Dial` already supports it.)

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/pocketbase && go test ./internal/api/ -run 'TestPromptReturns202|TestStreamDoesNotReserve|TestSecondPrompt' -v`
Expected: FAIL — routes not present.

- [ ] **Step 3: Write minimal implementation**

Replace the `/runs` and `/events` handlers. `prompt`:

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
	input.Prompt = strings.TrimSpace(input.Prompt)
	if input.Prompt == "" {
		return re.BadRequestError("prompt is required", nil)
	}
	runID, err := service.StartPrompt(chatID, input.Prompt,
		func(ctx context.Context) (string, error) { return gooseSessionForChat(app, chatID, re.Auth.Id) },
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

`stream`: parse `cursor` (query or `Last-Event-ID` header), `att := service.Attach(chatID, cursor)` (add a `Coordinator.Attach` pass-through to `hubFor(chatID).Attach`), set SSE headers, write `Snapshot` then `Buffered` (each `writeEventWithID(seq, ev)`), then loop over `att.Live` until `re.Request.Context().Done()` or channel close, calling `att.Unsubscribe()` on exit. For `ColdReplayNeeded`, first run the Goose replay walk into the stream (reuse the `session/load` history logic, no `Reserve`). The SSE writer must emit `id: <seq>` — extend the writer or write raw `id:`/`data:` lines (the AG-UI `sse.NewSSEWriter` may not emit `id:`; if not, write frames manually per spec §4).

- [ ] **Step 4: Run test to verify it passes**

Run: `cd services/pocketbase && go test ./internal/api/ -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add services/pocketbase/internal/api/agent.go services/pocketbase/internal/api/agent_test.go
git commit -m "feat(api): prompt(202)+stream(cursor) split with SSE id:"
```

---

### Task 14: set_mode / set_config / permission / elicitation routes + chats delete hook

**Files:**
- Modify: `internal/api/agent.go`
- Test: `internal/api/agent_test.go`

**Interfaces:**
- Produces routes: `POST …/session/set_mode` (`{"modeId": string}` → `SetMode`), `POST …/session/set_config_option` (verbatim ACP `SetSessionConfigOptionRequest` body → `SetConfigOption`), `POST …/session/request_permission/{id}` (renamed from `/approvals/{id}`, `{"optionId"}` → `Approve`), `POST …/session/elicitation/{id}` (`{"outcome":"accept|decline|cancel", ...}` → `ResolveElicitation`). Plus an `OnRecordAfterDeleteSuccess("chats")` hook → `service.DeleteSession(chatID)` (best-effort `UnstableDeleteSession` + reconcile-log on failure; never blocks the delete).

- [ ] **Step 1: Write the failing test**

```go
func TestSetModeRoute202(t *testing.T) { /* POST set_mode during an active run → 202; fake conn sees the mode */ }
func TestElicitationRoute202(t *testing.T) { /* POST elicitation/{id} accept → 202; handler resumes */ }
func TestChatDeleteTriggersSessionDelete(t *testing.T) {
	// Create a chat + goose_sessions mapping; delete the chat record; assert
	// the fake conn observed UnstableDeleteSession and the mapping row is gone.
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/pocketbase && go test ./internal/api/ -run 'TestSetModeRoute|TestElicitationRoute|TestChatDeleteTriggers' -v`
Expected: FAIL — routes/hook absent.

- [ ] **Step 3: Write minimal implementation**

Add the four routes (mirror the existing `approvals` handler for ownership + error mapping; `set_config_option` binds the ACP union struct directly). Register the delete hook in `RegisterAgentApi`:

```go
app.OnRecordAfterDeleteSuccess("chats").BindFunc(func(e *core.RecordEvent) error {
	chatID := e.Record.Id
	go func() {
		if err := service.DeleteSession(context.Background(), app, chatID); err != nil {
			app.Logger().Error("goose session delete failed; queued for reconcile", "chat_id", chatID, "error", err)
		}
	}()
	return e.Next()
})
```

`Coordinator.DeleteSession` dials (or reuses) a short-lived conn, resolves the mapping, calls `UnstableDeleteSession`, removes the `goose_sessions` row on success; on failure it leaves the row for a startup/periodic reconcile sweep (a follow-up hook — for v1, the error log + orphaned row is the documented floor; add a `RUN_ERROR`-free `session_delete_failed` log line).

- [ ] **Step 4: Run test to verify it passes**

Run: `cd services/pocketbase && go test ./internal/api/ -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add services/pocketbase/internal/api/agent.go services/pocketbase/internal/api/agent_test.go
git commit -m "feat(api): set_mode/set_config/permission/elicitation routes + chat-delete hook"
```

---

### Task 15: Live-Goose integration (build-tagged) + wiring update

**Files:**
- Create: `services/pocketbase/internal/agent/coordinator/live_acp_test.go` (build tag `//go:build live_acp`)
- Modify: `tests/agent-c1/*` (update to the `prompt`+`stream` split)

**Interfaces:**
- Consumes: the full stack against a real Goose container.

- [ ] **Step 1: Write the failing test**

A `//go:build live_acp` test that: starts a run via `StartPrompt` against real Goose (env `GOOSE_ACP_URL`/secret), attaches a stream, asserts a full authed turn renders `RUN_STARTED … RUN_FINISHED` with a real tool/diff turn flowing through the translation unit; reconnects mid-turn with a cursor and asserts no gap; wrong token → the dial fails loudly. (Model on the existing `tests/agent-c1` harness.)

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/pocketbase && go test -tags live_acp ./internal/agent/coordinator/ -run TestLiveAcp -v`
Expected: FAIL until the stack is wired (or SKIP if Goose env absent — gate with `t.Skip` when `GOOSE_ACP_URL` is empty).

- [ ] **Step 3: Bring the stack up and implement any gaps**

Follow `CLAUDE.md` model-generation pipeline only if schema changed (it does not here). Rebuild + start c1/c2: `docker compose build pocketbase opencode && docker compose up -d pocketbase opencode`. Update `tests/agent-c1` scripts to POST `session/prompt` and GET `session/stream?cursor=`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd services/pocketbase && go test -tags live_acp ./internal/agent/coordinator/ -run TestLiveAcp -v`
Expected: PASS against live Goose.

- [ ] **Step 5: Commit**

```bash
git add services/pocketbase/internal/agent/coordinator/live_acp_test.go tests/agent-c1
git commit -m "test(agent): live_acp integration for the detached bridge"
```

---

## Self-Review

**Spec coverage** (§ → task):
- §4 hub (seq, atomic attach, drop-slow, snapshot, linger/evict, teardown) → Tasks 2–6. ✓
- §4a build-in-house → no dependency added (Tasks 1–6 are stdlib-only). ✓
- §5 detached lifecycle (bg/dial ctx, 202 runId, idempotent teardown, cancel triggers, Reserve-last, panic) → Tasks 9, 10. ✓
- §6 Goose conn (dial-per-run owned by run, Elicitation capability, init sequence, orphan compensation) → Tasks 9, 10, 12. ✓
- §7 endpoint table → Tasks 13, 14. ✓
- §8 elicitation + set_mode/set_config → Tasks 12, 14. ✓
- §9 session lifecycle (new/load kept, delete hook + reconcile floor, close/fork deferred) → Tasks 10, 14. ✓
- §10 error taxonomy (`goose_unavailable`/`run_timeout`/`run_too_large`/`protocol_error`/`session_delete_failed`) → Tasks 9, 14. ✓
- §11 decisions (chat-global seq, subscriber-owned backlog, merged Snapshot, sync.Once) → Tasks 2, 3, 7, 9. ✓
- §12 testing (deterministic hub, lifecycle, method, live_acp) → all tasks + Task 15. ✓
- §13 module structure → matches File Structure above. ✓

**Deferred (spec §14, correctly out):** c1-restart durability, pooled conn, `session/close`, `session/fork`, providers/model, Flutter client, cron.

**Type consistency:** `Finished(stopReason)` (Task 7) is used in Task 9's `runLoop`. `Attach`/`Attachment` (Task 3) consumed by Task 13. `Conn` additions (Task 11) consumed by Tasks 10/12. `Clock` (Task 1) threaded through hub (Task 2) and coordinator (Task 8). Hub `StartRun(runID, snapshot)`/`Publish`/`FinishRun`/`Attach`/`IsEmpty` names are consistent across Tasks 2–9.

**Verify-at-impl-time notes (intentional, not placeholders):** AG-UI event constructor/accessor names (`NewTextMessageContentEvent`, `NewRunFinishedEvent`+`WithResult`, `NewStateSnapshotEvent`, `EventTypeStateSnapshot`/`EventTypeRunFinished`, `NewRunErrorEvent`+`WithErrorCode`) and the translation `Bridge`'s internal field names (`threadID`/`runID`/`openTools`) must be confirmed against the actual SDK / merged translation unit as each task is implemented — TDD makes the RED step catch any mismatch. This plan pins the ACP SDK shapes (verified against `acp-go-sdk@v0.13.5`): `PromptResponse.StopReason`, `StopReason*` constants, `ClientCapabilities.Elicitation`/`ElicitationCapabilities.Form`, `SetSessionConfigOptionRequest`, `UnstableDeleteSessionRequest`, `UnstableCreateElicitation{Request,Response,Accept,Decline,Cancel}`, `NewSessionResponse.{Modes,ConfigOptions}`.

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-07-19-robust-c1-c2-bridge.md`.** Phase A (Tasks 1–6) is a self-contained, deterministic, Goose-free unit — a clean first checkpoint. Phase B (7–10) and Phase C (11–15) build on it and consume the merged translation unit.
