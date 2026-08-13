package coordinator

import (
	"testing"
	"time"
)

func newTestCoordinatorClk(t *testing.T, clk Clock) *Coordinator {
	t.Helper()
	c, err := New(Config{Workspace: "/w", Clock: clk})
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
