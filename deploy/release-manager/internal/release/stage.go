package release

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"

	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/artifact"
	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/contract"
	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/state"
)

func StageServerFiles(fetcher artifact.Fetcher, manifest contract.Manifest, releaseDigest, releasesDirectory, artifactDirectory string, verify func([]byte) error) (string, error) {
	releaseDirectory := filepath.Join(releasesDirectory, releaseDigest)
	if info, err := os.Stat(releaseDirectory); err == nil {
		if !info.IsDir() {
			return "", fmt.Errorf("release path is not a directory")
		}
		if err := verifyInternalIdentity(releaseDirectory, manifest); err != nil {
			return "", err
		}
		return releaseDirectory, nil
	} else if !errors.Is(err, os.ErrNotExist) {
		return "", err
	}
	archivePath, err := fetcher.ArtifactToFile(manifest.ServerFiles, artifactDirectory)
	if err != nil {
		return "", err
	}
	defer os.Remove(archivePath)
	if err := verifyFile(archivePath, verify); err != nil {
		return "", err
	}
	if err := os.MkdirAll(releasesDirectory, 0o755); err != nil {
		return "", err
	}
	stagingDirectory, err := os.MkdirTemp(releasesDirectory, ".release-stage-")
	if err != nil {
		return "", err
	}
	defer os.RemoveAll(stagingDirectory)
	if err := artifact.ExtractServerFiles(archivePath, stagingDirectory, manifest.ServerFiles.UnpackedBytes); err != nil {
		return "", err
	}
	if err := verifyInternalIdentity(stagingDirectory, manifest); err != nil {
		return "", err
	}
	if err := os.Rename(stagingDirectory, releaseDirectory); err != nil {
		if _, statErr := os.Stat(releaseDirectory); statErr == nil {
			if identityErr := verifyInternalIdentity(releaseDirectory, manifest); identityErr == nil {
				return releaseDirectory, nil
			}
		}
		return "", err
	}
	if err := state.SyncDirectory(releasesDirectory); err != nil {
		return "", err
	}
	return releaseDirectory, nil
}

func verifyFile(path string, verify func([]byte) error) error {
	if verify == nil {
		return fmt.Errorf("release attestation verifier is required")
	}
	bytes, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	return verify(bytes)
}
