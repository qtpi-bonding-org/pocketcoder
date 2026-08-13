package main

import (
	"archive/tar"
	"bytes"
	"compress/gzip"
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"

	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/contract"
)

func TestSyntheticReleaseAInstallsBAndRollsBack(t *testing.T) {
	rootPublic, rootPrivate, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	operationsPublic, operationsPrivate, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}

	serverFilesA := testServerFiles(t, "1.0.0", 1, testCommit('a'))
	serverFilesB := testServerFiles(t, "1.1.0", 1, testCommit('b'))
	imageArchive := testGzip(t, []byte("synthetic Docker image archive"))
	document := []byte("synthetic release document")

	var (
		mu     sync.RWMutex
		routes = map[string][]byte{}
	)
	server := httptest.NewTLSServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		mu.RLock()
		body, exists := routes[request.URL.Path]
		mu.RUnlock()
		if !exists {
			http.NotFound(writer, request)
			return
		}
		writer.Header().Set("Content-Length", fmt.Sprint(len(body)))
		writer.WriteHeader(http.StatusOK)
		_, _ = writer.Write(body)
	}))
	defer server.Close()
	healthServer := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, _ *http.Request) {
		writer.WriteHeader(http.StatusOK)
	}))
	defer healthServer.Close()

	chain := newTestChain(t, server.URL, rootPrivate, operationsPublic, operationsPrivate)
	chain.addRelease(t, "a", 1, "1.0.0", testCommit('a'), serverFilesA, imageArchive, document)
	chain.addRelease(t, "b", 2, "1.1.0", testCommit('b'), serverFilesB, imageArchive, document)
	chain.selectRelease("a")
	routes = chain.routes

	rootDER, err := x509.MarshalPKIXPublicKey(rootPublic)
	if err != nil {
		t.Fatal(err)
	}
	rootPath := filepath.Join(t.TempDir(), "root.pem")
	if err := os.WriteFile(rootPath, pem.EncodeToMemory(&pem.Block{Type: "PUBLIC KEY", Bytes: rootDER}), 0o600); err != nil {
		t.Fatal(err)
	}

	root := t.TempDir()
	stateRoot := filepath.Join(root, "state")
	artifactRoot := filepath.Join(root, "artifacts")
	releasesRoot := filepath.Join(root, "releases")
	currentLink := filepath.Join(root, "current")
	runtimeEnvironment := filepath.Join(root, "runtime.env")
	if err := os.WriteFile(runtimeEnvironment, []byte("POCKETCODER_TEST=true\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	installFakeDocker(t, root)

	previousClient := http.DefaultClient
	http.DefaultClient = server.Client()
	t.Cleanup(func() { http.DefaultClient = previousClient })
	t.Setenv("POCKETCODER_RELEASE_STATE_DIR", stateRoot)
	t.Setenv("POCKETCODER_ARTIFACT_DIR", artifactRoot)
	t.Setenv("POCKETCODER_RELEASES_DIR", releasesRoot)
	t.Setenv("POCKETCODER_CURRENT_LINK", currentLink)
	t.Setenv("POCKETCODER_RUNTIME_ENV", runtimeEnvironment)
	t.Setenv("POCKETCODER_ROOT_PUBLIC_KEY", rootPath)
	t.Setenv("POCKETCODER_SELECTED_HARNESSES", "goose")
	t.Setenv("POCKETCODER_DISK_RESERVE_BYTES", "0")
	t.Setenv("POCKETCODER_HEALTH_URL", healthServer.URL)
	t.Setenv("RELEASE_BASE", server.URL)

	if err := run([]string{"install"}); err != nil {
		t.Fatalf("install A: %v", err)
	}
	assertCurrentDigest(t, stateRoot, chain.releases["a"].digest)
	if err := run([]string{"install"}); err != nil {
		t.Fatalf("repeated install was not idempotent: %v", err)
	}

	mu.Lock()
	chain.selectRelease("b")
	routes = chain.routes
	mu.Unlock()
	if err := run([]string{"update"}); err != nil {
		t.Fatalf("A updater installing B: %v", err)
	}
	assertCurrentDigest(t, stateRoot, chain.releases["b"].digest)
	if err := run([]string{"update"}); err != nil {
		t.Fatalf("repeated B update was not idempotent: %v", err)
	}

	if err := run([]string{"rollback"}); err != nil {
		t.Fatalf("same-data rollback to A: %v", err)
	}
	assertCurrentDigest(t, stateRoot, chain.releases["a"].digest)
	if target, err := os.Readlink(currentLink); err != nil || target != filepath.Join(releasesRoot, chain.releases["a"].digest) {
		t.Fatalf("current link = %q, %v", target, err)
	}
}

type testRelease struct {
	digest   string
	manifest []byte
	pointer  []byte
}

type testChain struct {
	baseURL           string
	operationsPrivate ed25519.PrivateKey
	delegation        []byte
	delegationSig     []byte
	revocations       []byte
	revocationsSig    []byte
	releases          map[string]testRelease
	routes            map[string][]byte
}

func newTestChain(t *testing.T, baseURL string, rootPrivate ed25519.PrivateKey, operationsPublic ed25519.PublicKey, operationsPrivate ed25519.PrivateKey) *testChain {
	t.Helper()
	publicDER, err := x509.MarshalPKIXPublicKey(operationsPublic)
	if err != nil {
		t.Fatal(err)
	}
	delegated := contract.DelegatedKey{KeyID: "test-operations", Algorithm: "ed25519", PublicKey: base64.StdEncoding.EncodeToString(publicDER), ValidFrom: "2020-01-01T00:00:00Z"}
	delegation := marshalTestJSON(t, contract.RootDelegation{
		SchemaVersion: 1, Sequence: 1, IssuedAt: "2026-08-12T19:00:00Z", RootKeyID: "test-root",
		Roles:         map[string][]contract.DelegatedKey{"release": {delegated}, "channel": {delegated}, "metadata": {delegated}, "revocation": {delegated}},
		RevokedKeyIDs: []string{},
	})
	revocations := marshalTestJSON(t, contract.Revocations{SchemaVersion: 1, Sequence: 1, PublishedAt: "2026-08-12T19:00:00Z", RevokedReleases: map[string]contract.Revocation{}})
	return &testChain{
		baseURL: baseURL, operationsPrivate: operationsPrivate,
		delegation: delegation, delegationSig: signTestPayload(t, delegation, rootPrivate, "root", "test-root"),
		revocations: revocations, revocationsSig: signTestPayload(t, revocations, operationsPrivate, "revocation", "test-operations"),
		releases: map[string]testRelease{}, routes: map[string][]byte{},
	}
}

func (chain *testChain) addRelease(t *testing.T, id string, sequence int64, version, sourceCommit string, serverFiles, imageArchive, document []byte) {
	t.Helper()
	serverArtifact := testArtifact(chain.baseURL, serverFiles, nil)
	serverArtifact.UnpackedBytes = testExpandedGzipBytes(t, serverFiles)
	imageArtifact := testArtifact(chain.baseURL, imageArchive, []string{"pocketcoder-test-" + id + ":" + sourceCommit})
	documentDigest := sha256.Sum256(document)
	documentHex := hex.EncodeToString(documentDigest[:])
	maximum := 1
	manifest := contract.Manifest{
		SchemaVersion: 1, ServerVersion: version, SourceRepository: "qtpi-bonding-org/pocketcoder", SourceCommit: sourceCommit,
		BuiltAt: "2026-08-12T19:00:00Z", Platform: contract.Platform{OS: "linux", Architecture: "amd64"},
		DataVersion: 1, MinimumUpgradeFromDataVersion: 1,
		Compatibility: contract.Compatibility{
			App:    contract.AppCompatibility{ContractVersion: 1, OfficialMinimumVersions: map[string]string{"pocketcoder-pro": "1.0.0", "pocketcoder-foss": "1.0.0"}},
			Server: contract.APICompatibility{APIVersion: 1}, Workers: map[string]int{"image-relay": 1, "push-relay": 1, "oauth-relay": 1},
			Provisioning: contract.ContractCompatibility{ContractVersion: 1},
			Deployment:   contract.DeploymentCompatibility{ContractVersion: 1, SupportedSourceContractVersions: contract.VersionRange{Minimum: 1, Maximum: 1}},
		},
		Documents:   map[string]contract.Document{"synthetic": {MediaType: "text/plain", SourcePath: "synthetic.txt", URL: chain.baseURL + "/v1/documents/" + documentHex + ".txt", SHA256: documentHex, DownloadBytes: int64(len(document))}},
		OSImages:    map[string]contract.OSImage{"debian": {Delivery: contract.OSDelivery{Kind: "provider", ProviderImages: map[string]string{"linode": "linode/debian12"}}, Bootstrap: contract.OSBootstrap{Kind: "generated-config", ScriptDocument: "synthetic"}}},
		ServerFiles: serverArtifact,
		Images: contract.Images{
			Required: map[string]contract.Artifact{"server": imageArtifact},
			Choices:  map[string]contract.ChoiceGroup{"coding-harnesses": {SchemaVersion: 1, ConsumerPolicy: "required", MinimumSelections: 1, MaximumSelections: &maximum, Options: map[string]contract.Artifact{"goose": imageArtifact}}},
			Registry: contract.RegistryImages{
				Required: []string{"example/required@sha256:" + strings.Repeat("d", 64)},
				Optional: map[string]contract.OptionalRegistryImage{},
			},
		},
	}
	// Required and choice image inventories must be distinct.
	manifest.Images.Required["server"] = testArtifact(chain.baseURL, imageArchive, []string{"pocketcoder-server:" + sourceCommit})
	manifestBytes := marshalTestJSON(t, manifest)
	manifestDigest := sha256.Sum256(manifestBytes)
	digest := hex.EncodeToString(manifestDigest[:])
	manifestURL := chain.baseURL + "/v1/releases/" + digest + ".json"
	pointer := contract.ChannelPointer{
		SchemaVersion: 1, Channel: "stable", Sequence: sequence, PromotedAt: "2026-08-12T19:00:00Z",
		Manifest:  contract.ManifestReference{URL: manifestURL, SHA256: digest, DownloadBytes: int64(len(manifestBytes)), Signature: contract.SignatureDescriptor{Algorithm: "ed25519", KeyID: "test-operations", URL: manifestURL + ".sig"}},
		Signature: contract.SignatureDescriptor{Algorithm: "ed25519", KeyID: "test-operations", URL: fmt.Sprintf("%s/v1/channels/stable/%d.sig", chain.baseURL, sequence)},
	}
	pointerBytes := marshalTestJSON(t, pointer)
	chain.releases[id] = testRelease{digest: digest, manifest: manifestBytes, pointer: pointerBytes}
	chain.routes["/v1/releases/"+digest+".json"] = manifestBytes
	chain.routes["/v1/releases/"+digest+".json.sig"] = signTestPayload(t, manifestBytes, chain.operationsPrivate, "release", "test-operations")
	chain.routes[fmt.Sprintf("/v1/channels/stable/%d.sig", sequence)] = signTestPayload(t, pointerBytes, chain.operationsPrivate, "channel", "test-operations")
	chain.routes["/v1/artifacts/"+serverArtifact.SHA256+".tar.gz"] = serverFiles
	chain.routes["/v1/artifacts/"+imageArtifact.SHA256+".tar.gz"] = imageArchive
	chain.routes["/v1/documents/"+documentHex+".txt"] = document
}

func (chain *testChain) selectRelease(id string) {
	chain.routes["/v1/delegations/root.json"] = chain.delegation
	chain.routes["/v1/delegations/root.json.sig"] = chain.delegationSig
	chain.routes["/v1/revocations/releases.json"] = chain.revocations
	chain.routes["/v1/revocations/releases/1.sig"] = chain.revocationsSig
	chain.routes["/v1/channels/stable.json"] = chain.releases[id].pointer
}

func testArtifact(baseURL string, body []byte, images []string) contract.Artifact {
	digest := sha256.Sum256(body)
	value := hex.EncodeToString(digest[:])
	return contract.Artifact{URL: baseURL + "/v1/artifacts/" + value + ".tar.gz", SHA256: value, DownloadBytes: int64(len(body)), UnpackedBytes: int64(len(body)), Images: images}
}

func testServerFiles(t *testing.T, version string, dataVersion int, sourceCommit string) []byte {
	t.Helper()
	identity := marshalTestJSON(t, map[string]any{"schemaVersion": 1, "serverVersion": version, "sourceCommit": sourceCommit, "serverApiVersion": 1, "dataVersion": dataVersion, "deploymentContractVersion": 1})
	var compressed bytes.Buffer
	gzipWriter := gzip.NewWriter(&compressed)
	tarWriter := tar.NewWriter(gzipWriter)
	files := map[string]struct {
		body []byte
		mode int64
	}{
		"release.json":                          {identity, 0o644},
		"docker-compose.prebuilt.yml":           {[]byte("services: {}\n"), 0o644},
		"deploy/scripts/prepare-runtime-env.sh": {[]byte("#!/bin/sh\nexit 0\n"), 0o755},
		"bin/pocketcoder-release":               {[]byte("synthetic candidate manager\n"), 0o755},
	}
	for name, file := range files {
		if err := tarWriter.WriteHeader(&tar.Header{Name: name, Mode: file.mode, Size: int64(len(file.body)), Typeflag: tar.TypeReg}); err != nil {
			t.Fatal(err)
		}
		if _, err := tarWriter.Write(file.body); err != nil {
			t.Fatal(err)
		}
	}
	if err := tarWriter.Close(); err != nil {
		t.Fatal(err)
	}
	if err := gzipWriter.Close(); err != nil {
		t.Fatal(err)
	}
	return compressed.Bytes()
}

func testGzip(t *testing.T, body []byte) []byte {
	t.Helper()
	var result bytes.Buffer
	writer := gzip.NewWriter(&result)
	if _, err := writer.Write(body); err != nil {
		t.Fatal(err)
	}
	if err := writer.Close(); err != nil {
		t.Fatal(err)
	}
	return result.Bytes()
}

func testExpandedGzipBytes(t *testing.T, body []byte) int64 {
	t.Helper()
	reader, err := gzip.NewReader(bytes.NewReader(body))
	if err != nil {
		t.Fatal(err)
	}
	defer reader.Close()
	bytesRead, err := io.Copy(io.Discard, reader)
	if err != nil {
		t.Fatal(err)
	}
	return bytesRead
}

func installFakeDocker(t *testing.T, root string) {
	t.Helper()
	bin := filepath.Join(root, "bin")
	if err := os.MkdirAll(bin, 0o755); err != nil {
		t.Fatal(err)
	}
	script := `#!/bin/sh
set -eu
case "${1:-}:${2:-}" in
  image:inspect) test -f "$FAKE_DOCKER_IMAGES" ;;
  image:rm) exit 0 ;;
  load:*) cat >/dev/null; : > "$FAKE_DOCKER_IMAGES" ;;
  compose:*) exit 0 ;;
  *) echo "unexpected fake docker command: $*" >&2; exit 1 ;;
esac
`
	docker := filepath.Join(bin, "docker")
	if err := os.WriteFile(docker, []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("FAKE_DOCKER_IMAGES", filepath.Join(root, "images-loaded"))
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))
}

func signTestPayload(t *testing.T, payload []byte, key ed25519.PrivateKey, role, keyID string) []byte {
	t.Helper()
	digest := sha256.Sum256(payload)
	return marshalTestJSON(t, contract.SignatureEnvelope{SchemaVersion: 1, Algorithm: "ed25519", Role: role, KeyID: keyID, PayloadSHA256: hex.EncodeToString(digest[:]), Signature: base64.StdEncoding.EncodeToString(ed25519.Sign(key, payload))})
}

func marshalTestJSON(t *testing.T, value any) []byte {
	t.Helper()
	data, err := json.Marshal(value)
	if err != nil {
		t.Fatal(err)
	}
	return data
}

func assertCurrentDigest(t *testing.T, stateRoot, want string) {
	t.Helper()
	data, err := os.ReadFile(filepath.Join(stateRoot, "current.json"))
	if err != nil {
		t.Fatal(err)
	}
	var value map[string]any
	if err := json.Unmarshal(data, &value); err != nil {
		t.Fatal(err)
	}
	if value["releaseDigest"] != want {
		t.Fatalf("current digest = %v, want %s", value["releaseDigest"], want)
	}
}

func testCommit(value byte) string { return string(bytes.Repeat([]byte{value}, 40)) }
