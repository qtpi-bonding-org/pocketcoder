package artifact

import (
	"fmt"
	"os"

	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/contract"
)

type ImageRuntime interface {
	ImageExists(string) bool
	LoadGzipArchive(string) error
}

type ImageInstaller struct {
	Fetcher          Fetcher
	Runtime          ImageRuntime
	StagingDirectory string
	Verify           func([]byte) error
}

func (installer ImageInstaller) Ensure(id string, descriptor contract.Artifact) error {
	allPresent := true
	for _, image := range descriptor.Images {
		if !installer.Runtime.ImageExists(image) {
			allPresent = false
			break
		}
	}
	if allPresent {
		return nil
	}
	if err := os.MkdirAll(installer.StagingDirectory, 0o700); err != nil {
		return err
	}
	path, err := installer.Fetcher.ArtifactToFile(descriptor, installer.StagingDirectory)
	if err != nil {
		return err
	}
	defer os.Remove(path)
	if installer.Verify == nil {
		return fmt.Errorf("release attestation verifier is required")
	}
	bytes, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	if err := installer.Verify(bytes); err != nil {
		return fmt.Errorf("verify artifact %s: %w", id, err)
	}
	if err := installer.Runtime.LoadGzipArchive(path); err != nil {
		return err
	}
	for _, image := range descriptor.Images {
		if !installer.Runtime.ImageExists(image) {
			return fmt.Errorf("artifact %s did not contain image %s", id, image)
		}
	}
	return nil
}
