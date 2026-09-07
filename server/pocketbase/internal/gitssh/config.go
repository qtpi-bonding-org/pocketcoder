package gitssh

import (
	"fmt"
	"sort"
	"strings"
)

type Access struct {
	ID, Provider, Repository, CredentialID string
	// Host and Port are only used (and required) when Provider ==
	// CustomProviderID; built-in providers use their registry entry.
	Host string
	Port int
}

func RenderConfig(access []Access) (string, error) {
	items := append([]Access(nil), access...)
	sort.Slice(items, func(i, j int) bool { return items[i].ID < items[j].ID })
	var b strings.Builder
	for _, a := range items {
		host, user, port := "", "git", 22
		if a.Provider == CustomProviderID {
			if a.Host == "" {
				return "", fmt.Errorf("custom provider access %q has no host", a.ID)
			}
			host = a.Host
			if a.Port != 0 {
				port = a.Port
			}
		} else {
			p, ok := ProviderByID(a.Provider)
			if !ok {
				return "", fmt.Errorf("unsupported provider %q", a.Provider)
			}
			host, user, port = p.Host, p.User, p.Port
		}
		r, err := CanonicalRepository(a.Provider, a.Repository)
		if err != nil {
			return "", err
		}
		for _, v := range []string{a.ID, a.CredentialID} {
			if v == "" || strings.ContainsAny(v, "\r\n \t") {
				return "", fmt.Errorf("invalid access identity")
			}
		}
		fmt.Fprintf(&b, "Host pcgit-%s\n    HostName %s\n    HostKeyAlias %s\n    Port %d\n    User %s\n    IdentityFile /run/pocketcoder/git/current/keys/%s\n    IdentitiesOnly yes\n    IdentityAgent none\n    StrictHostKeyChecking yes\n    UserKnownHostsFile /run/pocketcoder/git/current/known_hosts\n    BatchMode yes\n\n", a.ID, host, host, port, user, a.CredentialID)
		_ = r
	}
	return b.String(), nil
}
