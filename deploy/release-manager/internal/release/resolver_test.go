package release

import (
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"testing"
	"time"

	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/artifact"
	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/contract"
	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/state"
)

type resolverTransport map[string][]byte

func (transport resolverTransport) RoundTrip(request *http.Request) (*http.Response, error) {
	data, exists := transport[request.URL.String()]
	if !exists {
		return nil, fmt.Errorf("unexpected request %s", request.URL)
	}
	return &http.Response{
		StatusCode:    http.StatusOK,
		Body:          io.NopCloser(newBytesReader(data)),
		Header:        make(http.Header),
		ContentLength: int64(len(data)),
	}, nil
}

type resolverFixture struct {
	base       string
	routes     resolverTransport
	rootPublic ed25519.PublicKey
	operations ed25519.PrivateKey
	manifest   []byte
	digest     string
}

func TestResolverVerifiesCompleteChainAndRejectsReplay(t *testing.T) {
	fixture := newResolverFixture(t)
	fixture.setPointer(t, 2)
	paths := state.NewPaths(t.TempDir(), t.TempDir(), t.TempDir(), t.TempDir()+"/current")
	resolver := Resolver{Config: Config{
		ReleaseBase: fixture.base, Channel: "stable", StableSequenceFloor: 1,
		State: paths, RootPublicKey: fixture.rootPublic,
		Fetcher: artifact.Fetcher{Client: &http.Client{Transport: fixture.routes}},
		Now:     func() time.Time { return time.Date(2026, 8, 12, 20, 0, 0, 0, time.UTC) },
	}}
	resolved, err := resolver.Resolve()
	if err != nil {
		t.Fatal(err)
	}
	if resolved.ManifestSHA256 != fixture.digest || resolved.ChannelSequence != 2 {
		t.Fatalf("resolved = %#v", resolved)
	}
	if _, err := os.Stat(resolved.ManifestPath); err != nil {
		t.Fatalf("persisted manifest: %v", err)
	}

	fixture.setPointer(t, 1)
	if _, err := resolver.Resolve(); err == nil {
		t.Fatal("expected channel replay rejection")
	}
}

func newResolverFixture(t *testing.T) *resolverFixture {
	t.Helper()
	rootPublic, rootPrivate, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	operationsPublic, operationsPrivate, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	operationsDER, err := x509.MarshalPKIXPublicKey(operationsPublic)
	if err != nil {
		t.Fatal(err)
	}
	fixture := &resolverFixture{
		base: "https://images.example", routes: resolverTransport{},
		rootPublic: rootPublic, operations: operationsPrivate,
	}
	delegatedKey := contract.DelegatedKey{
		KeyID: "operations", Algorithm: "ed25519",
		PublicKey: base64.StdEncoding.EncodeToString(operationsDER),
		ValidFrom: "2026-01-01T00:00:00Z",
	}
	delegation := contract.RootDelegation{
		SchemaVersion: 1, Sequence: 1, IssuedAt: "2026-08-12T19:00:00Z",
		RootKeyID: "root", RevokedKeyIDs: []string{},
		Roles: map[string][]contract.DelegatedKey{
			"release": {delegatedKey}, "channel": {delegatedKey},
			"metadata": {delegatedKey}, "revocation": {delegatedKey},
		},
	}
	delegationBytes := mustJSON(t, delegation)
	fixture.routes[fixture.base+"/v1/delegations/root.json"] = delegationBytes
	fixture.routes[fixture.base+"/v1/delegations/root.json.sig"] = mustJSON(t, signEnvelope(delegationBytes, "root", "root", rootPrivate))

	manifestBytes, err := os.ReadFile("../../../release/release-manifest.example.json")
	if err != nil {
		t.Fatal(err)
	}
	var manifest contract.Manifest
	if err := contract.DecodeStrict(manifestBytes, &manifest); err != nil {
		t.Fatal(err)
	}
	if err := contract.ValidateManifest(manifest); err != nil {
		t.Fatal(err)
	}
	manifestDigest := sha256.Sum256(manifestBytes)
	fixture.manifest = manifestBytes
	fixture.digest = hex.EncodeToString(manifestDigest[:])
	manifestURL := fixture.base + "/v1/releases/" + fixture.digest + ".json"
	fixture.routes[manifestURL] = manifestBytes
	fixture.routes[manifestURL+".sig"] = mustJSON(t, signEnvelope(manifestBytes, "release", "operations", operationsPrivate))

	revocations := mustJSON(t, contract.Revocations{
		SchemaVersion: 1, Sequence: 1, PublishedAt: "2026-08-12T19:00:00Z",
		RevokedReleases: map[string]contract.Revocation{},
	})
	fixture.routes[fixture.base+"/v1/revocations/releases.json"] = revocations
	fixture.routes[fixture.base+"/v1/revocations/releases/1.sig"] = mustJSON(t, signEnvelope(revocations, "revocation", "operations", operationsPrivate))
	return fixture
}

func (fixture *resolverFixture) setPointer(t *testing.T, sequence int64) {
	t.Helper()
	manifestURL := fixture.base + "/v1/releases/" + fixture.digest + ".json"
	pointer := contract.ChannelPointer{
		SchemaVersion: 1, Channel: "stable", Sequence: sequence,
		PromotedAt: "2026-08-12T19:00:00Z",
		Manifest: contract.ManifestReference{
			URL: manifestURL, SHA256: fixture.digest, DownloadBytes: int64(len(fixture.manifest)),
			Signature: contract.SignatureDescriptor{Algorithm: "ed25519", KeyID: "operations", URL: manifestURL + ".sig"},
		},
		Signature: contract.SignatureDescriptor{
			Algorithm: "ed25519", KeyID: "operations",
			URL: fmt.Sprintf("%s/v1/channels/stable/%d.sig", fixture.base, sequence),
		},
	}
	pointerBytes := mustJSON(t, pointer)
	fixture.routes[fixture.base+"/v1/channels/stable.json"] = pointerBytes
	fixture.routes[pointer.Signature.URL] = mustJSON(t, signEnvelope(pointerBytes, "channel", "operations", fixture.operations))
}

func signEnvelope(payload []byte, role, keyID string, privateKey ed25519.PrivateKey) contract.SignatureEnvelope {
	digest := sha256.Sum256(payload)
	return contract.SignatureEnvelope{
		SchemaVersion: 1, Algorithm: "ed25519", Role: role, KeyID: keyID,
		PayloadSHA256: hex.EncodeToString(digest[:]),
		Signature:     base64.StdEncoding.EncodeToString(ed25519.Sign(privateKey, payload)),
	}
}

func mustJSON(t *testing.T, value any) []byte {
	t.Helper()
	data, err := json.Marshal(value)
	if err != nil {
		t.Fatal(err)
	}
	return data
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
	count := copy(buffer, reader.data[reader.offset:])
	reader.offset += count
	return count, nil
}
