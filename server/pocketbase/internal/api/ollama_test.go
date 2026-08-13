package api

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/dockerapi"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/releaseartifact"
)

type fakeOllamaDocker struct {
	inspect    dockerapi.ContainerInspect
	inspectErr error
	created    dockerapi.CreateSpec
	started    []string
	removed    []string
}

func (f *fakeOllamaDocker) Inspect(context.Context, string) (dockerapi.ContainerInspect, error) {
	return f.inspect, f.inspectErr
}

func (f *fakeOllamaDocker) ImageExists(context.Context, string) (bool, error) { return false, nil }

func (f *fakeOllamaDocker) PullImage(context.Context, string) error { return nil }

func (f *fakeOllamaDocker) LoadImage(_ context.Context, archive io.Reader) error {
	_, err := io.Copy(io.Discard, archive)
	return err
}

func (f *fakeOllamaDocker) Create(_ context.Context, _ string, spec dockerapi.CreateSpec) (string, error) {
	f.created = spec
	return "ollama-id", nil
}

func (f *fakeOllamaDocker) Start(_ context.Context, name string) error {
	f.started = append(f.started, name)
	return nil
}

func (f *fakeOllamaDocker) Remove(_ context.Context, name string) error {
	f.removed = append(f.removed, name)
	return nil
}

func TestOllamaModelInstalledUsesLiveTags(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/tags" {
			t.Fatalf("path = %q, want /api/tags", r.URL.Path)
		}
		_, _ = w.Write([]byte(`{"models":[{"name":"qwen3:0.6b","size":523000000}]}`))
	}))
	defer server.Close()
	t.Setenv("OLLAMA_API_URL", server.URL)

	installed, err := ollamaModelInstalled(context.Background(), server.Client(), "qwen3:0.6b")
	if err != nil {
		t.Fatal(err)
	}
	if !installed {
		t.Fatal("expected tag returned by /api/tags to be installed")
	}
	missing, err := ollamaModelInstalled(context.Background(), server.Client(), "qwen2.5:0.5b")
	if err != nil {
		t.Fatal(err)
	}
	if missing {
		t.Fatal("tag absent from /api/tags must not be considered installed")
	}
}

func TestEnsureOllamaRuntimeAcquiresCreatesAndPreservesModelVolume(t *testing.T) {
	const release = "0123456789abcdef0123456789abcdef01234567"
	t.Setenv("POCKETCODER_RELEASE", release)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"models":[]}`))
	}))
	defer server.Close()

	docker := &fakeOllamaDocker{inspectErr: dockerapi.ErrContainerNotFound}
	original := ensureOllamaReleaseImage
	acquired := false
	expectedImage := "ollama/ollama@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
	ensureOllamaReleaseImage = func(_ context.Context, _ releaseartifact.DockerLoader, id string) (string, error) {
		acquired = id == "ollama"
		return expectedImage, nil
	}
	t.Cleanup(func() { ensureOllamaReleaseImage = original })

	if err := ensureOllamaRuntime(context.Background(), docker, server.Client(), server.URL); err != nil {
		t.Fatal(err)
	}
	if !acquired || docker.created.Image != expectedImage {
		t.Fatalf("acquired/image = %v/%q", acquired, docker.created.Image)
	}
	if len(docker.created.VolumeBinds) != 1 || docker.created.VolumeBinds[0] != "pocketcoder_ollama_models:/ollama-models" {
		t.Fatalf("Ollama volume binds = %v", docker.created.VolumeBinds)
	}
	for _, network := range docker.created.NetworkNames {
		aliases := docker.created.NetworkAliases[network]
		if len(aliases) != 1 || aliases[0] != "ollama" {
			t.Fatalf("Ollama aliases on %s = %v", network, aliases)
		}
	}
	if docker.created.Labels["pc_managed"] != "pocketcoder" || docker.created.Labels["pc_release"] != release {
		t.Fatalf("Ollama labels = %v", docker.created.Labels)
	}
	if len(docker.started) != 1 || docker.started[0] != ollamaContainerName {
		t.Fatalf("started = %v", docker.started)
	}
}
