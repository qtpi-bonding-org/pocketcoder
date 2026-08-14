/*
PocketCoder: An accessible, secure, and user-friendly open-source coding assistant platform.
Copyright (C) 2026 Qtpi Bonding LLC

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

package ollama

import (
	"context"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/dockerapi"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/releaseartifact"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
)

type fakeDocker struct {
	inspect    dockerapi.ContainerInspect
	inspectErr error
	running    bool
	created    dockerapi.CreateSpec
	started    []string
	removed    []string
}

func (f *fakeDocker) Inspect(context.Context, string) (dockerapi.ContainerInspect, error) {
	f.inspect.State.Running = f.running
	return f.inspect, f.inspectErr
}
func (f *fakeDocker) ImageExists(context.Context, string) (bool, error) { return false, nil }
func (f *fakeDocker) PullImage(context.Context, string) error           { return nil }
func (f *fakeDocker) LoadImage(_ context.Context, r io.Reader) error {
	_, e := io.Copy(io.Discard, r)
	return e
}
func (f *fakeDocker) Create(_ context.Context, _ string, s dockerapi.CreateSpec) (string, error) {
	f.created = s
	return "id", nil
}
func (f *fakeDocker) Start(_ context.Context, n string) error {
	f.started = append(f.started, n)
	return nil
}
func (f *fakeDocker) Remove(_ context.Context, n string) error {
	f.removed = append(f.removed, n)
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

	installed, err := ModelInstalled(context.Background(), server.Client(), server.URL, "qwen3:0.6b")
	if err != nil {
		t.Fatal(err)
	}
	if !installed {
		t.Fatal("expected tag returned by /api/tags to be installed")
	}
	missing, err := ModelInstalled(context.Background(), server.Client(), server.URL, "qwen2.5:0.5b")
	if err != nil {
		t.Fatal(err)
	}
	if missing {
		t.Fatal("tag absent from /api/tags must not be considered installed")
	}
}

func TestEnsureOllamaRuntimeAcquiresCreatesAndPreservesModelVolume(t *testing.T) {
	const release = "0123456789abcdef0123456789abcdef01234567"
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"models":[]}`))
	}))
	defer server.Close()

	docker := &fakeDocker{inspectErr: dockerapi.ErrContainerNotFound}
	acquired := false
	expectedImage := "ollama/ollama@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
	acquire := func(_ context.Context, _ releaseartifact.DockerLoader, id string) (string, error) {
		acquired = id == "ollama"
		return expectedImage, nil
	}

	cfg := Config{BaseURL: server.URL, Release: release}
	if err := EnsureRuntime(context.Background(), docker, server.Client(), cfg, acquire, nil); err != nil {
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
	if len(docker.started) != 1 || docker.started[0] != "pocketcoder-ollama" {
		t.Fatalf("started = %v", docker.started)
	}
}
