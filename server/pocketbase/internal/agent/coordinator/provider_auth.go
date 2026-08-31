package coordinator

import (
	"fmt"
	"strings"
)

// providerAuthFailure deliberately classifies only errors from a session
// whose harness account uses an account-owned login rather than a bare API
// key (SessionProfile.AccountLogin, resolved from credential_selections.mode
// == "oauth" for the session's (harness, provider) pair). That flag comes
// from the user's actual credential selection, not a hardcoded per-provider
// name list -- a name list is what this
// used to be (claude/claude-code only), and it silently left Codex's own
// account-login errors misclassified as a generic failure with no reauth
// path, even though harness_provision.go's renderEnv had already started
// treating Codex the same as Claude Code for credential purposes. Keying off
// the account's real credential mode means any future account-login harness
// is covered automatically. It does not modify the provider's durable auth
// volume: a failed request is a signal to reauthenticate, not permission to
// erase a user's saved login.
func providerAuthFailure(accountLogin bool, err error) bool {
	if err == nil || !accountLogin {
		return false
	}
	return matchesAuthFailureMarker(err)
}

// providerApiKeyFailure classifies a run failure from a session whose
// harness/provider pair uses a bare API key rather than an account-owned
// login (the accountLogin == false counterpart to providerAuthFailure).
// Without this, an api_key harness (goose, opencode) that gets a genuinely
// rejected/invalid key from its upstream provider collapsed into the same
// generic "goose_unavailable" code as a crashed container or a network
// failure -- indistinguishable from every other kind of failure, and giving
// the user no actionable signal to go fix their saved key. It intentionally
// reuses the same textual markers as providerAuthFailure: the upstream
// provider's own wording for "your credential was rejected" doesn't change
// based on whether PocketCoder obtained that credential via OAuth or a
// pasted key.
func providerApiKeyFailure(accountLogin bool, err error) bool {
	if err == nil || accountLogin {
		return false
	}
	return matchesAuthFailureMarker(err)
}

func matchesAuthFailureMarker(err error) bool {
	message := strings.ToLower(fmt.Sprintf("%v", err))
	for _, marker := range []string{
		"authentication required",
		"authentication failed",
		"auth required",
		"login required",
		"not logged in",
		"reauthenticate",
		"re-authenticate",
		"invalid api key",
		"invalid token",
		"token expired",
		"unauthorized",
		"forbidden",
		"401",
		"403",
		"please run claude login",
	} {
		if strings.Contains(message, marker) {
			return true
		}
	}
	return false
}

const (
	providerAuthRequiredCode  = "provider_auth_required"
	providerApiKeyInvalidCode = "provider_api_key_invalid"
)

// apiKeyInvalidMessage builds the invalid-credential copy for an api_key
// harness -- distinct from reauthRequiredMessage's OAuth-flavored "your
// saved login was kept" wording, since there is no login session to keep
// here, only a saved key the user should go check in Harness Connections.
func apiKeyInvalidMessage(harnessName string) string {
	if harnessName == "" {
		harnessName = "Your provider"
	}
	return harnessName + " rejected the saved API key. Check the key in Harness Connections."
}
