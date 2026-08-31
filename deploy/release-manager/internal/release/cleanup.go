package release

import (
	"errors"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"regexp"

	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/contract"
	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/state"
)

var releaseDigestPattern = regexp.MustCompile(`^[0-9a-f]{64}$`)

type CleanupRuntime interface {
	ImageExists(string) bool
	RemoveImage(string) error
}

// CleanupRetainedReleases keeps the active and immediately previous release.
// An older release remains fully described if Docker refuses to remove one of
// its images, so a later cleanup can retry without orphaning managed state.
func CleanupRetainedReleases(paths state.Paths, runtime CleanupRuntime) error {
	current, exists, err := loadCurrentFile(filepath.Join(paths.Root, "current.json"))
	if err != nil {
		return err
	}
	if !exists || !releaseDigestPattern.MatchString(current.ReleaseDigest) {
		return fmt.Errorf("current release pointer is unavailable; refusing cleanup")
	}
	previous, previousExists, err := loadCurrentFile(filepath.Join(paths.Root, "previous.json"))
	if err != nil {
		return err
	}
	keepReleases := map[string]bool{current.ReleaseDigest: true}
	keepImages := stringSet(current.SelectedImages)
	if previousExists {
		if !releaseDigestPattern.MatchString(previous.ReleaseDigest) {
			return fmt.Errorf("previous release pointer is invalid; refusing cleanup")
		}
		keepReleases[previous.ReleaseDigest] = true
		for _, image := range previous.SelectedImages {
			keepImages[image] = struct{}{}
		}
	}

	manifestDirectory := filepath.Join(paths.Root, "manifests")
	entries, err := os.ReadDir(manifestDirectory)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	if err != nil {
		return err
	}
	for _, entry := range entries {
		if entry.IsDir() || filepath.Ext(entry.Name()) != ".json" {
			continue
		}
		digest := entry.Name()[:len(entry.Name())-len(".json")]
		if !releaseDigestPattern.MatchString(digest) || keepReleases[digest] {
			continue
		}
		manifestPath := filepath.Join(manifestDirectory, entry.Name())
		manifest, err := loadManifestFile(manifestPath)
		if err != nil {
			return err
		}
		removable := true
		for _, image := range allImages(manifest) {
			if _, keep := keepImages[image]; keep || !runtime.ImageExists(image) {
				continue
			}
			if err := runtime.RemoveImage(image); err != nil {
				log.Printf("[Cleanup] failed to remove image %s: %v", image, err)
				removable = false
			}
		}
		if !removable {
			continue
		}
		releaseDirectory := filepath.Join(paths.Releases, digest)
		if err := os.RemoveAll(releaseDirectory); err != nil {
			return err
		}
		if err := state.SyncDirectory(paths.Releases); err != nil {
			return err
		}
		if err := state.RemoveDurable(manifestPath); err != nil {
			return err
		}
		if err := state.RemoveDurable(BundlePath(paths.Root, digest)); err != nil {
			return err
		}
	}
	return nil
}

func loadCurrentFile(path string) (Current, bool, error) {
	data, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return Current{}, false, nil
	}
	if err != nil {
		return Current{}, false, err
	}
	var current Current
	if err := contract.DecodeStrict(data, &current); err != nil {
		return Current{}, false, err
	}
	return current, true, nil
}

func loadManifestFile(path string) (contract.Manifest, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return contract.Manifest{}, err
	}
	var manifest contract.Manifest
	if err := contract.DecodeStrict(data, &manifest); err != nil {
		return contract.Manifest{}, err
	}
	return manifest, nil
}

func allImages(manifest contract.Manifest) []string {
	images := make([]string, 0)
	for _, artifact := range manifest.Images.Required {
		images = append(images, artifact.Images...)
	}
	for _, group := range manifest.Images.Choices {
		for _, artifact := range group.Options {
			images = append(images, artifact.Images...)
		}
	}
	images = append(images, manifest.Images.Registry.Required...)
	for _, descriptor := range manifest.Images.Registry.Optional {
		images = append(images, descriptor.Image)
	}
	return images
}
