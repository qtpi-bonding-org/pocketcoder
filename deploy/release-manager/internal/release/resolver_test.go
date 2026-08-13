package release

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"testing"

	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/artifact"
	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/contract"
	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/state"
)

type verifierFunc func(string, []byte, []byte) error

func (function verifierFunc) Verify(role string, subject, bundle []byte) error {
	return function(role, subject, bundle)
}

type resolverTransport map[string][]byte

func (transport resolverTransport) RoundTrip(request *http.Request) (*http.Response, error) {
	data, ok := transport[request.URL.String()]
	if !ok {
		return nil, fmt.Errorf("unexpected request %s", request.URL)
	}
	return &http.Response{StatusCode: http.StatusOK, Body: io.NopCloser(newBytesReader(data)), Header: make(http.Header), ContentLength: int64(len(data))}, nil
}

type byteReader struct {
	data   []byte
	offset int
}

func newBytesReader(data []byte) *byteReader { return &byteReader{data: data} }
func (reader *byteReader) Read(buffer []byte) (int, error) {
	if reader.offset == len(reader.data) {
		return 0, io.EOF
	}
	n := copy(buffer, reader.data[reader.offset:])
	reader.offset += n
	return n, nil
}

func TestResolverRequiresAttestedPointerManifestAndRevocations(t *testing.T) {
	base := "https://images.example"
	manifest, err := os.ReadFile("../../../release/release-manifest.example.json")
	if err != nil {
		t.Fatal(err)
	}
	digestBytes := sha256.Sum256(manifest)
	digest := hex.EncodeToString(digestBytes[:])
	revocations, _ := json.Marshal(contract.Revocations{SchemaVersion: 1, Sequence: 1, PublishedAt: "2026-08-12T19:00:00Z", RevokedReleases: map[string]contract.Revocation{}})
	pointer := contract.ChannelPointer{SchemaVersion: 1, Channel: "stable", Sequence: 2, PromotedAt: "2026-08-12T20:00:00Z", Attestation: contract.AttestationDescriptor{URL: base + "/v1/attestations/channels/stable/2.sigstore.json"}, Manifest: contract.ManifestReference{URL: base + "/v1/releases/" + digest + ".json", SHA256: digest, DownloadBytes: int64(len(manifest)), Attestation: contract.AttestationDescriptor{URL: base + "/v1/attestations/releases/" + digest + ".sigstore.json"}}}
	pointerBytes, _ := json.Marshal(pointer)
	routes := resolverTransport{base + "/v1/channels/stable.json": pointerBytes, pointer.Attestation.URL: []byte("pointer"), pointer.Manifest.URL: manifest, pointer.Manifest.Attestation.URL: []byte("release"), base + "/v1/revocations/releases.json": revocations, base + "/v1/attestations/revocations/releases/1.sigstore.json": []byte("revoke")}
	called := map[string]int{}
	verifier := verifierFunc(func(role string, subject, bundle []byte) error {
		called[role]++
		if len(subject) == 0 || len(bundle) == 0 {
			return fmt.Errorf("empty attested subject")
		}
		return nil
	})
	paths := state.NewPaths(t.TempDir(), t.TempDir(), t.TempDir(), t.TempDir()+"/current")
	resolver := Resolver{Config: Config{ReleaseBase: base, Channel: "stable", StableSequenceFloor: 1, State: paths, Fetcher: artifact.Fetcher{Client: &http.Client{Transport: routes}}, Verifier: verifier}}
	resolved, err := resolver.Resolve()
	if err != nil {
		t.Fatal(err)
	}
	if resolved.ManifestSHA256 != digest || called["channel"] != 1 || called["release"] != 1 || called["revocation"] != 1 {
		t.Fatalf("unexpected result %#v calls=%#v", resolved, called)
	}
	// The persisted sequence rejects an R2 replay even if the attacker retains an old valid bundle.
	pointer.Sequence = 1
	pointer.Attestation.URL = base + "/v1/attestations/channels/stable/1.sigstore.json"
	pointerBytes, _ = json.Marshal(pointer)
	routes[base+"/v1/channels/stable.json"] = pointerBytes
	routes[pointer.Attestation.URL] = []byte("pointer")
	if _, err := resolver.Resolve(); err == nil {
		t.Fatal("expected replay rejection")
	}
}
