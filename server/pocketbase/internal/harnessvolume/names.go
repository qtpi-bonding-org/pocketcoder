// Package harnessvolume owns the deterministic Docker volume names used by
// dynamically provisioned harnesses and their authentication helpers.
package harnessvolume

import (
	"fmt"
	"regexp"
	"strings"
)

const AuthHomeMount = "/workspace/.pocketcoder_auth"
const GitSSHMount = "/run/pocketcoder/git"

var nameComponent = regexp.MustCompile(`^[a-zA-Z0-9][a-zA-Z0-9_.-]*$`)

// Names describes the durable workspace and authentication storage mounted
// into a harness container. Workspaces belong to PocketBase users. Login state
// belongs to a named harness account, which may be shared by multiple users.
type Names struct {
	Workspace string
	Auth      string
	GitSSH    string
}

// Resolve derives durable sibling volume names from the generic Compose
// workspace volume used as this deployment's namespace. The Compose volume's
// trailing "_workspace" is structural rather than part of the namespace.
func Resolve(base, userID, harnessCLI, accountID string) (Names, error) {
	for label, value := range map[string]string{
		"base volume": base,
		"user id":     userID,
		"harness CLI": harnessCLI,
	} {
		if !nameComponent.MatchString(value) {
			return Names{}, fmt.Errorf("invalid %s %q", label, value)
		}
	}
	if accountID != "" && !nameComponent.MatchString(accountID) {
		return Names{}, fmt.Errorf("invalid account id %q", accountID)
	}

	userSuffix := userID
	if len(userSuffix) > 8 {
		userSuffix = userSuffix[:8]
	}
	namespace := strings.TrimSuffix(base, "_workspace")
	if namespace == "" {
		return Names{}, fmt.Errorf("invalid base volume %q", base)
	}
	authName := fmt.Sprintf("%s_harness_%s_account_%s_auth_home", namespace, harnessCLI, accountID)
	if accountID == "" {
		authName = fmt.Sprintf("%s_harness_%s_user_%s_auth_home", namespace, harnessCLI, userID)
	}
	names := Names{
		Workspace: fmt.Sprintf("%s_user_%s_workspace", namespace, userSuffix),
		Auth:      authName,
		GitSSH:    fmt.Sprintf("%s_git_ssh_%s", namespace, userID),
	}
	if len(names.GitSSH) > 255 {
		return Names{}, fmt.Errorf("git volume name is too long")
	}
	return names, nil
}
