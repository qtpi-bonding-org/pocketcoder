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
	log         []seqEvent // this run's events only (bounded by run length)
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
