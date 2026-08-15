package coordinator

import (
	"fmt"
	"strings"
)

// providerAuthFailure deliberately classifies only errors from the provider
// session path. It does not modify the provider's durable auth volume: a
// failed request is a signal to reauthenticate, not permission to erase a
// user's saved login.
func providerAuthFailure(provider string, err error) bool {
	if err == nil || (provider != "claude" && provider != "claude-code") {
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
