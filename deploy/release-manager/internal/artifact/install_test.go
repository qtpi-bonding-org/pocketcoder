package artifact

import (
	"crypto/sha256"
	"encoding/hex"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/contract"
)

type fakeImageRuntime struct {
	images map[string]bool
	loaded bool
}

type roundTripFunc func(*http.Request) (*http.Response, error)

func (function roundTripFunc) RoundTrip(request *http.Request) (*http.Response, error) {
	return function(request)
}

func (runtime *fakeImageRuntime) ImageExists(image string) bool {
	return runtime.images[image]
}

func (runtime *fakeImageRuntime) LoadGzipArchive(path string) error {
	file, err := os.Open(path)
	if err != nil {
		return err
	}
	defer file.Close()
	if _, err := io.Copy(io.Discard, file); err != nil {
		return err
	}
	runtime.loaded = true
	runtime.images["example/image:release"] = true
	return nil
}

func TestImageInstallerStreamsVerifiedArtifactToDisk(t *testing.T) {
	payload := strings.Repeat("archive-data", 128*1024)
	digest := sha256.Sum256([]byte(payload))
	client := &http.Client{Transport: roundTripFunc(func(_ *http.Request) (*http.Response, error) {
		return &http.Response{
			StatusCode:    http.StatusOK,
			Body:          io.NopCloser(strings.NewReader(payload)),
			Header:        make(http.Header),
			ContentLength: int64(len(payload)),
		}, nil
	})}

	directory := t.TempDir()
	digestString := hex.EncodeToString(digest[:])
	stalePath := filepath.Join(directory, digestString+".part")
	if err := os.WriteFile(stalePath, []byte("interrupted"), 0o600); err != nil {
		t.Fatal(err)
	}
	runtime := &fakeImageRuntime{images: map[string]bool{}}
	descriptor := contract.Artifact{
		URL: "https://images.example/artifact", SHA256: digestString,
		DownloadBytes: int64(len(payload)), UnpackedBytes: int64(len(payload)),
		Images: []string{"example/image:release"},
	}
	installer := ImageInstaller{Fetcher: Fetcher{Client: client}, Runtime: runtime, StagingDirectory: directory}
	if err := installer.Ensure("required.server", descriptor); err != nil {
		t.Fatal(err)
	}
	if !runtime.loaded {
		t.Fatal("expected Docker archive load")
	}
	if _, err := os.Stat(stalePath); !os.IsNotExist(err) {
		t.Fatalf("temporary artifact remains: %v", err)
	}
}

func TestImageInstallerSkipsDownloadWhenAllImagesExist(t *testing.T) {
	runtime := &fakeImageRuntime{images: map[string]bool{"example/image:release": true}}
	installer := ImageInstaller{Runtime: runtime, StagingDirectory: t.TempDir()}
	if err := installer.Ensure("required.server", contract.Artifact{Images: []string{"example/image:release"}}); err != nil {
		t.Fatal(err)
	}
	if runtime.loaded {
		t.Fatal("already loaded image should not be downloaded")
	}
}
