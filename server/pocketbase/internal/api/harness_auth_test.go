package api

import (
	"testing"

	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/harnessauth"
)

func TestHarnessAuthAttemptStatusMapping(t *testing.T) {
	tests := map[string]string{
		harnessauth.AttemptStatusStarting:  accountStatusConnecting,
		harnessauth.AttemptStatusAwaiting:  accountStatusConnecting,
		harnessauth.AttemptStatusSucceeded: accountStatusConnected,
		harnessauth.AttemptStatusCancelled: accountStatusDisconnected,
		harnessauth.AttemptStatusFailed:    accountStatusError,
		harnessauth.AttemptStatusExpired:   accountStatusError,
	}
	for attempt, want := range tests {
		if got := statusForAttempt(attempt); got != want {
			t.Errorf("statusForAttempt(%q) = %q, want %q", attempt, got, want)
		}
	}
}
