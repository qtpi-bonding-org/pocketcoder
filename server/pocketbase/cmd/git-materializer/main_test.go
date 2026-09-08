package main

import (
	"archive/tar"
	"bytes"
	"os"
	"path/filepath"
	"testing"
)

func buildManifest(t *testing.T, files map[string]string) string {
	t.Helper()
	var buf bytes.Buffer
	tw := tar.NewWriter(&buf)
	for name, content := range files {
		mode := int64(0644)
		if filepath.Dir(name) == "keys" {
			mode = 0600
		}
		if err := tw.WriteHeader(&tar.Header{Name: name, Mode: mode, Size: int64(len(content))}); err != nil {
			t.Fatal(err)
		}
		if _, err := tw.Write([]byte(content)); err != nil {
			t.Fatal(err)
		}
	}
	if err := tw.Close(); err != nil {
		t.Fatal(err)
	}

	dir := t.TempDir()
	inbox := filepath.Join(dir, "inbox")
	if err := os.MkdirAll(inbox, 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(inbox, "manifest.tar"), buf.Bytes(), 0600); err != nil {
		t.Fatal(err)
	}
	return inbox
}

func TestMaterializeWritesFilesFromTheManifest(t *testing.T) {
	inbox := buildManifest(t, map[string]string{
		"config":  "Host pcgit-a\n",
		"known_hosts": "github.com ssh-ed25519 AAAA\n",
		"keys/cred1":  "private-key-1",
	})
	state := t.TempDir()

	if err := materialize(inbox, state); err != nil {
		t.Fatal(err)
	}

	for name, want := range map[string]string{
		"config":  "Host pcgit-a\n",
		"known_hosts": "github.com ssh-ed25519 AAAA\n",
		"keys/cred1":  "private-key-1",
	} {
		got, err := os.ReadFile(filepath.Join(state, "current", name))
		if err != nil {
			t.Fatalf("read %s: %v", name, err)
		}
		if string(got) != want {
			t.Fatalf("%s = %q, want %q", name, got, want)
		}
	}
}

func TestMaterializeCarriesForwardKeysNotInTheNewManifest(t *testing.T) {
	state := t.TempDir()

	firstInbox := buildManifest(t, map[string]string{
		"config":  "Host pcgit-a\n",
		"known_hosts": "github.com ssh-ed25519 AAAA\n",
		"keys/cred1":  "private-key-1",
	})
	if err := materialize(firstInbox, state); err != nil {
		t.Fatal(err)
	}

	secondInbox := buildManifest(t, map[string]string{
		"config":  "Host pcgit-a\nHost pcgit-b\n",
		"known_hosts": "github.com ssh-ed25519 AAAA\ngitlab.com ssh-ed25519 BBBB\n",
	})
	if err := materialize(secondInbox, state); err != nil {
		t.Fatal(err)
	}

	got, err := os.ReadFile(filepath.Join(state, "current", "keys", "cred1"))
	if err != nil {
		t.Fatalf("cred1's key did not survive the second pass: %v", err)
	}
	if string(got) != "private-key-1" {
		t.Fatalf("keys/cred1 = %q, want %q", got, "private-key-1")
	}

	config, err := os.ReadFile(filepath.Join(state, "current", "config"))
	if err != nil {
		t.Fatal(err)
	}
	if string(config) != "Host pcgit-a\nHost pcgit-b\n" {
		t.Fatalf("config not updated to the second pass's content: %q", config)
	}
}

func TestMaterializeOverwritesAFileThatChangedRatherThanKeepingTheOldOne(t *testing.T) {
	state := t.TempDir()

	first := buildManifest(t, map[string]string{"keys/cred1": "old-key"})
	if err := materialize(first, state); err != nil {
		t.Fatal(err)
	}

	second := buildManifest(t, map[string]string{"keys/cred1": "new-key"})
	if err := materialize(second, state); err != nil {
		t.Fatal(err)
	}

	got, err := os.ReadFile(filepath.Join(state, "current", "keys", "cred1"))
	if err != nil {
		t.Fatal(err)
	}
	if string(got) != "new-key" {
		t.Fatalf("keys/cred1 = %q, want %q (the new manifest's content should win)", got, "new-key")
	}
}

func TestMaterializeExposesConfigAndKnownHostsAtTheVolumeRoot(t *testing.T) {
	state := t.TempDir()

	first := buildManifest(t, map[string]string{
		"config":      "Host pcgit-a\n",
		"known_hosts": "github.com ssh-ed25519 AAAA\n",
	})
	if err := materialize(first, state); err != nil {
		t.Fatal(err)
	}

	// ssh's own default config/known-hosts lookup is $HOME/.ssh/config and
	// $HOME/.ssh/known_hosts directly -- these must resolve at the volume
	// root, not only under "current/", or an unmodified ssh/git invocation
	// (no -F override) would never find them.
	for name, want := range map[string]string{
		"config":      "Host pcgit-a\n",
		"known_hosts": "github.com ssh-ed25519 AAAA\n",
	} {
		got, err := os.ReadFile(filepath.Join(state, name))
		if err != nil {
			t.Fatalf("read root %s: %v", name, err)
		}
		if string(got) != want {
			t.Fatalf("root %s = %q, want %q", name, got, want)
		}
	}

	// A later generation must be picked up through the same root-level
	// name, since it follows "current" rather than pinning a generation.
	second := buildManifest(t, map[string]string{"config": "Host pcgit-a\nHost pcgit-b\n"})
	if err := materialize(second, state); err != nil {
		t.Fatal(err)
	}
	got, err := os.ReadFile(filepath.Join(state, "config"))
	if err != nil {
		t.Fatal(err)
	}
	if string(got) != "Host pcgit-a\nHost pcgit-b\n" {
		t.Fatalf("root config after rotation = %q", got)
	}
}

func TestMaterializeSucceedsOnTheFirstEverPassWithNoPriorGeneration(t *testing.T) {
	inbox := buildManifest(t, map[string]string{"config": "Host pcgit-a\n"})
	state := t.TempDir()

	if err := materialize(inbox, state); err != nil {
		t.Fatal(err)
	}
}
