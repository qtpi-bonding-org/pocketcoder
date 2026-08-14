package harnessauth

import "testing"

func TestAttemptStatusMapping(t *testing.T) {
	tests := map[string]string{
		AttemptStatusStarting:  StatusConnecting,
		AttemptStatusAwaiting:  StatusConnecting,
		AttemptStatusSucceeded: StatusConnected,
		AttemptStatusCancelled: StatusDisconnected,
		AttemptStatusFailed:    StatusError,
		AttemptStatusExpired:   StatusError,
	}
	for attempt, want := range tests {
		if got := StatusForAttempt(attempt); got != want {
			t.Errorf("StatusForAttempt(%q) = %q, want %q", attempt, got, want)
		}
	}
}
