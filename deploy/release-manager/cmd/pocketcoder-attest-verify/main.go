// pocketcoder-attest-verify is a deliberately tiny first-boot verifier. The
// image installer uses it before writing a NixOS image, and the release
// manager reuses the same policy for later release subjects.
package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/trust"
)

func main() {
	var artifactPath string
	var bundlePath string
	var workflowRef string
	var cachePath string
	flag.StringVar(&artifactPath, "artifact", "", "artifact bytes to verify")
	flag.StringVar(&bundlePath, "bundle", "", "GitHub Actions Sigstore bundle")
	flag.StringVar(&workflowRef, "workflow-ref", "", "exact repository-relative GitHub workflow ref")
	flag.StringVar(&cachePath, "tuf-cache", "/var/lib/pocketcoder/sigstore-tuf", "Sigstore TUF cache directory")
	flag.Parse()
	if artifactPath == "" || bundlePath == "" || workflowRef == "" {
		fmt.Fprintln(os.Stderr, "usage: pocketcoder-attest-verify --artifact FILE --bundle FILE --workflow-ref .github/workflows/file.yml@refs/heads/main")
		os.Exit(2)
	}
	artifactBytes, err := os.ReadFile(artifactPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "read artifact: %v\n", err)
		os.Exit(1)
	}
	bundleBytes, err := os.ReadFile(bundlePath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "read bundle: %v\n", err)
		os.Exit(1)
	}
	verifier := trust.AttestationVerifier{
		Policy: trust.GitHubAttestationPolicy{
			Repository:  "qtpi-bonding-org/pocketcoder",
			WorkflowRef: workflowRef,
		},
		CachePath: cachePath,
	}
	if err := verifier.Verify(artifactBytes, bundleBytes); err != nil {
		fmt.Fprintf(os.Stderr, "GitHub attestation rejected: %v\n", err)
		os.Exit(1)
	}
	fmt.Println("GitHub attestation verified")
}
