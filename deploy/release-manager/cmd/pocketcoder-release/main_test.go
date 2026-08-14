package main

import "testing"

func TestSelectedChannel(t *testing.T) {
	tests := []struct {
		name, requested, current, want string
		explicit                       bool
	}{
		{name: "keeps activated nightly channel", requested: "stable", current: "nightly", want: "nightly"},
		{name: "keeps activated beta channel", requested: "stable", current: "beta", want: "beta"},
		{name: "explicit command flag wins", explicit: true, requested: "stable", current: "nightly", want: "stable"},
		{name: "invalid recorded channel keeps requested default", requested: "stable", current: "invalid", want: "stable"},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			if got := selectedChannel(test.explicit, test.requested, test.current); got != test.want {
				t.Fatalf("selectedChannel() = %q, want %q", got, test.want)
			}
		})
	}
}
