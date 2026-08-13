package release

import (
	"fmt"
	"time"

	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/contract"
)

type Current struct {
	SchemaVersion             int      `json:"schemaVersion"`
	ReleaseDigest             string   `json:"releaseDigest"`
	SourceCommit              string   `json:"sourceCommit"`
	ServerVersion             string   `json:"serverVersion"`
	DataVersion               int      `json:"dataVersion"`
	DeploymentContractVersion int      `json:"deploymentContractVersion"`
	Channel                   string   `json:"channel"`
	ChannelSequence           int64    `json:"channelSequence"`
	RevocationSequence        int64    `json:"revocationSequence"`
	SelectedHarnesses         []string `json:"selectedHarnesses"`
	SelectedOptionalImages    []string `json:"selectedOptionalImages"`
	SelectedImages            []string `json:"selectedImages"`
	ManifestURL               string   `json:"manifestUrl"`
	ActivatedAt               string   `json:"activatedAt"`
}

type MetadataStatus struct {
	SchemaVersion                       int    `json:"schemaVersion"`
	Status                              string `json:"status"`
	CheckedAt                           string `json:"checkedAt"`
	CurrentReleaseDigest                string `json:"currentReleaseDigest"`
	RevokedReleaseDigest                string `json:"revokedReleaseDigest,omitempty"`
	CurrentVersion                      string `json:"currentVersion,omitempty"`
	CurrentDataVersion                  int    `json:"currentDataVersion,omitempty"`
	ReasonCode                          string `json:"reasonCode,omitempty"`
	Summary                             string `json:"summary,omitempty"`
	AvailableReleaseDigest              string `json:"availableReleaseDigest,omitempty"`
	AvailableVersion                    string `json:"availableVersion,omitempty"`
	AvailableDataVersion                int    `json:"availableDataVersion,omitempty"`
	DownloadBytes                       int64  `json:"downloadBytes,omitempty"`
	RequiredDiskBytes                   int64  `json:"requiredDiskBytes,omitempty"`
	NormalRollbackAvailableAfterSuccess *bool  `json:"normalRollbackAvailableAfterSuccess,omitempty"`
}

func BuildMetadataStatus(current Current, resolved Resolved, snapshotBytes, reserveBytes int64, now time.Time) (MetadataStatus, error) {
	status := MetadataStatus{
		SchemaVersion: contract.SchemaVersion, CheckedAt: now.UTC().Format(time.RFC3339),
		CurrentReleaseDigest: current.ReleaseDigest,
	}
	if revoked, exists := resolved.Revocations.RevokedReleases[current.ReleaseDigest]; exists {
		status.Status = "critical-release-warning"
		status.RevokedReleaseDigest = current.ReleaseDigest
		status.CurrentVersion = current.ServerVersion
		status.CurrentDataVersion = current.DataVersion
		status.ReasonCode = revoked.ReasonCode
		status.Summary = revoked.Summary
		return status, nil
	}
	if resolved.Revoked != nil {
		return MetadataStatus{}, fmt.Errorf("channel points to revoked candidate release")
	}
	if resolved.ManifestSHA256 == current.ReleaseDigest {
		status.Status = "current"
		return status, nil
	}
	download, staging, err := selectedArtifactBytes(resolved.Manifest, current.SelectedHarnesses, current.SelectedOptionalImages)
	if err != nil {
		return MetadataStatus{}, err
	}
	rollback := current.DataVersion == resolved.Manifest.DataVersion
	status.Status = "update-available"
	status.CurrentVersion = current.ServerVersion
	status.CurrentDataVersion = current.DataVersion
	status.AvailableReleaseDigest = resolved.ManifestSHA256
	status.AvailableVersion = resolved.Manifest.ServerVersion
	status.AvailableDataVersion = resolved.Manifest.DataVersion
	status.DownloadBytes = download
	status.RequiredDiskBytes = staging + snapshotBytes + reserveBytes
	status.NormalRollbackAvailableAfterSuccess = &rollback
	return status, nil
}

func selectedArtifactBytes(manifest contract.Manifest, harnesses, optional []string) (int64, int64, error) {
	download := manifest.ServerFiles.DownloadBytes
	staging := manifest.ServerFiles.DownloadBytes + manifest.ServerFiles.UnpackedBytes
	add := func(artifact contract.Artifact) {
		download += artifact.DownloadBytes
		staging += artifact.DownloadBytes + artifact.UnpackedBytes
	}
	for _, artifact := range manifest.Images.Required {
		add(artifact)
	}
	selectedHarnesses := stringSet(harnesses)
	for _, group := range manifest.Images.Choices {
		for id := range selectedHarnesses {
			if artifact, exists := group.Options[id]; exists {
				add(artifact)
				delete(selectedHarnesses, id)
			}
		}
	}
	if len(selectedHarnesses) != 0 {
		return 0, 0, fmt.Errorf("selected harness is absent from candidate release")
	}
	for _, id := range optional {
		_, exists := manifest.Images.Registry.Optional[id]
		if !exists {
			return 0, 0, fmt.Errorf("selected optional image %q is absent from candidate release", id)
		}
	}
	return download, staging, nil
}

func stringSet(values []string) map[string]struct{} {
	result := make(map[string]struct{}, len(values))
	for _, value := range values {
		result[value] = struct{}{}
	}
	return result
}
