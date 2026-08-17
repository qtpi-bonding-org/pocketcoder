package main

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/contract"
	releasecontract "github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/release"
	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/state"
)

func TestSelectedChannel(t *testing.T) {
	tests := []struct {
		name, requested, current, want string
		explicit                       bool
	}{
		{name: "keeps activated nightly channel", requested: "stable", current: "nightly", want: "nightly"},
		{name: "keeps activated beta channel", requested: "stable", current: "beta", want: "beta"},
		{name: "explicit command flag wins", explicit: true, requested: "stable", current: "nightly", want: "stable"},
		{name: "invalid recorded channel keeps requested default", requested: "stable", current: "invalid", want: "stable"},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			if got := selectedChannel(test.explicit, test.requested, test.current); got != test.want {
				t.Fatalf("selectedChannel() = %q, want %q", got, test.want)
			}
		})
	}
}

func TestReadHostNixosVersion(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "nixos-version")
	t.Setenv("POCKETCODER_NIXOS_VERSION_FILE", path)

	if got := readHostNixosVersion(); got != "" {
		t.Fatalf("expected empty string for a missing file, got %q", got)
	}

	if err := os.WriteFile(path, []byte("26.05\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if got := readHostNixosVersion(); got != "26.05" {
		t.Fatalf("expected trimmed version, got %q", got)
	}
}

// rollback restores an already-installed release without a network
// round-trip, so it must prove that release verified using the bundle
// Resolve() persisted at install time, not by re-fetching it. This was
// live-broken (Issue 1 in docs/testing/vps-full-suite-remaining-issues.md):
// "release attestation verifier is required".
func TestResolvedFromPreviousLoadsPersistedBundleForOfflineVerification(t *testing.T) {
	root := t.TempDir()
	digest := "deadbeef"
	bundle := []byte("bundle-bytes")
	if err := os.MkdirAll(filepath.Join(root, "manifests"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(releasecontract.BundlePath(root, digest), bundle, 0o644); err != nil {
		t.Fatal(err)
	}
	paths := state.NewPaths(root, t.TempDir(), t.TempDir(), t.TempDir()+"/current")
	previous := releasecontract.Current{ReleaseDigest: digest}
	resolved, err := resolvedFromPrevious(paths, previous, contract.Manifest{}, contract.Revocations{})
	if err != nil {
		t.Fatal(err)
	}
	if string(resolved.ReleaseBundle) != string(bundle) {
		t.Fatalf("release bundle = %q, want %q", resolved.ReleaseBundle, bundle)
	}
	if resolved.Verifier == nil {
		t.Fatal("expected a verifier to be set")
	}
}

func TestResolvedFromPreviousFailsWithoutAPersistedBundle(t *testing.T) {
	root := t.TempDir()
	paths := state.NewPaths(root, t.TempDir(), t.TempDir(), t.TempDir()+"/current")
	previous := releasecontract.Current{ReleaseDigest: "missing"}
	if _, err := resolvedFromPrevious(paths, previous, contract.Manifest{}, contract.Revocations{}); err == nil {
		t.Fatal("expected an error when no bundle was persisted")
	}
}
