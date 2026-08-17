package release

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/artifact"
	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/contract"
	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/state"
	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/trust"
)

const (
	maximumPointerBytes    = 256 << 10
	maximumRevocationBytes = 256 << 10
	maximumManifestBytes   = 1 << 20
)

type Config struct {
	ReleaseBase         string
	Channel             string
	StableSequenceFloor int64
	State               state.Paths
	AllowRevoked        bool
	Fetcher             artifact.Fetcher
	Verifier            trust.SubjectVerifier
}

type Resolved struct {
	SchemaVersion      int                   `json:"schemaVersion"`
	Channel            string                `json:"channel"`
	ChannelSequence    int64                 `json:"channelSequence"`
	RevocationSequence int64                 `json:"revocationSequence"`
	ManifestSHA256     string                `json:"manifestSha256"`
	ManifestPath       string                `json:"manifestPath"`
	ManifestURL        string                `json:"manifestUrl"`
	Revoked            *contract.Revocation  `json:"revoked"`
	Manifest           contract.Manifest     `json:"-"`
	Revocations        contract.Revocations  `json:"-"`
	ReleaseBundle      []byte                `json:"-"`
	Verifier           trust.SubjectVerifier `json:"-"`
}

type Resolver struct{ Config Config }

// ChannelPath returns the release-maturity value's object-path segment,
// qualified with a "-testing" suffix whenever
// POCKETCODER_GITHUB_WORKFLOW_BRANCH is anything other than main. This is
// what keeps parallel branch pipelines from ever sharing a channel-pointer
// object: main's "nightly" stays the bare "nightly.json" it always was,
// while every other branch (today, only "staging" -- see
// GitHubVerifier.Verify's branch allowlist) gets its own
// "nightly-testing.json" that a main-trust box never even requests. A fixed
// "-testing" suffix (purpose-named, not the literal branch name) keeps the
// public path meaningful even if the non-main trust branch is ever renamed.
// Confirmed live: repeated staging-branch promotions onto the shared,
// unqualified "nightly.json" broke bootstrap for any ordinary main-trust
// box, since the attestation check alone has no way to reject a pointer
// object it was never meant to receive in the first place -- the fix has
// to be in the path, not just the trust check.
func ChannelPath(channel string) string {
	branch := os.Getenv("POCKETCODER_GITHUB_WORKFLOW_BRANCH")
	if branch == "" || branch == "main" {
		return channel
	}
	return channel + "-testing"
}

func (resolver Resolver) Resolve() (Resolved, error) {
	c := resolver.Config
	c.ReleaseBase = strings.TrimRight(c.ReleaseBase, "/")
	if c.ReleaseBase == "" || (c.Channel != "stable" && c.Channel != "beta" && c.Channel != "nightly") || c.Verifier == nil {
		return Resolved{}, fmt.Errorf("invalid release resolver configuration")
	}
	sequences, err := state.LoadSequences(c.State.Sequences)
	if err != nil {
		return Resolved{}, err
	}

	channelPath := ChannelPath(c.Channel)
	pointerURL := c.ReleaseBase + "/v1/channels/" + channelPath + ".json"
	pointerBytes, err := c.Fetcher.Bounded(pointerURL, maximumPointerBytes)
	if err != nil {
		return Resolved{}, err
	}
	var pointer contract.ChannelPointer
	if err := contract.DecodeForward(pointerBytes, &pointer); err != nil {
		return Resolved{}, err
	}
	if err := contract.ValidatePointer(pointer, c.Channel, channelPath, c.ReleaseBase, maximumManifestBytes); err != nil {
		return Resolved{}, err
	}
	pointerBundle, err := c.Fetcher.Bounded(pointer.Attestation.URL, 16<<20)
	if err != nil {
		return Resolved{}, err
	}
	if err := c.Verifier.Verify("channel", pointerBytes, pointerBundle); err != nil {
		return Resolved{}, err
	}
	floor := int64(0)
	if c.Channel == "stable" {
		floor = c.StableSequenceFloor
	}
	if err := sequences.Accept("channel-"+c.Channel, pointer.Sequence, floor); err != nil {
		return Resolved{}, err
	}

	manifestBytes, err := c.Fetcher.Bounded(pointer.Manifest.URL, maximumManifestBytes)
	if err != nil {
		return Resolved{}, err
	}
	if int64(len(manifestBytes)) != pointer.Manifest.DownloadBytes {
		return Resolved{}, fmt.Errorf("manifest size mismatch")
	}
	digest := sha256.Sum256(manifestBytes)
	if hex.EncodeToString(digest[:]) != pointer.Manifest.SHA256 {
		return Resolved{}, fmt.Errorf("manifest digest mismatch")
	}
	releaseBundle, err := c.Fetcher.Bounded(pointer.Manifest.Attestation.URL, 16<<20)
	if err != nil {
		return Resolved{}, err
	}
	if err := c.Verifier.Verify("release", manifestBytes, releaseBundle); err != nil {
		return Resolved{}, err
	}
	var manifest contract.Manifest
	if err := contract.DecodeForward(manifestBytes, &manifest); err != nil {
		return Resolved{}, err
	}
	if err := contract.ValidateManifest(manifest); err != nil {
		return Resolved{}, err
	}

	revocationURL := c.ReleaseBase + "/v1/revocations/releases.json"
	revocationBytes, err := c.Fetcher.Bounded(revocationURL, maximumRevocationBytes)
	if err != nil {
		return Resolved{}, err
	}
	var revocations contract.Revocations
	if err := contract.DecodeForward(revocationBytes, &revocations); err != nil {
		return Resolved{}, err
	}
	if err := contract.ValidateRevocations(revocations); err != nil {
		return Resolved{}, err
	}
	revocationBundleURL := fmt.Sprintf("%s/v1/attestations/revocations/releases/%d.sigstore.json", c.ReleaseBase, revocations.Sequence)
	revocationBundle, err := c.Fetcher.Bounded(revocationBundleURL, 16<<20)
	if err != nil {
		return Resolved{}, err
	}
	if err := c.Verifier.Verify("revocation", revocationBytes, revocationBundle); err != nil {
		return Resolved{}, err
	}
	if err := sequences.Accept("revocation", revocations.Sequence, 0); err != nil {
		return Resolved{}, err
	}

	var revoked *contract.Revocation
	if value, ok := revocations.RevokedReleases[pointer.Manifest.SHA256]; ok {
		copy := value
		revoked = &copy
		if !c.AllowRevoked {
			return Resolved{}, fmt.Errorf("release %s is revoked: %s", pointer.Manifest.SHA256, value.ReasonCode)
		}
	}
	manifestPath := filepath.Join(c.State.Root, "manifests", pointer.Manifest.SHA256+".json")
	if err := state.WriteAtomic(manifestPath, manifestBytes, 0o644); err != nil {
		return Resolved{}, err
	}
	if err := state.WriteAtomic(BundlePath(c.State.Root, pointer.Manifest.SHA256), releaseBundle, 0o644); err != nil {
		return Resolved{}, err
	}
	if err := state.WriteAtomic(filepath.Join(c.State.Root, "resolved", "revocations.json"), revocationBytes, 0o644); err != nil {
		return Resolved{}, err
	}
	sequences["channel-"+c.Channel] = pointer.Sequence
	sequences["revocation"] = revocations.Sequence
	if err := state.WriteJSONAtomic(c.State.Sequences, sequences, 0o644); err != nil {
		return Resolved{}, err
	}
	return Resolved{SchemaVersion: contract.SchemaVersion, Channel: c.Channel, ChannelSequence: pointer.Sequence, RevocationSequence: revocations.Sequence, ManifestSHA256: pointer.Manifest.SHA256, ManifestPath: manifestPath, ManifestURL: pointer.Manifest.URL, Revoked: revoked, Manifest: manifest, Revocations: revocations, ReleaseBundle: releaseBundle, Verifier: c.Verifier}, nil
}

// BundlePath returns where a resolved release's attestation bundle is
// persisted, keyed by manifest digest so an offline rollback can find and
// re-verify the exact bundle that verified this release when it was first
// installed, without a network round-trip.
func BundlePath(root, digest string) string {
	return filepath.Join(root, "manifests", digest+".attestation")
}

// LoadBundle reads back a bundle previously persisted by Resolve().
func LoadBundle(root, digest string) ([]byte, error) {
	return os.ReadFile(BundlePath(root, digest))
}

func ReadCurrent(path string) (map[string]any, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var current map[string]any
	if err := json.Unmarshal(data, &current); err != nil {
		return nil, err
	}
	return current, nil
}
