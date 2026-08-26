package coordinator

import (
	"errors"
	"testing"
)

func TestProviderAuthFailure(t *testing.T) {
	for _, test := range []struct {
		name         string
		accountLogin bool
		err          string
		want         bool
	}{
		// Claude Code and Codex both resolve AccountLogin=true when the
		// account row is on OAuth login (harnessaccount.ModeAccount) --
		// providerAuthFailure no longer cares which harness it is, only
		// whether this session's credential is an account login.
		{"account-login/authentication required", true, "ACP: authentication required", true},
		{"account-login/401", true, "401 unauthorized", true},
		{"account-login/network failure", true, "temporary network failure", false},
		// An API-key-mode session (e.g. Goose, OpenCode, or Claude/Codex
		// configured with a bare provider key instead of account login)
		// never maps to the reauth flow, even on an auth-shaped message --
		// a bad API key needs a different fix (rotate the key), not a
		// "your saved login was kept" reauth prompt.
		{"api-key/authentication required", false, "authentication required", false},
	} {
		t.Run(test.name, func(t *testing.T) {
			if got := providerAuthFailure(test.accountLogin, errors.New(test.err)); got != test.want {
				t.Fatalf("providerAuthFailure() = %v, want %v", got, test.want)
			}
		})
	}
}
