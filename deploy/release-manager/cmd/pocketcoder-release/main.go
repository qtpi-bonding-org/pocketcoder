package main

import (
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/artifact"
	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/contract"
	managercontract "github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/manager"
	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/progress"
	releasecontract "github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/release"
	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/runtime"
	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/snapshot"
	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/state"
	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/trust"
)

var version = "dev"

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, "pocketcoder-release:", err)
		os.Exit(1)
	}
}

func run(args []string) error {
	if len(args) == 0 {
		return usage()
	}
	switch args[0] {
	case "version", "--version":
		fmt.Println(version)
		return nil
	case "status":
		return status(args[1:])
	case "check-metadata":
		return checkMetadata(args[1:])
	case "install", "update":
		return update(args[0], args[1:])
	case "rollback":
		return rollback(args[1:])
	default:
		return usage()
	}
}

type mutationOptions struct {
	stateRoot, artifactRoot, releasesRoot, currentLink string
	releaseBase, channel, runtimeEnvironment           string
	channelExplicit                                    bool
	statusFile, statusRunID                            string
	stableFloor, reserveBytes                          int64
	expectedDigest                                     string
	expectedSequence                                   int64
	harnesses, optional                                []string
}

func mutationFlags(name string, args []string) (mutationOptions, error) {
	flags := flag.NewFlagSet(name, flag.ContinueOnError)
	var result mutationOptions
	flags.StringVar(&result.stateRoot, "state-dir", envOr("POCKETCODER_RELEASE_STATE_DIR", "/var/lib/pocketcoder/release"), "release state directory")
	flags.StringVar(&result.artifactRoot, "artifact-dir", envOr("POCKETCODER_ARTIFACT_DIR", "/var/lib/pocketcoder/artifacts"), "artifact directory")
	flags.StringVar(&result.releasesRoot, "releases-dir", envOr("POCKETCODER_RELEASES_DIR", "/opt/pocketcoder/releases"), "immutable release directory")
	flags.StringVar(&result.currentLink, "current-link", envOr("POCKETCODER_CURRENT_LINK", "/opt/pocketcoder/current"), "active release symlink")
	flags.StringVar(&result.releaseBase, "release-base", envOr("RELEASE_BASE", "https://images.relay.pocketcoder.org"), "release service base URL")
	flags.StringVar(&result.channel, "channel", envOr("POCKETCODER_RELEASE_CHANNEL", "stable"), "release channel")
	flags.StringVar(&result.runtimeEnvironment, "runtime-env", envOr("POCKETCODER_RUNTIME_ENV", "/var/lib/pocketcoder/config/runtime.env"), "runtime environment file")
	flags.StringVar(&result.statusFile, "status-file", envOr("POCKETCODER_STATUS_FILE", ""), "bootstrap status document to continue")
	flags.StringVar(&result.statusRunID, "status-run-id", envOr("POCKETCODER_STATUS_RUN_ID", ""), "bootstrap status run identifier")
	flags.Int64Var(&result.stableFloor, "stable-sequence-floor", envInt64("POCKETCODER_STABLE_SEQUENCE_FLOOR", 1), "stable sequence floor")
	flags.Int64Var(&result.reserveBytes, "reserve-bytes", envInt64("POCKETCODER_DISK_RESERVE_BYTES", 1<<30), "required free-space reserve")
	flags.StringVar(&result.expectedDigest, "expected-digest", envOr("POCKETCODER_RELEASE_DIGEST", ""), "expected immutable release digest")
	flags.Int64Var(&result.expectedSequence, "expected-sequence", envInt64("POCKETCODER_RELEASE_SEQUENCE", 0), "expected channel sequence")
	harnesses := flags.String("harnesses", envOr("POCKETCODER_SELECTED_HARNESSES", ""), "comma-separated harness IDs for first install")
	optional := flags.String("optional-images", envOr("POCKETCODER_OPTIONAL_IMAGES", ""), "comma-separated optional image IDs")
	if err := flags.Parse(args); err != nil {
		return mutationOptions{}, err
	}
	flags.Visit(func(flag *flag.Flag) {
		if flag.Name == "channel" {
			result.channelExplicit = true
		}
	})
	if os.Getenv("POCKETCODER_RELEASE_CHANNEL") != "" {
		result.channelExplicit = true
	}
	result.harnesses = splitList(*harnesses)
	result.optional = splitList(*optional)
	return result, nil
}

func update(operation string, args []string) (returnErr error) {
	options, err := mutationFlags(operation, args)
	if err != nil {
		return err
	}
	reporter := progress.New(
		options.statusFile,
		options.statusRunID,
		envOr("PC_SOURCE_COMMIT", "unknown"),
		envOr("POCKETCODER_SSH_HOST_KEY_TYPE", ""),
		envOr("POCKETCODER_SSH_HOST_KEY_FINGERPRINT", ""),
		os.Stderr,
	)
	reporter.Report("fetching_release", "resolving_release")
	defer func() {
		if returnErr != nil {
			reporter.Fail("release_install_failed")
		}
	}()
	stopHeartbeat := reporter.StartHeartbeat(60 * time.Second)
	defer stopHeartbeat()
	paths := state.NewPaths(options.stateRoot, options.releasesRoot, options.artifactRoot, options.currentLink)
	lock, err := state.AcquireLock(paths.Lock)
	if err != nil {
		return err
	}
	defer lock.Close()
	current, exists, err := loadCurrent(filepath.Join(options.stateRoot, "current.json"))
	if err != nil {
		return err
	}
	if operation == "update" {
		// A deployment's selected channel is part of the activated release
		// record. A later interactive update must retain it: NixOS first boot
		// passes the channel only to `install`, while normal updates have no
		// service environment to re-export it.
		options.channel = selectedChannel(options.channelExplicit, options.channel, current.Channel)
	}
	recovery := newUpdateManager(options, paths, current, releasecontract.Resolved{}, nil, reporter)
	if err := recovery.Transaction().RecoverLocked(); err != nil {
		return fmt.Errorf("recover interrupted release: %w", err)
	}
	current, exists, err = loadCurrent(filepath.Join(options.stateRoot, "current.json"))
	if err != nil {
		return err
	}
	if operation == "install" && exists {
		if options.expectedDigest == "" || options.expectedDigest == current.ReleaseDigest {
			fmt.Printf("PocketCoder install already complete: %s\n", current.ReleaseDigest)
			return nil
		}
		return fmt.Errorf("PocketCoder is already installed at a different release; use update")
	}
	if operation == "update" && !exists {
		return fmt.Errorf("PocketCoder is not installed; use install")
	}
	if !exists {
		if len(options.harnesses) == 0 {
			return fmt.Errorf("first install requires at least one harness")
		}
		current = releasecontract.Current{SchemaVersion: 1, Channel: options.channel, SelectedHarnesses: options.harnesses, SelectedOptionalImages: options.optional}
	}
	resolved, manifestBytes, err := resolveLocked(options, paths, false)
	if err != nil {
		return err
	}
	reporter.SetSourceCommit(resolved.Manifest.SourceCommit)
	if options.expectedDigest != "" && resolved.ManifestSHA256 != options.expectedDigest {
		return fmt.Errorf("resolved release does not match the expected digest")
	}
	if options.expectedSequence > 0 && resolved.ChannelSequence < options.expectedSequence {
		return fmt.Errorf("resolved release is older than the expected channel sequence")
	}
	updateManager := newUpdateManager(options, paths, current, resolved, manifestBytes, reporter)
	if err := updateManager.Transaction().UpdateLocked(updateManager.Previous(), updateManager.Candidate()); err != nil {
		return err
	}
	if err := updateManager.CleanupLocked(); err != nil {
		fmt.Fprintln(os.Stderr, "pocketcoder-release: cleanup warning:", err)
	}
	fmt.Printf("PocketCoder %s complete: %s\n", operation, resolved.ManifestSHA256)
	return nil
}

func rollback(args []string) error {
	options, err := mutationFlags("rollback", args)
	if err != nil {
		return err
	}
	paths := state.NewPaths(options.stateRoot, options.releasesRoot, options.artifactRoot, options.currentLink)
	lock, err := state.AcquireLock(paths.Lock)
	if err != nil {
		return err
	}
	defer lock.Close()
	current, exists, err := loadCurrent(filepath.Join(options.stateRoot, "current.json"))
	if err != nil {
		return err
	}
	if !exists {
		return fmt.Errorf("current release is unavailable")
	}
	recovery := newUpdateManager(options, paths, current, releasecontract.Resolved{}, nil, nil)
	if err := recovery.Transaction().RecoverLocked(); err != nil {
		return fmt.Errorf("recover interrupted release: %w", err)
	}
	current, exists, err = loadCurrent(filepath.Join(options.stateRoot, "current.json"))
	if err != nil {
		return err
	}
	if !exists {
		return fmt.Errorf("current release is unavailable after recovery")
	}
	previous, exists, err := loadCurrent(filepath.Join(options.stateRoot, "previous.json"))
	if err != nil {
		return err
	}
	if !exists {
		return fmt.Errorf("no previous release is available")
	}
	if current.DataVersion != previous.DataVersion {
		return fmt.Errorf("normal rollback is unavailable after a successful data-version change")
	}
	manifestBytes, err := os.ReadFile(filepath.Join(options.stateRoot, "manifests", previous.ReleaseDigest+".json"))
	if err != nil {
		return err
	}
	var manifest contract.Manifest
	if err := contract.DecodeStrict(manifestBytes, &manifest); err != nil {
		return err
	}
	var revocations contract.Revocations
	if data, readErr := os.ReadFile(filepath.Join(options.stateRoot, "resolved", "revocations.json")); readErr == nil {
		if err := contract.DecodeStrict(data, &revocations); err != nil {
			return err
		}
	}
	resolved := releasecontract.Resolved{ManifestSHA256: previous.ReleaseDigest, ManifestURL: previous.ManifestURL, ChannelSequence: previous.ChannelSequence, RevocationSequence: previous.RevocationSequence, Manifest: manifest, Revocations: revocations}
	updateManager := newUpdateManager(options, paths, current, resolved, manifestBytes, nil)
	if err := updateManager.Transaction().UpdateLocked(updateManager.Previous(), updateManager.Candidate()); err != nil {
		return err
	}
	if err := updateManager.CleanupLocked(); err != nil {
		fmt.Fprintln(os.Stderr, "pocketcoder-release: cleanup warning:", err)
	}
	fmt.Printf("PocketCoder rollback complete: %s\n", previous.ReleaseDigest)
	return nil
}

func newUpdateManager(options mutationOptions, paths state.Paths, current releasecontract.Current, resolved releasecontract.Resolved, manifestBytes []byte, progressSink progress.Sink) *managercontract.Update {
	return &managercontract.Update{Resolved: resolved, ManifestBytes: manifestBytes, Current: current, Paths: paths, RuntimeEnvironment: options.runtimeEnvironment, Fetcher: artifact.Fetcher{}, Docker: runtime.Docker{ProjectName: envOr("POCKETCODER_COMPOSE_PROJECT", "pocketcoder"), Stdout: os.Stdout, Stderr: os.Stderr}, Snapshot: snapshot.Manager{StateRoot: options.stateRoot, DataVolume: envOr("POCKETCODER_DATA_VOLUME", "pocketcoder_pb_data"), BackupVolume: envOr("POCKETCODER_BACKUP_VOLUME", "pocketcoder_pb_backups"), Container: envOr("POCKETCODER_POCKETBASE_CONTAINER", "pocketcoder-pocketbase")}, ReserveBytes: options.reserveBytes, UpdaterContract: 1, Progress: progressSink, HealthURL: envOr("POCKETCODER_HEALTH_URL", ""), HealthTimeout: envDuration("POCKETCODER_HEALTH_TIMEOUT", 0)}
}

func resolveLocked(options mutationOptions, paths state.Paths, allowRevoked bool) (releasecontract.Resolved, []byte, error) {
	resolved, resolveErr := (releasecontract.Resolver{Config: releasecontract.Config{ReleaseBase: options.releaseBase, Channel: options.channel, StableSequenceFloor: options.stableFloor, State: paths, AllowRevoked: allowRevoked, Fetcher: artifact.Fetcher{}, Verifier: trust.GitHubVerifier{CachePath: filepath.Join(paths.Root, "sigstore-tuf")}}}).Resolve()
	if resolveErr != nil {
		return releasecontract.Resolved{}, nil, resolveErr
	}
	manifestBytes, err := os.ReadFile(resolved.ManifestPath)
	return resolved, manifestBytes, err
}

func loadCurrent(path string) (releasecontract.Current, bool, error) {
	data, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return releasecontract.Current{}, false, nil
	}
	if err != nil {
		return releasecontract.Current{}, false, err
	}
	var current releasecontract.Current
	if err := contract.DecodeStrict(data, &current); err != nil {
		return releasecontract.Current{}, false, err
	}
	return current, true, nil
}
func splitList(value string) []string {
	result := make([]string, 0)
	for _, item := range strings.Split(value, ",") {
		if item = strings.TrimSpace(item); item != "" {
			result = append(result, item)
		}
	}
	return result
}

func validChannel(value string) bool {
	return value == "stable" || value == "beta" || value == "nightly"
}

func selectedChannel(explicit bool, requested, current string) string {
	if !explicit && validChannel(current) {
		return current
	}
	return requested
}

func checkMetadata(args []string) error {
	flags := flag.NewFlagSet("check-metadata", flag.ContinueOnError)
	stateRoot := flags.String("state-dir", envOr("POCKETCODER_RELEASE_STATE_DIR", "/var/lib/pocketcoder/release"), "release state directory")
	artifactRoot := flags.String("artifact-dir", envOr("POCKETCODER_ARTIFACT_DIR", "/var/lib/pocketcoder/artifacts"), "artifact directory")
	releaseBase := flags.String("release-base", envOr("RELEASE_BASE", "https://images.relay.pocketcoder.org"), "release service base URL")
	channel := flags.String("channel", envOr("POCKETCODER_RELEASE_CHANNEL", "stable"), "release channel")
	stableFloor := flags.Int64("stable-sequence-floor", envInt64("POCKETCODER_STABLE_SEQUENCE_FLOOR", 1), "stable sequence floor")
	reserveBytes := flags.Int64("reserve-bytes", envInt64("POCKETCODER_DISK_RESERVE_BYTES", 1<<30), "required free-space reserve")
	if err := flags.Parse(args); err != nil {
		return err
	}
	channelExplicit := os.Getenv("POCKETCODER_RELEASE_CHANNEL") != ""
	flags.Visit(func(flag *flag.Flag) {
		if flag.Name == "channel" {
			channelExplicit = true
		}
	})
	paths := state.NewPaths(*stateRoot, envOr("POCKETCODER_RELEASES_DIR", "/opt/pocketcoder/releases"), *artifactRoot, envOr("POCKETCODER_CURRENT_LINK", "/opt/pocketcoder/current"))
	lock, err := state.AcquireLock(paths.Lock)
	if err != nil {
		return err
	}
	defer lock.Close()
	currentBytes, err := os.ReadFile(filepath.Join(*stateRoot, "current.json"))
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	if err != nil {
		return err
	}
	var current releasecontract.Current
	if err := contract.DecodeStrict(currentBytes, &current); err != nil {
		return err
	}
	*channel = selectedChannel(channelExplicit, *channel, current.Channel)
	resolved, err := (releasecontract.Resolver{Config: releasecontract.Config{
		ReleaseBase: *releaseBase, Channel: *channel, StableSequenceFloor: *stableFloor,
		State: paths, AllowRevoked: true, Fetcher: artifact.Fetcher{},
		Verifier: trust.GitHubVerifier{CachePath: filepath.Join(paths.Root, "sigstore-tuf")},
	}}).Resolve()
	if err != nil {
		return err
	}
	snapshotBytes := int64(0)
	if current.DataVersion != resolved.Manifest.DataVersion {
		snapshotBytes, err = (snapshot.Manager{DataVolume: envOr("POCKETCODER_DATA_VOLUME", "pocketcoder_pb_data")}).VolumeBytes()
		if err != nil {
			return fmt.Errorf("measure PocketBase data volume: %w", err)
		}
	}
	metadata, err := releasecontract.BuildMetadataStatus(current, resolved, snapshotBytes, *reserveBytes, time.Now())
	if err != nil {
		return err
	}
	return state.WriteJSONAtomic(paths.Metadata, metadata, 0o644)
}

func usage() error {
	return errors.New("usage: pocketcoder-release <install|update|rollback|check-metadata|status|version>")
}

func status(args []string) error {
	flags := flag.NewFlagSet("status", flag.ContinueOnError)
	stateRoot := flags.String("state-dir", envOr("POCKETCODER_RELEASE_STATE_DIR", "/var/lib/pocketcoder/release"), "release state directory")
	if err := flags.Parse(args); err != nil {
		return err
	}
	result := map[string]any{"schemaVersion": 1, "managerVersion": version}
	for key, name := range map[string]string{
		"current": "current.json", "metadata": "metadata-status.json", "transaction": "transaction.json",
	} {
		data, err := os.ReadFile(filepath.Join(*stateRoot, name))
		if errors.Is(err, os.ErrNotExist) {
			continue
		}
		if err != nil {
			return err
		}
		var value any
		if err := json.Unmarshal(data, &value); err != nil {
			return fmt.Errorf("decode %s: %w", name, err)
		}
		result[key] = value
	}
	encoder := json.NewEncoder(os.Stdout)
	encoder.SetIndent("", "  ")
	return encoder.Encode(result)
}

func envOr(name, fallback string) string {
	if value := os.Getenv(name); value != "" {
		return value
	}
	return fallback
}

func envInt64(name string, fallback int64) int64 {
	value := os.Getenv(name)
	if value == "" {
		return fallback
	}
	parsed, err := strconv.ParseInt(value, 10, 64)
	if err != nil {
		return fallback
	}
	return parsed
}

func envDuration(name string, fallback time.Duration) time.Duration {
	value := os.Getenv(name)
	if value == "" {
		return fallback
	}
	parsed, err := time.ParseDuration(value)
	if err != nil {
		return fallback
	}
	return parsed
}
