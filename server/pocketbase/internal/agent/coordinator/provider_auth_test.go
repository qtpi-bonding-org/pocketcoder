package coordinator

import (
	"errors"
	"testing"
)

func TestProviderAuthFailure(t *testing.T) {
	for _, test := range []struct {
		provider string
		err      string
		want     bool
	}{
		{"claude", "ACP: authentication required", true},
		{"claude-code", "401 unauthorized", true},
		{"claude", "temporary network failure", false},
		{"codex", "authentication required", false},
	} {
		t.Run(test.provider+"/"+test.err, func(t *testing.T) {
			if got := providerAuthFailure(test.provider, errors.New(test.err)); got != test.want {
				t.Fatalf("providerAuthFailure() = %v, want %v", got, test.want)
			}
		})
	}
}
