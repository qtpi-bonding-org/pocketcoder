package releaseartifact

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

const testRelease = "0123456789abcdef0123456789abcdef01234567"

type fakeDockerLoader struct {
	mu        sync.Mutex
	exists    bool
	loadCalls int
	payload   []byte
}

func (f *fakeDockerLoader) ImageExists(context.Context, string) (bool, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.exists, nil
}

func (f *fakeDockerLoader) LoadImage(_ context.Context, archive io.Reader) error {
	payload, err := io.ReadAll(archive)
	if err != nil {
		return err
	}
	f.mu.Lock()
	defer f.mu.Unlock()
	f.payload = payload
	f.loadCalls++
	f.exists = true
	return nil
}

func (f *fakeDockerLoader) calls() int {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.loadCalls
}

func writeReleaseState(t *testing.T, root, artifactURL string, payload []byte, checksum string) string {
	t.Helper()
	stateDir := filepath.Join(root, "release")
	if err := os.MkdirAll(filepath.Join(stateDir, "manifests"), 0o755); err != nil {
		t.Fatal(err)
	}
	pointer := releasePointer{
		SchemaVersion:         1,
		ManifestSchemaVersion: 2,
		Release:               testRelease,
		ManifestURL:           "https://images.example.test/release-" + testRelease + ".json",
		ActivatedAt:           "2026-08-10T00:00:00Z",
	}
	manifest := releaseManifest{
		SchemaVersion: 2,
		Release:       testRelease,
		SourceURL:     "https://github.com/example/repo/tree/" + testRelease,
		Harnesses: map[string]artifact{
			"codex": {
				URL:           artifactURL,
				SHA256:        checksum,
				Bytes:         int64(len(payload)),
				ExpandedBytes: int64(len(payload)),
				Images:        []string{"pocketcoder-harness-codex:" + testRelease},
			},
		},
	}
	manifest.Optional.Ollama = artifact{
		URL:           artifactURL,
		SHA256:        checksum,
		Bytes:         int64(len(payload)),
		ExpandedBytes: int64(len(payload)),
		Images:        []string{"pocketcoder-ollama:" + testRelease},
	}
	writeJSON := func(path string, value any) {
		data, err := json.Marshal(value)
		if err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, data, 0o600); err != nil {
			t.Fatal(err)
		}
	}
	pointerPath := filepath.Join(stateDir, "current.json")
	writeJSON(pointerPath, pointer)
	writeJSON(filepath.Join(stateDir, "manifests", testRelease+".json"), manifest)
	return pointerPath
}

func testLoader(t *testing.T, pointerPath, artifactDir string, client *http.Client) *Loader {
	t.Helper()
	return New(Config{
		PointerPath:     pointerPath,
		ArtifactDir:     artifactDir,
		ExpectedRelease: testRelease,
		ReserveBytes:    1,
		DownloadTimeout: 5 * time.Second,
		HTTPClient:      client,
		AvailableBytes:  func(string) (uint64, error) { return 1 << 40, nil },
	})
}

func TestEnsureHarnessImageDownloadsVerifiesLoadsAndRemovesTemporaryArchive(t *testing.T) {
	payload := []byte("compressed docker image archive")
	digest := sha256.Sum256(payload)
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write(payload)
	}))
	defer server.Close()

	root := t.TempDir()
	artifactDir := filepath.Join(root, "artifacts")
	if err := os.MkdirAll(artifactDir, 0o700); err != nil {
		t.Fatal(err)
	}
	pointer := writeReleaseState(t, root, server.URL+"/codex.tar.gz", payload, hex.EncodeToString(digest[:]))
	docker := &fakeDockerLoader{}
	loader := testLoader(t, pointer, artifactDir, server.Client())
	image := "pocketcoder-harness-codex:" + testRelease

	if err := loader.EnsureHarnessImage(context.Background(), docker, "codex", image); err != nil {
		t.Fatal(err)
	}
	if docker.calls() != 1 || string(docker.payload) != string(payload) {
		t.Fatalf("Docker load calls/payload = %d/%q", docker.calls(), docker.payload)
	}
	entries, err := os.ReadDir(artifactDir)
	if err != nil {
		t.Fatal(err)
	}
	if len(entries) != 0 {
		t.Fatalf("temporary artifacts were not removed: %v", entries)
	}
}

func TestEnsureHarnessImageRejectsChecksumBeforeDockerLoad(t *testing.T) {
	payload := []byte("tampered archive")
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write(payload)
	}))
	defer server.Close()

	root := t.TempDir()
	artifactDir := filepath.Join(root, "artifacts")
	if err := os.MkdirAll(artifactDir, 0o700); err != nil {
		t.Fatal(err)
	}
	pointer := writeReleaseState(t, root, server.URL+"/codex.tar.gz", payload, strings.Repeat("a", 64))
	docker := &fakeDockerLoader{}
	err := testLoader(t, pointer, artifactDir, server.Client()).EnsureHarnessImage(
		context.Background(), docker, "codex", "pocketcoder-harness-codex:"+testRelease,
	)
	if err == nil || !strings.Contains(err.Error(), "checksum mismatch") {
		t.Fatalf("error = %v, want checksum mismatch", err)
	}
	if docker.calls() != 0 {
		t.Fatal("checksum mismatch reached Docker load")
	}
}

func TestEnsureOptionalOllamaImageUsesVerifiedReleaseArtifact(t *testing.T) {
	payload := []byte("compressed ollama image archive")
	digest := sha256.Sum256(payload)
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write(payload)
	}))
	defer server.Close()

	root := t.TempDir()
	artifactDir := filepath.Join(root, "artifacts")
	if err := os.MkdirAll(artifactDir, 0o700); err != nil {
		t.Fatal(err)
	}
	pointer := writeReleaseState(t, root, server.URL+"/ollama.tar.gz", payload, hex.EncodeToString(digest[:]))
	docker := &fakeDockerLoader{}
	loader := testLoader(t, pointer, artifactDir, server.Client())
	image := "pocketcoder-ollama:" + testRelease

	if err := loader.EnsureOptionalImage(context.Background(), docker, "ollama", image); err != nil {
		t.Fatal(err)
	}
	if docker.calls() != 1 || string(docker.payload) != string(payload) {
		t.Fatalf("Docker load calls/payload = %d/%q", docker.calls(), docker.payload)
	}
	if err := loader.EnsureOptionalImage(context.Background(), docker, "cognee", image); err == nil {
		t.Fatal("deferred Cognee capability was unexpectedly accepted")
	}
}

func TestEnsureHarnessImageDeduplicatesConcurrentDownloads(t *testing.T) {
	payload := []byte("one shared artifact download")
	digest := sha256.Sum256(payload)
	started := make(chan struct{})
	releaseDownload := make(chan struct{})
	var startOnce sync.Once
	var requests atomic.Int32
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		requests.Add(1)
		startOnce.Do(func() { close(started) })
		<-releaseDownload
		_, _ = w.Write(payload)
	}))
	defer server.Close()

	root := t.TempDir()
	artifactDir := filepath.Join(root, "artifacts")
	if err := os.MkdirAll(artifactDir, 0o700); err != nil {
		t.Fatal(err)
	}
	pointer := writeReleaseState(t, root, server.URL+"/codex.tar.gz", payload, hex.EncodeToString(digest[:]))
	docker := &fakeDockerLoader{}
	loader := testLoader(t, pointer, artifactDir, server.Client())
	image := "pocketcoder-harness-codex:" + testRelease

	const callers = 12
	ready := sync.WaitGroup{}
	ready.Add(callers)
	begin := make(chan struct{})
	errors := make(chan error, callers)
	for range callers {
		go func() {
			ready.Done()
			<-begin
			errors <- loader.EnsureHarnessImage(context.Background(), docker, "codex", image)
		}()
	}
	ready.Wait()
	close(begin)
	<-started
	close(releaseDownload)
	for range callers {
		if err := <-errors; err != nil {
			t.Fatal(err)
		}
	}
	if requests.Load() != 1 || docker.calls() != 1 {
		t.Fatalf("requests/load calls = %d/%d, want 1/1", requests.Load(), docker.calls())
	}
}

func TestEnsureHarnessImageRejectsInsufficientDiskBeforeDownload(t *testing.T) {
	payload := []byte("archive")
	digest := sha256.Sum256(payload)
	var requests atomic.Int32
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		requests.Add(1)
		_, _ = w.Write(payload)
	}))
	defer server.Close()
	root := t.TempDir()
	artifactDir := filepath.Join(root, "artifacts")
	if err := os.MkdirAll(artifactDir, 0o700); err != nil {
		t.Fatal(err)
	}
	pointer := writeReleaseState(t, root, server.URL+"/codex.tar.gz", payload, hex.EncodeToString(digest[:]))
	loader := testLoader(t, pointer, artifactDir, server.Client())
	loader.config.AvailableBytes = func(string) (uint64, error) { return 1, nil }
	err := loader.EnsureHarnessImage(context.Background(), &fakeDockerLoader{}, "codex", "pocketcoder-harness-codex:"+testRelease)
	if err == nil || !strings.Contains(err.Error(), "insufficient disk space") {
		t.Fatalf("error = %v, want insufficient disk space", err)
	}
	if requests.Load() != 0 {
		t.Fatal("insufficient disk space still reached the artifact server")
	}
}

func TestManagedReleaseImageRequiresExactCommitTag(t *testing.T) {
	if !ManagedReleaseImage("pocketcoder-harness-codex:"+testRelease, testRelease) {
		t.Fatal("expected commit-tagged image to be managed")
	}
	if ManagedReleaseImage("pocketcoder-harness-codex:latest", testRelease) {
		t.Fatal("latest tag must not be treated as a release artifact")
	}
}
