// Package harnessvolume owns the deterministic Docker volume names used by
// dynamically provisioned harnesses and their authentication helpers.
package harnessvolume

import (
	"fmt"
	"regexp"
	"strings"
)

const AuthHomeMount = "/workspace/.pocketcoder_auth"

var nameComponent = regexp.MustCompile(`^[a-zA-Z0-9][a-zA-Z0-9_.-]*$`)

// Names describes the durable workspace and authentication storage mounted
// into a harness container. Workspaces belong to PocketBase users. Login state
// belongs to a named harness account, which may be shared by multiple users.
type Names struct {
	Workspace string
	Auth      string
}

// Resolve derives durable sibling volume names from the generic Compose
// workspace volume used as this deployment's namespace. The Compose volume's
// trailing "_workspace" is structural rather than part of the namespace.
func Resolve(base, userID, harnessCLI, accountID string) (Names, error) {
	for label, value := range map[string]string{
		"base volume": base,
		"user id":     userID,
		"harness CLI": harnessCLI,
		"account id":  accountID,
	} {
		if !nameComponent.MatchString(value) {
			return Names{}, fmt.Errorf("invalid %s %q", label, value)
		}
	}

	userSuffix := userID
	if len(userSuffix) > 8 {
		userSuffix = userSuffix[:8]
	}
	namespace := strings.TrimSuffix(base, "_workspace")
	if namespace == "" {
		return Names{}, fmt.Errorf("invalid base volume %q", base)
	}
	return Names{
		Workspace: fmt.Sprintf("%s_user_%s_workspace", namespace, userSuffix),
		Auth:      fmt.Sprintf("%s_harness_%s_account_%s_auth_home", namespace, harnessCLI, accountID),
	}, nil
}
