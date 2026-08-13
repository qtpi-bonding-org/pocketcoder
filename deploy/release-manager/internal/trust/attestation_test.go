package trust

import "testing"

func TestGitHubAttestationPolicyRejectsUntrustedPublishers(t *testing.T) {
	tests := []GitHubAttestationPolicy{
		{},
		{Repository: "someone-else/pocketcoder", WorkflowRef: ".github/workflows/release.yml@refs/heads/main"},
		{Repository: "qtpi-bonding-org/pocketcoder", WorkflowRef: "release.yml@refs/heads/main"},
	}
	for _, policy := range tests {
		if err := policy.Validate(); err == nil {
			t.Fatalf("policy %#v unexpectedly validated", policy)
		}
	}
}

func TestGitHubAttestationPolicyBuildsExactWorkflowIdentity(t *testing.T) {
	policy := GitHubAttestationPolicy{
		Repository:  "qtpi-bonding-org/pocketcoder",
		WorkflowRef: ".github/workflows/release-attestation-spike.yml@refs/heads/main",
	}
	if err := policy.Validate(); err != nil {
		t.Fatal(err)
	}
	const want = "https://github.com/qtpi-bonding-org/pocketcoder/.github/workflows/release-attestation-spike.yml@refs/heads/main"
	if got := policy.CertificateSAN(); got != want {
		t.Fatalf("CertificateSAN() = %q, want %q", got, want)
	}
}

func TestAttestationVerifierRejectsMalformedBundleBeforeNetworkTrustLookup(t *testing.T) {
	verifier := AttestationVerifier{Policy: GitHubAttestationPolicy{
		Repository:  "qtpi-bonding-org/pocketcoder",
		WorkflowRef: ".github/workflows/release-attestation-spike.yml@refs/heads/main",
	}}
	if err := verifier.Verify([]byte("fixture"), []byte("not JSON")); err == nil {
		t.Fatal("malformed bundle unexpectedly verified")
	}
}
