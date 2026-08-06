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
	att := h.Attach(2)     // caller already saw up to seq 2
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
	h.seqForTest(4)        // advance chat-global seq to 4 without buffering (test helper)
	h.Publish(textEv("e")) // 5
	att := h.Attach(2)     // wants > 2, but log base is 5 => gap at 3,4
	if !att.ColdReplayNeeded {
		t.Fatal("cursor precedes buffered base; cold replay required")
	}
	att.Unsubscribe()
}

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

// A never-run chat (fresh hub, nothing ever published) must still report
// ColdReplayNeeded so the stream route emits the bounded empty replay
// (RUN_STARTED+RUN_FINISHED) instead of hanging silently — and so a chat whose
// only history lives in Goose (fresh in-memory hub after a PocketBase restart)
// is replayed rather than dropped.
func TestAttachFreshChatNeedsColdReplay(t *testing.T) {
	h := NewChatHub(NewFakeClock(time.Unix(0, 0)), 30*time.Second, 8)
	att := h.Attach(0) // no run has ever happened: h.seq == 0
	if !att.ColdReplayNeeded {
		t.Fatal("fresh chat must need cold replay so the stream is not silent")
	}
	att.Unsubscribe()
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

func TestColdReplayAndLiveShareOneMonotonicSeq(t *testing.T) {
	h := NewChatHub(NewFakeClock(time.Unix(0, 0)), 30*time.Second, 8)
	// Simulate a cold replay allocating 3 seqs, then a live run allocating 2.
	a, b, c := h.nextSeq(), h.nextSeq(), h.nextSeq()
	h.StartRun("run-1", func() []events.Event { return nil })
	d := h.Publish(textEv("x"))
	e := h.Publish(textEv("y"))
	got := []int{a, b, c, d, e}
	for i := 1; i < len(got); i++ {
		if got[i] != got[i-1]+1 {
			t.Fatalf("seqs not strictly monotonic: %v", got)
		}
	}
	if a != 1 || e != 5 {
		t.Fatalf("want 1..5, got %v", got)
	}
}
