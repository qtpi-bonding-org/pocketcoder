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
