// State projection for the /pocketcoder/* namespace.
//
// PocketCoder state values are bounded current-value snapshots (the *latest*
// plan/mode/config/usage/etc.) that AG-UI clients keep rendered alongside the
// linear message/tool timeline. They are carried on STATE_DELTA / STATE_SNAPSHOT
// events, separate from TEXT_MESSAGE_START/END and TOOL_CALL_START/END, so
// emitting state never opens or closes a text/tool boundary — that invariant
// lets consumers treat the two streams independently.
//
// projection is package-private to the agui translation unit; callers hold
// it as a value field on Bridge and route set/remove operations through it.
package agui

import "github.com/ag-ui-protocol/ag-ui/sdks/community/go/pkg/core/events"

// projection owns the current-value map for /pocketcoder/* namespaces. A nil
// state map means "no namespaced state has been set yet", so snapshot() can
// return nil instead of an empty snapshot.
type projection struct {
	state map[string]any
}

// ensure lazily allocates the underlying map. Called by set; remove tolerates
// a nil map (matching ensure's contract that it's only consulted when state
// exists).
func (p *projection) ensure() {
	if p.state == nil {
		p.state = map[string]any{}
	}
}

// set stores value at /pocketcoder/<ns> and returns the STATE_DELTA event for
// the client to apply. Storing first means a snapshot taken immediately after
// a set sees the new value, which is what clients expect on reconnect.
func (p *projection) set(ns string, value any) events.Event {
	p.ensure()
	p.state[ns] = value
	return events.NewStateDeltaEvent([]events.JSONPatchOperation{{
		Op:    "add",
		Path:  "/pocketcoder/" + ns,
		Value: value,
	}})
}

// remove deletes the /pocketcoder/<ns> namespace and returns the matching
// STATE_DELTA. remove on an unknown namespace still emits a remove patch; the
// client treats it as a no-op and the next snapshot stays empty.
func (p *projection) remove(ns string) events.Event {
	if p.state != nil {
		delete(p.state, ns)
	}
	return events.NewStateDeltaEvent([]events.JSONPatchOperation{{
		Op:   "remove",
		Path: "/pocketcoder/" + ns,
	}})
}

// snapshot returns a single STATE_SNAPSHOT covering the entire /pocketcoder
// subtree, or nil when nothing has been set. One whole-subtree snapshot is
// cheaper than per-namespace snapshots and lets subscribers atomically rebuild
// the current state on attach.
func (p *projection) snapshot() []events.Event {
	if len(p.state) == 0 {
		return nil
	}
	return []events.Event{
		events.NewStateSnapshotEvent(map[string]any{"pocketcoder": p.state}),
	}
}
