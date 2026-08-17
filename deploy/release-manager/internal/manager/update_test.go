package manager

import (
	"os"
	"path/filepath"
	"reflect"
	"testing"

	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/contract"
	releasecontract "github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/release"
	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/state"
	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/transaction"
)

func TestDiscoverLocalSelectionsPreservesAcquiredHarnessesAndOptionalImages(t *testing.T) {
	current := releasecontract.Current{SelectedHarnesses: []string{"goose"}}
	previous := contract.Manifest{Images: contract.Images{
		Choices: map[string]contract.ChoiceGroup{
			"coding": {
				CatalogDocument: "coding-harnesses",
				Options: map[string]contract.Artifact{
					"goose":  {Images: []string{"goose:a"}},
					"codex":  {Images: []string{"codex:a"}},
					"absent": {Images: []string{"absent:a"}},
				},
			},
		},
		Registry: contract.RegistryImages{Optional: map[string]contract.OptionalRegistryImage{
			"ollama": {Image: "ollama:a"},
		}},
	}}
	local := map[string]bool{"goose:a": true, "codex:a": true, "ollama:a": true}

	discoverLocalSelections(&current, previous, func(image string) bool {
		return local[image]
	})

	if !reflect.DeepEqual(current.SelectedHarnesses, []string{"codex", "goose"}) {
		t.Fatalf("selected harnesses = %#v", current.SelectedHarnesses)
	}
	if !reflect.DeepEqual(current.SelectedOptionalImages, []string{"ollama"}) {
		t.Fatalf("selected optional images = %#v", current.SelectedOptionalImages)
	}
}

// RestorePrevious restores a release without a network round-trip, so its
// Resolved value must be able to satisfy Activation.Preload()'s
// verifier/bundle guard purely from the bundle Resolve() persisted at
// install time -- this was live-broken (Issue 1 in
// docs/testing/vps-full-suite-remaining-issues.md): "release attestation
// verifier is required".
func TestPreviousResolvedLoadsPersistedBundleForOfflineVerification(t *testing.T) {
	root := t.TempDir()
	digest := "deadbeef"
	bundle := []byte("bundle-bytes")
	if err := os.MkdirAll(filepath.Join(root, "manifests"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(releasecontract.BundlePath(root, digest), bundle, 0o644); err != nil {
		t.Fatal(err)
	}
	update := &Update{Paths: state.NewPaths(root, t.TempDir(), t.TempDir(), t.TempDir()+"/current")}
	resolved, err := update.previousResolved(transaction.Candidate{Digest: digest}, releasecontract.Current{})
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

func TestPreviousResolvedFailsWithoutAPersistedBundle(t *testing.T) {
	root := t.TempDir()
	update := &Update{Paths: state.NewPaths(root, t.TempDir(), t.TempDir(), t.TempDir()+"/current")}
	if _, err := update.previousResolved(transaction.Candidate{Digest: "missing"}, releasecontract.Current{}); err == nil {
		t.Fatal("expected an error when no bundle was persisted")
	}
}
