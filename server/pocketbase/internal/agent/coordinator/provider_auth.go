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
		"401",
		"please run claude login",
	} {
		if strings.Contains(message, marker) {
			return true
		}
	}
	return false
}

const providerAuthRequiredCode = "provider_auth_required"
