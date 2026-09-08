package gitssh

import (
	"strings"
	"testing"
)

func TestCanonicalRepository(t *testing.T) {
	got, err := CanonicalRepository("github", "octo/hello.git")
	if err != nil || got != "octo/hello" {
		t.Fatalf("got %q, %v", got, err)
	}
	for _, v := range []string{"github.com/octo/hello", "octo/hello\nHost evil", "octo"} {
		if _, err := CanonicalRepository("github", v); err == nil {
			t.Errorf("accepted %q", v)
		}
	}
}

func TestGenerateAndImport(t *testing.T) {
	k, err := GenerateKey("pocketcoder")
	if err != nil {
		t.Fatal(err)
	}
	if k.Fingerprint == "" || len(k.Private) == 0 || k.Public == "" {
		t.Fatal("incomplete key")
	}
	i, err := ImportKey(k.Private, "pocketcoder")
	if err != nil {
		t.Fatal(err)
	}
	if i.Fingerprint != k.Fingerprint {
		t.Fatalf("fingerprint changed: %s != %s", i.Fingerprint, k.Fingerprint)
	}
}

func TestConfigStableOrdering(t *testing.T) {
	c, err := RenderConfig([]Access{{ID: "b", Provider: "github", Repository: "a/b", CredentialID: "k2"}, {ID: "a", Provider: "gitlab", Repository: "a/c", CredentialID: "k1"}})
	if err != nil {
		t.Fatal(err)
	}
	if len(c) == 0 || c[0:8] != "Host pcg" {
		t.Fatalf("unexpected config: %s", c)
	}
}

func TestCanonicalRepositoryAcceptsCustomProviderWithoutARegistryEntry(t *testing.T) {
	got, err := CanonicalRepository("custom", "org/repo.git")
	if err != nil || got != "org/repo" {
		t.Fatalf("got %q, %v", got, err)
	}
}

func TestConfigRendersACustomProviderUsingItsOwnHostAndPort(t *testing.T) {
	c, err := RenderConfig([]Access{{ID: "a", Provider: "custom", Repository: "org/repo", CredentialID: "k1", Host: "git.example.com", Port: 2222}})
	if err != nil {
		t.Fatal(err)
	}
	for _, want := range []string{"HostName git.example.com", "HostKeyAlias git.example.com", "Port 2222"} {
		if !strings.Contains(c, want) {
			t.Fatalf("config missing %q: %s", want, c)
		}
	}
}

func TestConfigRejectsACustomProviderWithNoHost(t *testing.T) {
	if _, err := RenderConfig([]Access{{ID: "a", Provider: "custom", Repository: "org/repo", CredentialID: "k1"}}); err == nil {
		t.Fatal("expected an error for a custom provider with no host")
	}
}

func TestRenderRemotesDocIsEmptyForNoAccess(t *testing.T) {
	if got := RenderRemotesDoc(nil); got != "" {
		t.Fatalf("expected empty doc for no access, got %q", got)
	}
}

func TestRenderRemotesDocUsesTheAliasNotTheRealHostname(t *testing.T) {
	doc := RenderRemotesDoc([]Access{{ID: "acc1", Provider: "github", Repository: "octo/hello.git"}})
	want := "git clone git@pcgit-acc1:octo/hello.git"
	if !strings.Contains(doc, want) {
		t.Fatalf("doc missing %q: %s", want, doc)
	}
	if strings.Contains(doc, "github.com") {
		t.Fatalf("doc must route through the pcgit- alias, not the real hostname: %s", doc)
	}
}

func TestRenderRemotesDocSkipsAnInvalidEntryRatherThanFailingTheWholeDoc(t *testing.T) {
	doc := RenderRemotesDoc([]Access{
		{ID: "bad", Provider: "unsupported-provider", Repository: "x/y"},
		{ID: "good", Provider: "github", Repository: "octo/hello"},
	})
	if strings.Contains(doc, "pcgit-bad") {
		t.Fatalf("expected the invalid entry to be skipped: %s", doc)
	}
	if !strings.Contains(doc, "pcgit-good") {
		t.Fatalf("expected the valid entry to still render: %s", doc)
	}
}
