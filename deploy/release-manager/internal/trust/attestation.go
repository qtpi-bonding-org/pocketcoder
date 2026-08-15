package trust

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"

	"github.com/sigstore/sigstore-go/pkg/bundle"
	"github.com/sigstore/sigstore-go/pkg/root"
	"github.com/sigstore/sigstore-go/pkg/tuf"
	sigverify "github.com/sigstore/sigstore-go/pkg/verify"
)

const (
	GitHubActionsIssuer = "https://token.actions.githubusercontent.com"
	PublicGoodTUF       = "https://tuf-repo-cdn.sigstore.dev"
)

// GitHubAttestationPolicy is the immutable publisher policy for a release
// subject. Repository and workflow are represented by the Fulcio certificate
// SAN, which GitHub Actions derives from the workflow that minted its OIDC
// token.
type GitHubAttestationPolicy struct {
	Repository  string
	WorkflowRef string
}

func (policy GitHubAttestationPolicy) Validate() error {
	if policy.Repository == "" || policy.WorkflowRef == "" {
		return fmt.Errorf("GitHub attestation policy requires repository and workflow ref")
	}
	if policy.Repository != "qtpi-bonding-org/pocketcoder" {
		return fmt.Errorf("unsupported GitHub attestation repository %q", policy.Repository)
	}
	if policy.WorkflowRef[0] != '.' {
		return fmt.Errorf("GitHub workflow ref must be repository-relative")
	}
	return nil
}

func (policy GitHubAttestationPolicy) CertificateSAN() string {
	return "https://github.com/" + policy.Repository + "/" + policy.WorkflowRef
}

// AttestationVerifier verifies a Sigstore bundle emitted by GitHub Actions.
// The embedded Sigstore TUF root is the trust anchor; TUF metadata is cached
// under CachePath so a healthy installed release is never replaced merely
// because the public-good service is momentarily unavailable.
type AttestationVerifier struct {
	Policy    GitHubAttestationPolicy
	CachePath string
}

// SubjectVerifier lets release resolution use a real Sigstore verifier in
// production and a deliberately small fixture verifier in hermetic tests.
// Test fixtures never model a second, weaker production trust path.
type SubjectVerifier interface {
	Verify(role string, subject, bundle []byte) error
}

type GitHubVerifier struct{ CachePath string }

func (verifier GitHubVerifier) Verify(role string, subject, bundleBytes []byte) error {
	branch := os.Getenv("POCKETCODER_GITHUB_WORKFLOW_BRANCH")
	if branch == "" {
		branch = "main"
	}
	if branch != "main" && branch != "staging" {
		return fmt.Errorf("unsupported GitHub workflow branch %q", branch)
	}
	workflow, ok := map[string]string{
		"release":    ".github/workflows/nixos-image.yml@refs/heads/" + branch,
		"channel":    ".github/workflows/release-promotion.yml@refs/heads/" + branch,
		"revocation": ".github/workflows/release-revocation.yml@refs/heads/" + branch,
	}[role]
	if !ok {
		return fmt.Errorf("unsupported GitHub attestation role %q", role)
	}
	return (AttestationVerifier{Policy: GitHubAttestationPolicy{
		Repository: "qtpi-bonding-org/pocketcoder", WorkflowRef: workflow,
	}, CachePath: verifier.CachePath}).Verify(subject, bundleBytes)
}

func (verifier AttestationVerifier) Verify(artifactBytes, bundleBytes []byte) error {
	if err := verifier.Policy.Validate(); err != nil {
		return err
	}
	if len(artifactBytes) == 0 {
		return fmt.Errorf("attested artifact is empty")
	}
	if len(bundleBytes) == 0 {
		return fmt.Errorf("Sigstore bundle is empty")
	}

	var signedBundle bundle.Bundle
	if err := signedBundle.UnmarshalJSON(bundleBytes); err != nil {
		return fmt.Errorf("decode Sigstore bundle: %w", err)
	}

	trustedMaterial, err := verifier.trustedMaterial()
	if err != nil {
		return err
	}
	identity, err := sigverify.NewShortCertificateIdentity(
		GitHubActionsIssuer,
		"",
		verifier.Policy.CertificateSAN(),
		"",
	)
	if err != nil {
		return fmt.Errorf("build GitHub identity policy: %w", err)
	}
	nativeVerifier, err := sigverify.NewVerifier(
		trustedMaterial,
		sigverify.WithSignedCertificateTimestamps(1),
		sigverify.WithObserverTimestamps(1),
		sigverify.WithTransparencyLog(1),
	)
	if err != nil {
		return fmt.Errorf("build Sigstore verifier: %w", err)
	}
	if _, err := nativeVerifier.Verify(
		&signedBundle,
		sigverify.NewPolicy(
			sigverify.WithArtifact(bytes.NewReader(artifactBytes)),
			sigverify.WithCertificateIdentity(identity),
		),
	); err != nil {
		return fmt.Errorf("verify GitHub attestation: %w", err)
	}
	return nil
}

func (verifier AttestationVerifier) trustedMaterial() (root.TrustedMaterialCollection, error) {
	options := tuf.DefaultOptions()
	options.RepositoryBaseURL = PublicGoodTUF
	if verifier.CachePath != "" {
		options.CachePath = filepath.Clean(verifier.CachePath)
	}
	client, err := tuf.New(options)
	if err != nil {
		return nil, fmt.Errorf("initialize Sigstore TUF client: %w", err)
	}
	trustedRootJSON, err := client.GetTarget("trusted_root.json")
	if err != nil {
		return nil, fmt.Errorf("load Sigstore trusted root: %w", err)
	}
	trustedRoot, err := root.NewTrustedRootFromJSON(trustedRootJSON)
	if err != nil {
		return nil, fmt.Errorf("parse Sigstore trusted root: %w", err)
	}
	return root.TrustedMaterialCollection{trustedRoot}, nil
}
