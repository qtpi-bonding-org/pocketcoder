package gitssh

import (
	"fmt"
	"regexp"
	"strings"
)

type Provider struct {
	ID, Host, User string
	Port           int
}

var providers = map[string]Provider{
	"github":   {"github", "github.com", "git", 22},
	"gitlab":   {"gitlab", "gitlab.com", "git", 22},
	"codeberg": {"codeberg", "codeberg.org", "git", 22},
}

var repoPattern = regexp.MustCompile(`^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$`)

func ProviderByID(id string) (Provider, bool) { p, ok := providers[strings.ToLower(id)]; return p, ok }

func CanonicalRepository(provider, repository string) (string, error) {
	if _, ok := ProviderByID(provider); !ok {
		return "", fmt.Errorf("unsupported git provider %q", provider)
	}
	r := strings.TrimSuffix(strings.TrimSpace(repository), ".git")
	if !repoPattern.MatchString(r) || strings.ContainsAny(r, "\r\n") {
		return "", fmt.Errorf("invalid repository %q", repository)
	}
	return r, nil
}

func SSHTarget(provider, repository string) (string, error) {
	p, ok := ProviderByID(provider)
	if !ok {
		return "", fmt.Errorf("unsupported git provider %q", provider)
	}
	r, err := CanonicalRepository(provider, repository)
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%s@%s:%s.git", p.User, p.Host, r), nil
}
