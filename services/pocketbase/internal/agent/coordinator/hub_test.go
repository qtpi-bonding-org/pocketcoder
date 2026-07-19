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
