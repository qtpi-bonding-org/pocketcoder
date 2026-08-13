// Package harnessvolume owns the deterministic Docker volume names used by
// dynamically provisioned harnesses and their authentication helpers.
package harnessvolume

import (
	"fmt"
	"regexp"
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

// Resolve derives durable volume names from the Compose workspace volume used
// as this deployment's namespace. The existing first-eight-character workspace
// suffix is retained so this change does not orphan deployed user workspaces.
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
	return Names{
		Workspace: fmt.Sprintf("%s_%s_workspace", base, userSuffix),
		Auth:      fmt.Sprintf("%s_harness_%s_account_%s_auth_home", base, harnessCLI, accountID),
	}, nil
}
