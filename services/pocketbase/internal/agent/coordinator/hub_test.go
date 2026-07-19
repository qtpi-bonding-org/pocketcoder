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
	h.seqForTest(4)        // advance chat-global seq to 4 without buffering (test helper)
	h.Publish(textEv("e")) // 5
	att := h.Attach(2)     // wants > 2, but log base is 5 => gap at 3,4
	if !att.ColdReplayNeeded {
		t.Fatal("cursor precedes buffered base; cold replay required")
	}
	att.Unsubscribe()
}
