package contract

import (
	"fmt"
	"net/url"
	pathpkg "path"
	"regexp"
	"strings"
	"time"
)

var (
	digestPattern        = regexp.MustCompile(`^[0-9a-f]{64}$`)
	commitPattern        = regexp.MustCompile(`^[0-9a-f]{40}$`)
	registryImagePattern = regexp.MustCompile(`^[a-z0-9][a-z0-9./_-]*(?::[A-Za-z0-9._-]+)?@sha256:[0-9a-f]{64}$`)
	nixosVersionPattern  = regexp.MustCompile(`^[0-9]{2}\.[0-9]{2}$`)
)

func ValidateManifest(manifest Manifest) error {
	if manifest.SchemaVersion != SchemaVersion {
		return fmt.Errorf("unsupported manifest schema version %d", manifest.SchemaVersion)
	}
	if !commitPattern.MatchString(manifest.SourceCommit) {
		return fmt.Errorf("invalid source commit")
	}
	if manifest.Platform.OS != "linux" || manifest.Platform.Architecture != "amd64" {
		return fmt.Errorf("unsupported platform %s/%s", manifest.Platform.OS, manifest.Platform.Architecture)
	}
	if manifest.SourceRepository != "qtpi-bonding-org/pocketcoder" {
		return fmt.Errorf("unsupported source repository")
	}
	if _, err := time.Parse(time.RFC3339, manifest.BuiltAt); err != nil || !strings.HasSuffix(manifest.BuiltAt, "Z") {
		return fmt.Errorf("invalid UTC build time")
	}
	if manifest.Compatibility.App.ContractVersion < 1 || manifest.Compatibility.Server.APIVersion < 1 || manifest.Compatibility.Provisioning.ContractVersion < 1 || manifest.Compatibility.Deployment.ContractVersion < 1 {
		return fmt.Errorf("invalid compatibility versions")
	}
	if !nixosVersionPattern.MatchString(manifest.Compatibility.OS.NixosVersion) {
		return fmt.Errorf("invalid NixOS compatibility version")
	}
	for _, worker := range []string{"image-relay", "push-relay", "oauth-relay"} {
		if manifest.Compatibility.Workers[worker] < 1 {
			return fmt.Errorf("required Worker API version %q is missing", worker)
		}
	}
	if manifest.DataVersion < 1 || manifest.MinimumUpgradeFromDataVersion < 1 || manifest.MinimumUpgradeFromDataVersion > manifest.DataVersion {
		return fmt.Errorf("invalid data-version range")
	}
	if manifest.Compatibility.Deployment.SupportedSourceContractVersions.Minimum > manifest.Compatibility.Deployment.SupportedSourceContractVersions.Maximum {
		return fmt.Errorf("invalid source deployment-contract range")
	}
	if err := validateArtifact("serverFiles", manifest.ServerFiles, false); err != nil {
		return err
	}
	if len(manifest.ServerFiles.Images) != 0 {
		return fmt.Errorf("serverFiles may not declare Docker images")
	}
	if len(manifest.Documents) == 0 || len(manifest.OSImages) == 0 || len(manifest.Images.Required) == 0 || len(manifest.Images.Registry.Required) == 0 {
		return fmt.Errorf("release manifest is missing required content")
	}
	seenImages := make(map[string]string)
	for id, artifact := range manifest.Images.Required {
		if err := validateImageArtifact("required."+id, artifact, seenImages); err != nil {
			return err
		}
	}
	for groupID, group := range manifest.Images.Choices {
		if group.MinimumSelections < 0 || group.MinimumSelections > len(group.Options) {
			return fmt.Errorf("choice group %q has unsatisfiable minimum", groupID)
		}
		if group.MaximumSelections != nil && (*group.MaximumSelections < group.MinimumSelections || *group.MaximumSelections > len(group.Options)) {
			return fmt.Errorf("choice group %q has invalid maximum", groupID)
		}
		for id, artifact := range group.Options {
			if err := validateImageArtifact("choices."+groupID+"."+id, artifact, seenImages); err != nil {
				return err
			}
		}
	}
	seenRegistryImages := make(map[string]string)
	for _, image := range manifest.Images.Registry.Required {
		if err := validateRegistryImage("required", image, seenRegistryImages); err != nil {
			return err
		}
	}
	for id, descriptor := range manifest.Images.Registry.Optional {
		if descriptor.ComposeProfile == "" {
			return fmt.Errorf("optional registry image %q has no Compose profile", id)
		}
		if err := validateRegistryImage("optional."+id, descriptor.Image, seenRegistryImages); err != nil {
			return err
		}
	}
	for id, document := range manifest.Documents {
		if !digestPattern.MatchString(document.SHA256) || document.DownloadBytes < 1 {
			return fmt.Errorf("document %q has invalid identity or size", id)
		}
		if err := validateHTTPS(document.URL); err != nil {
			return fmt.Errorf("document %q: %w", id, err)
		}
		extension := map[string]string{"application/json": ".json", "text/plain": ".txt", "text/x-shellscript": ".sh", "text/x-go": ".go"}[document.MediaType]
		if extension == "" || pathpkg.Base(document.URL) != document.SHA256+extension {
			return fmt.Errorf("document %q is outside its content-addressed path", id)
		}
		if document.MediaType == "application/json" && (document.SchemaVersion == nil || *document.SchemaVersion < 1) {
			return fmt.Errorf("JSON document %q lacks a schema version", id)
		}
	}
	for id, osImage := range manifest.OSImages {
		switch osImage.Delivery.Kind {
		case "artifact":
			if osImage.Delivery.Artifact == nil || len(osImage.Delivery.ProviderImages) != 0 {
				return fmt.Errorf("OS image %q has invalid artifact delivery", id)
			}
			if err := validateArtifact("osImages."+id, *osImage.Delivery.Artifact, false); err != nil {
				return err
			}
		case "provider":
			if osImage.Delivery.Artifact != nil || len(osImage.Delivery.ProviderImages) == 0 {
				return fmt.Errorf("OS image %q has invalid provider delivery", id)
			}
		default:
			return fmt.Errorf("OS image %q has invalid delivery kind", id)
		}
		switch osImage.Bootstrap.Kind {
		case "image-baked":
		case "generated-config":
			if _, exists := manifest.Documents[osImage.Bootstrap.ScriptDocument]; !exists {
				return fmt.Errorf("OS image %q references a missing bootstrap document", id)
			}
			for _, documentID := range osImage.Bootstrap.SupportingDocuments {
				if _, exists := manifest.Documents[documentID]; !exists {
					return fmt.Errorf("OS image %q references a missing supporting document", id)
				}
			}
		default:
			return fmt.Errorf("OS image %q has invalid bootstrap kind", id)
		}
	}
	return nil
}

func validateRegistryImage(name, image string, seen map[string]string) error {
	if !registryImagePattern.MatchString(image) {
		return fmt.Errorf("registry image %q is not pinned by digest", name)
	}
	if previous, exists := seen[image]; exists {
		return fmt.Errorf("registry image %q is duplicated by %s and %s", image, previous, name)
	}
	seen[image] = name
	return nil
}

// ValidatePointer checks a fetched channel pointer against the box's own
// configuration. expectedChannel is the release-maturity value the box was
// installed with ("stable"/"beta"/"nightly") -- it never varies by publish
// branch, so it's what the pointer's own "channel" field is compared
// against. expectedChannelPath is the (possibly branch-qualified, e.g.
// "nightly-staging") path segment the pointer and its attestation were
// actually fetched from -- see resolver.go for how the two diverge.
func ValidatePointer(pointer ChannelPointer, expectedChannel, expectedChannelPath, releaseBase string, maximumManifestBytes int64) error {
	if pointer.SchemaVersion != SchemaVersion || pointer.Channel != expectedChannel || pointer.Sequence < 1 {
		return fmt.Errorf("invalid channel pointer")
	}
	if err := validateAttestationDescriptor(pointer.Attestation); err != nil {
		return fmt.Errorf("channel attestation: %w", err)
	}
	if err := validateAttestationDescriptor(pointer.Manifest.Attestation); err != nil {
		return fmt.Errorf("manifest attestation: %w", err)
	}
	if pointer.Manifest.DownloadBytes < 1 || pointer.Manifest.DownloadBytes > maximumManifestBytes || !digestPattern.MatchString(pointer.Manifest.SHA256) {
		return fmt.Errorf("invalid manifest identity or size")
	}
	expectedManifest := strings.TrimRight(releaseBase, "/") + "/v1/releases/" + pointer.Manifest.SHA256 + ".json"
	if pointer.Manifest.URL != expectedManifest {
		return fmt.Errorf("manifest URL is outside its content-addressed path")
	}
	base := strings.TrimRight(releaseBase, "/")
	if pointer.Attestation.URL != base+"/v1/attestations/channels/"+expectedChannelPath+"/"+fmt.Sprint(pointer.Sequence)+".sigstore.json" {
		return fmt.Errorf("channel attestation URL is outside its sequenced path")
	}
	if pointer.Manifest.Attestation.URL != base+"/v1/attestations/releases/"+pointer.Manifest.SHA256+".sigstore.json" {
		return fmt.Errorf("manifest attestation URL is outside its content-addressed path")
	}
	if _, err := time.Parse(time.RFC3339, pointer.PromotedAt); err != nil {
		return fmt.Errorf("invalid promotion time: %w", err)
	}
	return nil
}

func validateImageArtifact(name string, artifact Artifact, seen map[string]string) error {
	if err := validateArtifact(name, artifact, true); err != nil {
		return err
	}
	for _, image := range artifact.Images {
		if previous, exists := seen[image]; exists {
			return fmt.Errorf("image %q is duplicated by %s and %s", image, previous, name)
		}
		seen[image] = name
	}
	return nil
}

func validateArtifact(name string, artifact Artifact, requireImages bool) error {
	if !digestPattern.MatchString(artifact.SHA256) || artifact.DownloadBytes < 1 || artifact.UnpackedBytes < artifact.DownloadBytes {
		return fmt.Errorf("artifact %q has invalid identity or sizes", name)
	}
	if requireImages && len(artifact.Images) == 0 {
		return fmt.Errorf("artifact %q has no image inventory", name)
	}
	if err := validateHTTPS(artifact.URL); err != nil {
		return fmt.Errorf("artifact %q: %w", name, err)
	}
	base := pathpkg.Base(artifact.URL)
	if base != artifact.SHA256+".tar.gz" && base != artifact.SHA256+".img.gz" {
		return fmt.Errorf("artifact %q is outside its content-addressed path", name)
	}
	return nil
}

func ValidateRevocations(revocations Revocations) error {
	if revocations.SchemaVersion != SchemaVersion || revocations.Sequence < 1 {
		return fmt.Errorf("invalid release revocations")
	}
	if _, err := time.Parse(time.RFC3339, revocations.PublishedAt); err != nil || !strings.HasSuffix(revocations.PublishedAt, "Z") {
		return fmt.Errorf("invalid UTC revocation publication time")
	}
	for digest, value := range revocations.RevokedReleases {
		if !digestPattern.MatchString(digest) || value.ReasonCode == "" || len(value.ReasonCode) > 64 || value.Summary == "" || len(value.Summary) > 240 {
			return fmt.Errorf("invalid revocation for %q", digest)
		}
		if _, err := time.Parse(time.RFC3339, value.RevokedAt); err != nil || !strings.HasSuffix(value.RevokedAt, "Z") {
			return fmt.Errorf("invalid UTC revocation time for %q", digest)
		}
	}
	return nil
}

func validateAttestationDescriptor(descriptor AttestationDescriptor) error {
	return validateHTTPS(descriptor.URL)
}

func validateHTTPS(raw string) error {
	parsed, err := url.Parse(raw)
	if err != nil || parsed.Scheme != "https" || parsed.Host == "" {
		return fmt.Errorf("URL must be absolute HTTPS with a host")
	}
	return nil
}
