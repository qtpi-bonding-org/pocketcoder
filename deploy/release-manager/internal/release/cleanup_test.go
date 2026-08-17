package release

import (
	"errors"
	"os"
	"path/filepath"
	"testing"

	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/contract"
	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/state"
)

type fakeCleanupRuntime struct {
	images   map[string]bool
	failures map[string]bool
	removed  []string
}

func (runtime *fakeCleanupRuntime) ImageExists(image string) bool {
	return runtime.images[image]
}

func (runtime *fakeCleanupRuntime) RemoveImage(image string) error {
	if runtime.failures[image] {
		return errors.New("image is in use")
	}
	runtime.images[image] = false
	runtime.removed = append(runtime.removed, image)
	return nil
}

func TestCleanupRetainsCurrentAndPreviousAndRemovesOlderRelease(t *testing.T) {
	root := t.TempDir()
	paths := state.NewPaths(filepath.Join(root, "state"), filepath.Join(root, "releases"), filepath.Join(root, "artifacts"), filepath.Join(root, "current"))
	currentDigest := repeatedDigest('a')
	previousDigest := repeatedDigest('b')
	oldDigest := repeatedDigest('c')
	writeCleanupFixture(t, paths, currentDigest, previousDigest, oldDigest)
	runtime := &fakeCleanupRuntime{images: map[string]bool{
		"current:image": true, "previous:image": true,
		"old:image": true, "shared:image": true,
	}, failures: map[string]bool{}}
	if err := CleanupRetainedReleases(paths, runtime); err != nil {
		t.Fatal(err)
	}
	if len(runtime.removed) != 1 || runtime.removed[0] != "old:image" {
		t.Fatalf("removed = %#v", runtime.removed)
	}
	if _, err := os.Stat(filepath.Join(paths.Releases, oldDigest)); !os.IsNotExist(err) {
		t.Fatalf("old release tree remains: %v", err)
	}
	if _, err := os.Stat(filepath.Join(paths.Root, "manifests", oldDigest+".json")); !os.IsNotExist(err) {
		t.Fatalf("old manifest remains: %v", err)
	}
	// The attestation bundle persisted for rollback's offline verification
	// is release-scoped state exactly like the manifest -- an old release's
	// bundle must be pruned alongside its manifest, not orphaned forever.
	if _, err := os.Stat(BundlePath(paths.Root, oldDigest)); !os.IsNotExist(err) {
		t.Fatalf("old bundle remains: %v", err)
	}
	for _, digest := range []string{currentDigest, previousDigest} {
		if _, err := os.Stat(filepath.Join(paths.Releases, digest)); err != nil {
			t.Fatalf("retained release %s: %v", digest, err)
		}
		if _, err := os.Stat(BundlePath(paths.Root, digest)); err != nil {
			t.Fatalf("retained bundle %s: %v", digest, err)
		}
	}
}

func TestCleanupKeepsMetadataWhenDockerRefusesImageRemoval(t *testing.T) {
	root := t.TempDir()
	paths := state.NewPaths(filepath.Join(root, "state"), filepath.Join(root, "releases"), filepath.Join(root, "artifacts"), filepath.Join(root, "current"))
	currentDigest := repeatedDigest('a')
	previousDigest := repeatedDigest('b')
	oldDigest := repeatedDigest('c')
	writeCleanupFixture(t, paths, currentDigest, previousDigest, oldDigest)
	runtime := &fakeCleanupRuntime{
		images:   map[string]bool{"old:image": true},
		failures: map[string]bool{"old:image": true},
	}
	if err := CleanupRetainedReleases(paths, runtime); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(paths.Root, "manifests", oldDigest+".json")); err != nil {
		t.Fatalf("manifest should remain for retry: %v", err)
	}
	if _, err := os.Stat(filepath.Join(paths.Releases, oldDigest)); err != nil {
		t.Fatalf("release tree should remain for retry: %v", err)
	}
}

func writeCleanupFixture(t *testing.T, paths state.Paths, currentDigest, previousDigest, oldDigest string) {
	t.Helper()
	if err := os.MkdirAll(paths.Releases, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := state.WriteJSONAtomic(filepath.Join(paths.Root, "current.json"), Current{ReleaseDigest: currentDigest, SelectedImages: []string{"current:image", "shared:image"}}, 0o644); err != nil {
		t.Fatal(err)
	}
	if err := state.WriteJSONAtomic(filepath.Join(paths.Root, "previous.json"), Current{ReleaseDigest: previousDigest, SelectedImages: []string{"previous:image"}}, 0o644); err != nil {
		t.Fatal(err)
	}
	for _, digest := range []string{currentDigest, previousDigest, oldDigest} {
		if err := os.MkdirAll(filepath.Join(paths.Releases, digest), 0o755); err != nil {
			t.Fatal(err)
		}
		manifest := contract.Manifest{}
		if digest == oldDigest {
			manifest.Images.Required = map[string]contract.Artifact{
				"server": {Images: []string{"old:image", "shared:image"}},
			}
		}
		if err := state.WriteJSONAtomic(filepath.Join(paths.Root, "manifests", digest+".json"), manifest, 0o644); err != nil {
			t.Fatal(err)
		}
		if err := state.WriteAtomic(BundlePath(paths.Root, digest), []byte("bundle"), 0o644); err != nil {
			t.Fatal(err)
		}
	}
}

func repeatedDigest(value byte) string {
	result := make([]byte, 64)
	for index := range result {
		result[index] = value
	}
	return string(result)
}
