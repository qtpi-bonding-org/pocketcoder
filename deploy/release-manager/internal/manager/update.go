package manager

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"syscall"
	"time"

	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/artifact"
	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/contract"
	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/progress"
	releasecontract "github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/release"
	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/runtime"
	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/snapshot"
	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/state"
	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/transaction"
)

type Update struct {
	Resolved           releasecontract.Resolved
	ManifestBytes      []byte
	Current            releasecontract.Current
	Paths              state.Paths
	RuntimeEnvironment string
	Fetcher            artifact.Fetcher
	Docker             runtime.Docker
	Snapshot           snapshot.Manager
	ReserveBytes       int64
	UpdaterContract    int
	Progress           progress.Sink
	HealthURL          string
	HealthTimeout      time.Duration
	candidateDirectory string
	previousManifest   contract.Manifest
	previousBytes      []byte
	previousActivation releasecontract.Activation
}

func (update *Update) Transaction() transaction.Manager {
	return transaction.Manager{JournalPath: update.Paths.Journal, LockPath: update.Paths.Lock, Operations: update}
}

func (update *Update) CleanupLocked() error {
	return releasecontract.CleanupRetainedReleases(update.Paths, update.Docker)
}

func (update *Update) Previous() transaction.Candidate {
	return transaction.Candidate{Digest: update.Current.ReleaseDigest, DataVersion: update.Current.DataVersion}
}

func (update *Update) Candidate() transaction.Candidate {
	return transaction.Candidate{Digest: update.Resolved.ManifestSHA256, DataVersion: update.Resolved.Manifest.DataVersion}
}

func (update *Update) Preflight(previous, candidate transaction.Candidate) error {
	update.report("fetching_release", "staging_server")
	manifest := update.Resolved.Manifest
	if _, revoked := update.Resolved.Revocations.RevokedReleases[candidate.Digest]; revoked {
		return fmt.Errorf("candidate release is revoked")
	}
	rangeValue := manifest.Compatibility.Deployment.SupportedSourceContractVersions
	if update.UpdaterContract < rangeValue.Minimum || update.UpdaterContract > rangeValue.Maximum {
		return fmt.Errorf("candidate requires a stepping-stone release: updater contract %d is outside %d..%d", update.UpdaterContract, rangeValue.Minimum, rangeValue.Maximum)
	}
	if previous.Digest != "" && previous.DataVersion < manifest.MinimumUpgradeFromDataVersion {
		return fmt.Errorf("server data version %d requires a stepping-stone release", previous.DataVersion)
	}
	if previous.Digest != "" {
		if err := state.WriteJSONAtomic(update.recoveryPointerPath(), update.Current, 0o600); err != nil {
			return err
		}
		previousPath := filepath.Join(update.Paths.Root, "manifests", previous.Digest+".json")
		data, err := os.ReadFile(previousPath)
		if err != nil {
			return err
		}
		if err := contract.DecodeStrict(data, &update.previousManifest); err != nil {
			return err
		}
		update.previousBytes = data
		discoverLocalSelections(&update.Current, update.previousManifest, update.Docker.ImageExists)
	}
	download, staging, err := selectedBytes(manifest, update.Current.SelectedHarnesses, update.Current.SelectedOptionalImages)
	if err != nil {
		return err
	}
	_ = download
	snapshotReserve := int64(0)
	if previous.Digest != "" && previous.DataVersion != candidate.DataVersion {
		snapshotReserve, err = update.Snapshot.VolumeBytes()
		if err != nil {
			return fmt.Errorf("measure PocketBase data volume: %w", err)
		}
	}
	required := staging + snapshotReserve + update.ReserveBytes
	available, err := availableBytes(update.Paths.Artifacts)
	if err != nil {
		return err
	}
	if available < required {
		return fmt.Errorf("insufficient disk: available %d, require %d", available, required)
	}
	directory, err := releasecontract.StageServerFiles(update.Fetcher, manifest, candidate.Digest, update.Paths.Releases, update.Paths.Artifacts)
	if err != nil {
		return err
	}
	update.candidateDirectory = directory
	activation := update.activation(update.Resolved, update.ManifestBytes, directory, update.Current.SelectedHarnesses, update.Current.SelectedOptionalImages)
	update.report("loading_images", "preloading_selected_images")
	return activation.Preload()
}

func discoverLocalSelections(current *releasecontract.Current, previous contract.Manifest, imageExists func(string) bool) {
	harnesses := stringSet(current.SelectedHarnesses)
	optional := stringSet(current.SelectedOptionalImages)
	for _, group := range previous.Images.Choices {
		if group.CatalogDocument != "coding-harnesses" {
			continue
		}
		for id, descriptor := range group.Options {
			if artifactIsLocal(descriptor, imageExists) {
				harnesses[id] = struct{}{}
			}
		}
	}
	for id, descriptor := range previous.Images.Registry.Optional {
		if imageExists(descriptor.Image) {
			optional[id] = struct{}{}
		}
	}
	current.SelectedHarnesses = sortedSet(harnesses)
	current.SelectedOptionalImages = sortedSet(optional)
}

func artifactIsLocal(descriptor contract.Artifact, imageExists func(string) bool) bool {
	if len(descriptor.Images) == 0 {
		return false
	}
	for _, image := range descriptor.Images {
		if !imageExists(image) {
			return false
		}
	}
	return true
}

func sortedSet(values map[string]struct{}) []string {
	result := make([]string, 0, len(values))
	for value := range values {
		result = append(result, value)
	}
	sort.Strings(result)
	return result
}

func stringSet(values []string) map[string]struct{} {
	result := make(map[string]struct{}, len(values))
	for _, value := range values {
		result[value] = struct{}{}
	}
	return result
}

func (update *Update) CreateSnapshot(previous transaction.Candidate) (transaction.Snapshot, error) {
	path, err := update.Snapshot.Create(previous.Digest, previous.DataVersion)
	return transaction.Snapshot{Path: path}, err
}

func (update *Update) StopPrevious(previous transaction.Candidate) error {
	compose := filepath.Join(update.Paths.Releases, previous.Digest, "docker-compose.prebuilt.yml")
	return update.Docker.ComposeDown(compose, update.RuntimeEnvironment)
}

func (update *Update) Activate(_ transaction.Candidate) error {
	update.report("compose_up", "starting_services")
	_, err := update.activation(update.Resolved, update.ManifestBytes, update.candidateDirectory, update.Current.SelectedHarnesses, update.Current.SelectedOptionalImages).Run()
	return err
}

func (update *Update) Commit(previous, _ transaction.Candidate) error {
	if previous.Digest == "" {
		return nil
	}
	if err := state.WriteJSONAtomic(filepath.Join(update.Paths.Root, "previous.json"), update.Current, 0o644); err != nil {
		return err
	}
	return state.RemoveDurable(update.recoveryPointerPath())
}

func (update *Update) RestoreSnapshot(_ transaction.Candidate, value transaction.Snapshot) error {
	return update.Snapshot.Restore(value.Path)
}

func (update *Update) RestorePrevious(previous transaction.Candidate) error {
	if previous.Digest == "" {
		return nil
	}
	previousCurrent := update.Current
	if data, err := os.ReadFile(update.recoveryPointerPath()); err == nil {
		if err := contract.DecodeStrict(data, &previousCurrent); err != nil {
			return err
		}
	}
	if len(update.previousBytes) == 0 {
		data, err := os.ReadFile(filepath.Join(update.Paths.Root, "manifests", previous.Digest+".json"))
		if err != nil {
			return err
		}
		if err := contract.DecodeStrict(data, &update.previousManifest); err != nil {
			return err
		}
		update.previousBytes = data
	}
	directory := filepath.Join(update.Paths.Releases, previous.Digest)
	resolved := releasecontract.Resolved{ManifestSHA256: previous.Digest, ManifestURL: previousCurrent.ManifestURL, ChannelSequence: previousCurrent.ChannelSequence, RevocationSequence: previousCurrent.RevocationSequence, Manifest: update.previousManifest}
	activation := update.activation(resolved, update.previousBytes, directory, previousCurrent.SelectedHarnesses, previousCurrent.SelectedOptionalImages)
	update.previousActivation = activation
	update.report("compose_up", "restoring_previous_release")
	_, err := activation.Run()
	if err != nil {
		return err
	}
	if err := state.RemoveDurable(update.recoveryPointerPath()); err != nil {
		return err
	}
	return nil
}

func (update *Update) report(phase, detail string) {
	if update.Progress != nil {
		update.Progress.Report(phase, detail)
	}
}

func (update *Update) recoveryPointerPath() string {
	return filepath.Join(update.Paths.Root, "recovery-previous.json")
}

func (update *Update) activation(resolved releasecontract.Resolved, bytes []byte, directory string, harnesses, optional []string) releasecontract.Activation {
	return releasecontract.Activation{ManifestBytes: bytes, ManifestURL: resolved.ManifestURL, Manifest: resolved.Manifest, ReleaseDirectory: directory, RuntimeEnvironment: update.RuntimeEnvironment, Harnesses: harnesses, OptionalImages: optional, Channel: update.Current.Channel, ChannelSequence: resolved.ChannelSequence, RevocationSequence: resolved.RevocationSequence, Paths: update.Paths, Fetcher: update.Fetcher, Docker: update.Docker, HealthURL: update.HealthURL, HealthTimeout: update.HealthTimeout}
}

func selectedBytes(manifest contract.Manifest, harnesses, optional []string) (int64, int64, error) {
	download := manifest.ServerFiles.DownloadBytes
	staging := manifest.ServerFiles.DownloadBytes + manifest.ServerFiles.UnpackedBytes
	add := func(value contract.Artifact) {
		download += value.DownloadBytes
		staging += value.DownloadBytes + value.UnpackedBytes
	}
	for _, value := range manifest.Images.Required {
		add(value)
	}
	remaining := make(map[string]struct{}, len(harnesses))
	for _, id := range harnesses {
		remaining[id] = struct{}{}
	}
	for _, group := range manifest.Images.Choices {
		for id := range remaining {
			if value, exists := group.Options[id]; exists {
				add(value)
				delete(remaining, id)
			}
		}
	}
	if len(remaining) != 0 {
		return 0, 0, fmt.Errorf("selected harness is absent from candidate")
	}
	for _, id := range optional {
		_, exists := manifest.Images.Registry.Optional[id]
		if !exists {
			return 0, 0, fmt.Errorf("selected optional image %q is absent from candidate", id)
		}
	}
	return download, staging, nil
}

func availableBytes(path string) (int64, error) {
	if err := os.MkdirAll(path, 0o700); err != nil {
		return 0, err
	}
	var value syscall.Statfs_t
	if err := syscall.Statfs(path, &value); err != nil {
		return 0, err
	}
	return int64(value.Bavail) * int64(value.Bsize), nil
}
