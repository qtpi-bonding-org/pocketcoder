// Package harnessvolume owns the deterministic Docker volume names used by
// dynamically provisioned harnesses and their authentication helpers.
package harnessvolume

import (
	"fmt"
	"regexp"
	"strings"
)

const AuthHomeMount = "/workspace/.pocketcoder_auth"

// GitSSHMount is nested under AuthHomeMount (harness_provision.go sets
// HOME=AuthHomeMount) so ssh/git find the materialized config at the
// conventional $HOME/.ssh/config -- no GIT_SSH_COMMAND override needed,
// and it's where an agent introspecting "do I have an SSH key" would
// actually look.
const GitSSHMount = AuthHomeMount + "/.ssh"

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
	namespace, err := namespaceOf(base)
	if err != nil {
		return Names{}, err
	}
	authName := fmt.Sprintf("%s_harness_%s_account_%s_auth_home", namespace, harnessCLI, accountID)
	if accountID == "" {
		authName = fmt.Sprintf("%s_harness_%s_user_%s_auth_home", namespace, harnessCLI, userID)
	}
	gitSSH, err := GitSSHVolumeName(base, userID)
	if err != nil {
		return Names{}, err
	}
	names := Names{
		Workspace: fmt.Sprintf("%s_user_%s_workspace", namespace, userSuffix),
		Auth:      authName,
		GitSSH:    gitSSH,
	}
	return names, nil
}

func namespaceOf(base string) (string, error) {
	namespace := strings.TrimSuffix(base, "_workspace")
	if namespace == "" {
		return "", fmt.Errorf("invalid base volume %q", base)
	}
	return namespace, nil
}

func GitSSHVolumeName(base, userID string) (string, error) {
	if !nameComponent.MatchString(userID) {
		return "", fmt.Errorf("invalid user id %q", userID)
	}
	namespace, err := namespaceOf(base)
	if err != nil {
		return "", err
	}
	name := fmt.Sprintf("%s_git_ssh_%s", namespace, userID)
	if len(name) > 255 {
		return "", fmt.Errorf("git volume name is too long")
	}
	return name, nil
}
