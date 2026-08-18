package release

import (
	"testing"
	"time"

	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/contract"
)

func TestBuildMetadataStatusUsesSelectedArtifacts(t *testing.T) {
	manifest := contract.Manifest{
		ServerVersion: "2.0.0", DataVersion: 2,
		ServerFiles: contract.Artifact{DownloadBytes: 10, UnpackedBytes: 20},
		Images: contract.Images{
			Required: map[string]contract.Artifact{"server": {DownloadBytes: 30, UnpackedBytes: 40}},
			Choices: map[string]contract.ChoiceGroup{"coding": {Options: map[string]contract.Artifact{
				"goose": {DownloadBytes: 50, UnpackedBytes: 60},
				"codex": {DownloadBytes: 500, UnpackedBytes: 600},
			}}},
			Registry: contract.RegistryImages{Optional: map[string]contract.OptionalRegistryImage{
				"ollama": {Image: "ollama@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},
			}},
		},
	}
	resolved := Resolved{ManifestSHA256: "new", Manifest: manifest}
	current := Current{ReleaseDigest: "old", ServerVersion: "1.0.0", DataVersion: 1, SelectedHarnesses: []string{"goose"}, SelectedOptionalImages: []string{"ollama"}}
	status, err := BuildMetadataStatus(current, resolved, 100, 1000, "", time.Unix(0, 0))
	if err != nil {
		t.Fatal(err)
	}
	if status.DownloadBytes != 90 {
		t.Fatalf("download bytes = %d", status.DownloadBytes)
	}
	if status.RequiredDiskBytes != 1310 {
		t.Fatalf("required disk bytes = %d", status.RequiredDiskBytes)
	}
	if status.NormalRollbackAvailableAfterSuccess == nil || *status.NormalRollbackAvailableAfterSuccess {
		t.Fatal("expected cross-data-version rollback warning")
	}
}

func TestBuildMetadataStatusFindsRevokedCurrentAfterChannelMoves(t *testing.T) {
	resolved := Resolved{
		ManifestSHA256: "replacement",
		Revocations: contract.Revocations{RevokedReleases: map[string]contract.Revocation{
			"current": {ReasonCode: "security", Summary: "Replace this release."},
		}},
	}
	current := Current{ReleaseDigest: "current", ServerVersion: "1.0.0", DataVersion: 1}
	status, err := BuildMetadataStatus(current, resolved, 0, 0, "", time.Unix(0, 0))
	if err != nil {
		t.Fatal(err)
	}
	if status.Status != "critical-release-warning" || status.RevokedReleaseDigest != "current" {
		t.Fatalf("status = %#v", status)
	}
}

func TestBuildMetadataStatusFlagsNixosVersionMismatch(t *testing.T) {
	manifest := contract.Manifest{
		ServerVersion: "1.0.0", DataVersion: 1,
		Compatibility: contract.Compatibility{OS: contract.OSCompatibility{NixosVersion: "26.11"}},
	}
	resolved := Resolved{ManifestSHA256: "current", Manifest: manifest}
	current := Current{ReleaseDigest: "current", ServerVersion: "1.0.0", DataVersion: 1}

	status, err := BuildMetadataStatus(current, resolved, 0, 0, "26.05", time.Unix(0, 0))
	if err != nil {
		t.Fatal(err)
	}
	if status.HostNixosVersion != "26.05" || status.AvailableNixosVersion != "26.11" {
		t.Fatalf("expected mismatch to be flagged, got %#v", status)
	}
}

func TestBuildMetadataStatusOmitsNixosFieldsWhenVersionsMatchOrUnknown(t *testing.T) {
	manifest := contract.Manifest{
		ServerVersion: "1.0.0", DataVersion: 1,
		Compatibility: contract.Compatibility{OS: contract.OSCompatibility{NixosVersion: "26.05"}},
	}
	resolved := Resolved{ManifestSHA256: "current", Manifest: manifest}
	current := Current{ReleaseDigest: "current", ServerVersion: "1.0.0", DataVersion: 1}

	matching, err := BuildMetadataStatus(current, resolved, 0, 0, "26.05", time.Unix(0, 0))
	if err != nil {
		t.Fatal(err)
	}
	if matching.HostNixosVersion != "" || matching.AvailableNixosVersion != "" {
		t.Fatalf("expected no mismatch fields when versions match, got %#v", matching)
	}

	unknownHost, err := BuildMetadataStatus(current, resolved, 0, 0, "", time.Unix(0, 0))
	if err != nil {
		t.Fatal(err)
	}
	if unknownHost.HostNixosVersion != "" || unknownHost.AvailableNixosVersion != "" {
		t.Fatalf("expected no mismatch fields when host version is unknown, got %#v", unknownHost)
	}
}

func TestBuildMetadataStatusRejectsRevokedCandidate(t *testing.T) {
	resolved := Resolved{
		ManifestSHA256: "candidate",
		Revoked:        &contract.Revocation{ReasonCode: "bad-release"},
		Revocations:    contract.Revocations{RevokedReleases: map[string]contract.Revocation{}},
	}
	_, err := BuildMetadataStatus(Current{ReleaseDigest: "current"}, resolved, 0, 0, "", time.Unix(0, 0))
	if err == nil {
		t.Fatal("expected revoked candidate rejection")
	}
}
