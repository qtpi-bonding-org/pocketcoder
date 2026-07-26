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

// @pocketcoder-core: Agent Coordinator. Owns the per-chat Goose ACP connection and the run/approval lifecycle.
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

// nextSeq allocates the next hub-global monotonic sequence number. It is
// used both by live Publish and by cold-replay emission so a single stream's
// ids are strictly increasing regardless of which path produced them.
func (h *ChatHub) nextSeq() int {
	h.mu.Lock()
	defer h.mu.Unlock()
	return h.nextSeqLocked()
}

// nextSeqLocked allocates the next seq; caller must hold h.mu.
func (h *ChatHub) nextSeqLocked() int {
	h.seq++
	return h.seq
}

func (h *ChatHub) Publish(ev events.Event) int {
	h.mu.Lock()
	defer h.mu.Unlock()
	item := seqEvent{Seq: h.nextSeqLocked(), Ev: ev}
	if h.active != nil {
		h.active.log = append(h.active.log, item)
	}
	for s := range h.subs {
		select {
		case s.live <- item:
		default:
			// Full live channel: drop the subscriber (keystone). Drain any
			// items still buffered in its channel first so a subsequent
			// receive observes the close immediately rather than replaying
			// stale events the subscriber already fell behind on — it must
			// reconnect via Attach(cursor) to resume from the hub's log, not
			// from remnants of its own dropped live channel.
			for len(s.live) > 0 {
				<-s.live
			}
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
		// the only source of that history is Goose. A fresh hub (h.seq == 0)
		// also needs replay: either the chat has never run — so the route
		// emits the bounded empty replay (RUN_STARTED+RUN_FINISHED) instead of
		// hanging silently — or its history lives only in Goose after a
		// PocketBase restart that reset the in-memory log.
		att.ColdReplayNeeded = cursor < h.seq || h.seq == 0
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
