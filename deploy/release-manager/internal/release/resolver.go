package release

import (
	"crypto/ed25519"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/artifact"
	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/contract"
	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/state"
	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/trust"
)

const (
	maximumDelegationBytes = 256 << 10
	maximumPointerBytes    = 256 << 10
	maximumRevocationBytes = 256 << 10
	maximumEnvelopeBytes   = 16 << 10
	maximumManifestBytes   = 1 << 20
)

type Config struct {
	ReleaseBase         string
	Channel             string
	StableSequenceFloor int64
	State               state.Paths
	RootPublicKey       ed25519.PublicKey
	AllowRevoked        bool
	Fetcher             artifact.Fetcher
	Now                 func() time.Time
}

type Resolved struct {
	SchemaVersion      int                  `json:"schemaVersion"`
	Channel            string               `json:"channel"`
	ChannelSequence    int64                `json:"channelSequence"`
	RevocationSequence int64                `json:"revocationSequence"`
	ManifestSHA256     string               `json:"manifestSha256"`
	ManifestPath       string               `json:"manifestPath"`
	ManifestURL        string               `json:"manifestUrl"`
	Revoked            *contract.Revocation `json:"revoked"`
	Manifest           contract.Manifest    `json:"-"`
	Revocations        contract.Revocations `json:"-"`
}

type Resolver struct{ Config Config }

func (resolver Resolver) Resolve() (Resolved, error) {
	config := resolver.Config
	config.ReleaseBase = strings.TrimRight(config.ReleaseBase, "/")
	if config.ReleaseBase == "" || (config.Channel != "stable" && config.Channel != "beta" && config.Channel != "nightly") {
		return Resolved{}, fmt.Errorf("invalid release resolver configuration")
	}
	sequences, err := state.LoadSequences(config.State.Sequences)
	if err != nil {
		return Resolved{}, err
	}
	verifier := trust.Verifier{RootPublicKey: config.RootPublicKey, Now: config.Now}

	delegationURL := config.ReleaseBase + "/v1/delegations/root.json"
	delegationBytes, err := config.Fetcher.Bounded(delegationURL, maximumDelegationBytes)
	if err != nil {
		return Resolved{}, err
	}
	delegationEnvelopeBytes, err := config.Fetcher.Bounded(delegationURL+".sig", maximumEnvelopeBytes)
	if err != nil {
		return Resolved{}, err
	}
	var delegation contract.RootDelegation
	var delegationEnvelope contract.SignatureEnvelope
	if err := contract.DecodeStrict(delegationBytes, &delegation); err != nil {
		return Resolved{}, err
	}
	if err := contract.DecodeStrict(delegationEnvelopeBytes, &delegationEnvelope); err != nil {
		return Resolved{}, err
	}
	if err := verifier.VerifyRoot(delegationBytes, delegationEnvelope, delegation); err != nil {
		return Resolved{}, err
	}
	if delegation.SchemaVersion != contract.SchemaVersion || delegation.Sequence < 1 {
		return Resolved{}, fmt.Errorf("invalid root delegation")
	}
	if err := sequences.Accept("delegation", delegation.Sequence, 0); err != nil {
		return Resolved{}, err
	}

	pointerURL := config.ReleaseBase + "/v1/channels/" + config.Channel + ".json"
	pointerBytes, err := config.Fetcher.Bounded(pointerURL, maximumPointerBytes)
	if err != nil {
		return Resolved{}, err
	}
	var pointer contract.ChannelPointer
	if err := contract.DecodeStrict(pointerBytes, &pointer); err != nil {
		return Resolved{}, err
	}
	if err := contract.ValidatePointer(pointer, config.Channel, config.ReleaseBase, maximumManifestBytes); err != nil {
		return Resolved{}, err
	}
	pointerEnvelopeBytes, err := config.Fetcher.Bounded(pointer.Signature.URL, maximumEnvelopeBytes)
	if err != nil {
		return Resolved{}, err
	}
	var pointerEnvelope contract.SignatureEnvelope
	if err := contract.DecodeStrict(pointerEnvelopeBytes, &pointerEnvelope); err != nil {
		return Resolved{}, err
	}
	if pointerEnvelope.KeyID != pointer.Signature.KeyID || pointerEnvelope.Algorithm != pointer.Signature.Algorithm {
		return Resolved{}, fmt.Errorf("channel signature descriptor does not match its envelope")
	}
	if err := verifier.VerifyDelegated(pointerBytes, pointerEnvelope, "channel", delegation); err != nil {
		return Resolved{}, err
	}
	floor := int64(0)
	if config.Channel == "stable" {
		floor = config.StableSequenceFloor
	}
	if err := sequences.Accept("channel-"+config.Channel, pointer.Sequence, floor); err != nil {
		return Resolved{}, err
	}

	manifestBytes, err := config.Fetcher.Bounded(pointer.Manifest.URL, maximumManifestBytes)
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
	manifestEnvelopeBytes, err := config.Fetcher.Bounded(pointer.Manifest.Signature.URL, maximumEnvelopeBytes)
	if err != nil {
		return Resolved{}, err
	}
	var manifestEnvelope contract.SignatureEnvelope
	if err := contract.DecodeStrict(manifestEnvelopeBytes, &manifestEnvelope); err != nil {
		return Resolved{}, err
	}
	if manifestEnvelope.KeyID != pointer.Manifest.Signature.KeyID || manifestEnvelope.Algorithm != pointer.Manifest.Signature.Algorithm {
		return Resolved{}, fmt.Errorf("manifest signature descriptor does not match its envelope")
	}
	if err := verifier.VerifyDelegated(manifestBytes, manifestEnvelope, "release", delegation); err != nil {
		return Resolved{}, err
	}
	var manifest contract.Manifest
	if err := contract.DecodeStrict(manifestBytes, &manifest); err != nil {
		return Resolved{}, err
	}
	if err := contract.ValidateManifest(manifest); err != nil {
		return Resolved{}, err
	}

	revocationURL := config.ReleaseBase + "/v1/revocations/releases.json"
	revocationBytes, err := config.Fetcher.Bounded(revocationURL, maximumRevocationBytes)
	if err != nil {
		return Resolved{}, err
	}
	var revocations contract.Revocations
	if err := contract.DecodeStrict(revocationBytes, &revocations); err != nil {
		return Resolved{}, err
	}
	if err := contract.ValidateRevocations(revocations); err != nil {
		return Resolved{}, err
	}
	revocationEnvelopeURL := fmt.Sprintf("%s/v1/revocations/releases/%d.sig", config.ReleaseBase, revocations.Sequence)
	revocationEnvelopeBytes, err := config.Fetcher.Bounded(revocationEnvelopeURL, maximumEnvelopeBytes)
	if err != nil {
		return Resolved{}, err
	}
	var revocationEnvelope contract.SignatureEnvelope
	if err := contract.DecodeStrict(revocationEnvelopeBytes, &revocationEnvelope); err != nil {
		return Resolved{}, err
	}
	if err := verifier.VerifyDelegated(revocationBytes, revocationEnvelope, "revocation", delegation); err != nil {
		return Resolved{}, err
	}
	if err := sequences.Accept("revocation", revocations.Sequence, 0); err != nil {
		return Resolved{}, err
	}

	var revoked *contract.Revocation
	if value, exists := revocations.RevokedReleases[pointer.Manifest.SHA256]; exists {
		copy := value
		revoked = &copy
		if !config.AllowRevoked {
			return Resolved{}, fmt.Errorf("release %s is revoked: %s", pointer.Manifest.SHA256, value.ReasonCode)
		}
	}
	resolvedDirectory := filepath.Join(config.State.Root, "resolved")
	manifestDirectory := filepath.Join(config.State.Root, "manifests")
	manifestPath := filepath.Join(manifestDirectory, pointer.Manifest.SHA256+".json")
	if err := state.WriteAtomic(manifestPath, manifestBytes, 0o644); err != nil {
		return Resolved{}, err
	}
	if err := state.WriteAtomic(filepath.Join(resolvedDirectory, "revocations.json"), revocationBytes, 0o644); err != nil {
		return Resolved{}, err
	}
	sequences["delegation"] = delegation.Sequence
	sequences["channel-"+config.Channel] = pointer.Sequence
	sequences["revocation"] = revocations.Sequence
	if err := state.WriteJSONAtomic(config.State.Sequences, sequences, 0o644); err != nil {
		return Resolved{}, err
	}
	return Resolved{
		SchemaVersion: contract.SchemaVersion, Channel: config.Channel,
		ChannelSequence: pointer.Sequence, RevocationSequence: revocations.Sequence,
		ManifestSHA256: pointer.Manifest.SHA256, ManifestPath: manifestPath,
		ManifestURL: pointer.Manifest.URL, Revoked: revoked, Manifest: manifest,
		Revocations: revocations,
	}, nil
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
