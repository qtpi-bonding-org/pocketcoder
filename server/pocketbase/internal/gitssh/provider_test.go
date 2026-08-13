package gitssh

import "testing"

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
