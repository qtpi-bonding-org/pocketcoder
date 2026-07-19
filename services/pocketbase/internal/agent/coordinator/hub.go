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
