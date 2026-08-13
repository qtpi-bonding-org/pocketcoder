package release

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"time"

	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/artifact"
	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/contract"
	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/runtime"
	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/state"
	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/trust"
)

type Activation struct {
	ManifestBytes      []byte
	ManifestURL        string
	Manifest           contract.Manifest
	ReleaseDirectory   string
	RuntimeEnvironment string
	Harnesses          []string
	OptionalImages     []string
	Channel            string
	ChannelSequence    int64
	RevocationSequence int64
	Paths              state.Paths
	Fetcher            artifact.Fetcher
	Docker             runtime.Docker
	HealthURL          string
	HealthTimeout      time.Duration
	ReleaseBundle      []byte
	Verifier           trust.SubjectVerifier
}

func (activation Activation) Run() (Current, error) {
	// POCO:BEGIN bootstrap-activation-prepare
	digestBytes := sha256.Sum256(activation.ManifestBytes)
	digest := hex.EncodeToString(digestBytes[:])
	if err := activation.Preload(); err != nil {
		return Current{}, err
	}
	if err := switchCurrent(activation.Paths.Current, activation.ReleaseDirectory); err != nil {
		return Current{}, err
	}
	// POCO:END bootstrap-activation-prepare
	// POCO:BEGIN bootstrap-compose-start
	compose := filepath.Join(activation.ReleaseDirectory, "docker-compose.prebuilt.yml")
	profiles, err := activation.selectedProfiles()
	if err != nil {
		return Current{}, err
	}
	if err := activation.Docker.ComposeUp(compose, activation.RuntimeEnvironment, profiles); err != nil {
		return Current{}, err
	}
	healthURL := activation.HealthURL
	if healthURL == "" {
		healthURL = "http://127.0.0.1:8090/api/health"
	}
	timeout := activation.HealthTimeout
	if timeout == 0 {
		timeout = 3 * time.Minute
	}
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	if err := runtime.WaitHealthy(ctx, healthURL, 2*time.Second); err != nil {
		return Current{}, err
	}
	selectedImages, err := activation.selectedImages()
	if err != nil {
		return Current{}, err
	}
	current := Current{
		SchemaVersion: 1, ReleaseDigest: digest, SourceCommit: activation.Manifest.SourceCommit,
		ServerVersion: activation.Manifest.ServerVersion, DataVersion: activation.Manifest.DataVersion,
		DeploymentContractVersion: activation.Manifest.Compatibility.Deployment.ContractVersion,
		Compatibility:             activation.Manifest.Compatibility,
		Channel:                   activation.Channel, ChannelSequence: activation.ChannelSequence,
		RevocationSequence: activation.RevocationSequence, SelectedHarnesses: activation.Harnesses,
		SelectedOptionalImages: activation.OptionalImages, SelectedImages: selectedImages,
		ManifestURL: activation.ManifestURL, ActivatedAt: time.Now().UTC().Format(time.RFC3339),
	}
	if err := state.WriteJSONAtomic(filepath.Join(activation.Paths.Root, "current.json"), current, 0o644); err != nil {
		return Current{}, err
	}
	// POCO:END bootstrap-compose-start
	return current, nil
}

// Preload verifies the immutable server tree and makes every selected image
// available before the active server is interrupted.
func (activation Activation) Preload() error {
	// POCO:BEGIN bootstrap-verified-images
	if err := verifyInternalIdentity(activation.ReleaseDirectory, activation.Manifest); err != nil {
		return err
	}
	if activation.Verifier == nil || len(activation.ReleaseBundle) == 0 {
		return fmt.Errorf("release attestation verifier is required")
	}
	verify := func(subject []byte) error {
		return activation.Verifier.Verify("release", subject, activation.ReleaseBundle)
	}
	installer := artifact.ImageInstaller{Fetcher: activation.Fetcher, Runtime: activation.Docker, StagingDirectory: activation.Paths.Artifacts, Verify: verify}
	for id, descriptor := range activation.Manifest.Images.Required {
		if err := installer.Ensure("required."+id, descriptor); err != nil {
			return err
		}
	}
	for _, image := range activation.Manifest.Images.Registry.Required {
		if err := activation.Docker.PullImage(image); err != nil {
			return err
		}
	}
	remaining := stringSet(activation.Harnesses)
	for groupID, group := range activation.Manifest.Images.Choices {
		for id := range remaining {
			descriptor, exists := group.Options[id]
			if !exists {
				continue
			}
			if err := installer.Ensure("choices."+groupID+"."+id, descriptor); err != nil {
				return err
			}
			delete(remaining, id)
		}
	}
	if len(remaining) != 0 {
		return fmt.Errorf("selected harness is absent from release")
	}
	for _, id := range activation.OptionalImages {
		descriptor, exists := activation.Manifest.Images.Registry.Optional[id]
		if !exists {
			return fmt.Errorf("selected optional image %q is absent from release", id)
		}
		if err := activation.Docker.PullImage(descriptor.Image); err != nil {
			return err
		}
	}
	// POCO:END bootstrap-verified-images
	prepare := filepath.Join(activation.ReleaseDirectory, "deploy", "scripts", "prepare-runtime-env.sh")
	command := exec.Command(prepare, activation.RuntimeEnvironment, activation.Manifest.SourceCommit)
	command.Stdout, command.Stderr = os.Stdout, os.Stderr
	if err := command.Run(); err != nil {
		return fmt.Errorf("prepare runtime environment: %w", err)
	}
	return nil
}

func (activation Activation) selectedImages() ([]string, error) {
	selected := append([]string(nil), activation.Manifest.Images.Registry.Required...)
	for _, descriptor := range activation.Manifest.Images.Required {
		selected = append(selected, descriptor.Images...)
	}
	remaining := stringSet(activation.Harnesses)
	for _, group := range activation.Manifest.Images.Choices {
		for id := range remaining {
			if descriptor, exists := group.Options[id]; exists {
				selected = append(selected, descriptor.Images...)
				delete(remaining, id)
			}
		}
	}
	if len(remaining) != 0 {
		return nil, fmt.Errorf("selected harness is absent from release")
	}
	for _, id := range activation.OptionalImages {
		descriptor, exists := activation.Manifest.Images.Registry.Optional[id]
		if !exists {
			return nil, fmt.Errorf("selected optional image %q is absent from release", id)
		}
		selected = append(selected, descriptor.Image)
	}
	return selected, nil
}

func (activation Activation) selectedProfiles() ([]string, error) {
	profiles := make([]string, 0, len(activation.OptionalImages))
	seen := make(map[string]bool)
	for _, id := range activation.OptionalImages {
		descriptor, exists := activation.Manifest.Images.Registry.Optional[id]
		if !exists {
			return nil, fmt.Errorf("selected optional image %q is absent from release", id)
		}
		if !seen[descriptor.ComposeProfile] {
			profiles = append(profiles, descriptor.ComposeProfile)
			seen[descriptor.ComposeProfile] = true
		}
	}
	return profiles, nil
}

func verifyInternalIdentity(directory string, manifest contract.Manifest) error {
	data, err := os.ReadFile(filepath.Join(directory, "release.json"))
	if err != nil {
		return err
	}
	var identity struct {
		SchemaVersion             int    `json:"schemaVersion"`
		ServerVersion             string `json:"serverVersion"`
		SourceCommit              string `json:"sourceCommit"`
		ServerAPIVersion          int    `json:"serverApiVersion"`
		DataVersion               int    `json:"dataVersion"`
		DeploymentContractVersion int    `json:"deploymentContractVersion"`
	}
	if err := contract.DecodeStrict(data, &identity); err != nil {
		return err
	}
	if identity.SchemaVersion != 1 || identity.ServerVersion != manifest.ServerVersion || identity.SourceCommit != manifest.SourceCommit || identity.ServerAPIVersion != manifest.Compatibility.Server.APIVersion || identity.DataVersion != manifest.DataVersion || identity.DeploymentContractVersion != manifest.Compatibility.Deployment.ContractVersion {
		return fmt.Errorf("server files identity does not match release manifest")
	}
	return nil
}

func switchCurrent(path, target string) error {
	if info, err := os.Lstat(path); err == nil && info.Mode()&os.ModeSymlink == 0 {
		return fmt.Errorf("current release path is not a symbolic link")
	} else if err != nil && !os.IsNotExist(err) {
		return err
	}
	temporary := fmt.Sprintf("%s.tmp.%d", path, os.Getpid())
	os.Remove(temporary)
	if err := os.Symlink(target, temporary); err != nil {
		return err
	}
	defer os.Remove(temporary)
	if err := os.Rename(temporary, path); err != nil {
		return err
	}
	return state.SyncDirectory(filepath.Dir(path))
}
