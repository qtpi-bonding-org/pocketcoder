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

// Package ollama contains the Ollama runtime control logic: tag listing,
// model-install checks, and container lifecycle management.
package ollama

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"regexp"
	"strings"
	"sync"
	"time"

	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/dockerapi"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/releaseartifact"
)

const DefaultURL = "http://ollama:11434"
const ollamaContainerName = "pocketcoder-ollama"
const ollamaModelsVolumeName = "pocketcoder_ollama_models"

type Model struct {
	Name string `json:"name"`
	Size int64  `json:"size"`
}
type tagsResponse struct {
	Models []Model `json:"models"`
}
type Docker interface {
	releaseartifact.DockerLoader
	Inspect(context.Context, string) (dockerapi.ContainerInspect, error)
	Create(context.Context, string, dockerapi.CreateSpec) (string, error)
	Start(context.Context, string) error
	Remove(context.Context, string) error
}
type Config struct {
	BaseURL string
	Release string
}
type ReleaseImageAcquirer func(context.Context, releaseartifact.DockerLoader, string) (string, error)

var modelName = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._/-]*(?::[A-Za-z0-9][A-Za-z0-9._-]*)?$`)

func ModelNameValid(name string) bool { return modelName.MatchString(name) }
func ResolveBaseURL() string {
	if v := strings.TrimSpace(os.Getenv("OLLAMA_API_URL")); v != "" {
		return strings.TrimRight(v, "/")
	}
	return DefaultURL
}

// ResolveRelease reads POCKETCODER_RELEASE once. Empty or "development"
// selects the local-models runtime path in EnsureRuntime.
func ResolveRelease() string {
	return strings.TrimSpace(os.Getenv("POCKETCODER_RELEASE"))
}
func HTTPClient() *http.Client          { return &http.Client{Timeout: 10 * time.Second} }
func StreamingHTTPClient() *http.Client { return &http.Client{} }
func FetchTags(ctx context.Context, client *http.Client, baseURL string) ([]Model, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, strings.TrimRight(baseURL, "/")+"/api/tags", nil)
	if err != nil {
		return nil, err
	}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		b, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		return nil, fmt.Errorf("Ollama tags returned %s: %s", resp.Status, strings.TrimSpace(string(b)))
	}
	var tags tagsResponse
	if err := json.NewDecoder(resp.Body).Decode(&tags); err != nil {
		return nil, fmt.Errorf("decode Ollama tags: %w", err)
	}
	return tags.Models, nil
}
func ModelInstalled(ctx context.Context, client *http.Client, baseURL, name string) (bool, error) {
	ms, err := FetchTags(ctx, client, baseURL)
	if err != nil {
		return false, err
	}
	for _, m := range ms {
		if m.Name == name {
			return true, nil
		}
	}
	return false, nil
}
func EnsureRuntime(ctx context.Context, docker Docker, client *http.Client, cfg Config, acquire ReleaseImageAcquirer, runtimeMu *sync.Mutex) error {
	if cfg.BaseURL == "" {
		cfg.BaseURL = ResolveBaseURL()
	}
	cfg.Release = strings.TrimSpace(cfg.Release)
	if runtimeMu == nil {
		runtimeMu = &sync.Mutex{}
	}
	if acquire == nil {
		acquire = releaseartifact.EnsureOptionalImage
	}
	runtimeMu.Lock()
	defer runtimeMu.Unlock()
	expected := ""
	acquireImage := func() error {
		image, err := acquire(ctx, docker, "ollama")
		if err != nil {
			return fmt.Errorf("acquire Ollama runtime: %w", err)
		}
		expected = image
		return nil
	}
	insp, err := docker.Inspect(ctx, ollamaContainerName)
	if err == nil {
		if cfg.Release == "" || cfg.Release == "development" {
			if !insp.State.Running {
				if err := docker.Start(ctx, ollamaContainerName); err != nil {
					return fmt.Errorf("start Ollama runtime: %w", err)
				}
			}
			return WaitForReady(ctx, client, cfg.BaseURL)
		}
		if err := acquireImage(); err != nil {
			return err
		}
		if insp.Config.Image != expected {
			if err := docker.Remove(ctx, ollamaContainerName); err != nil {
				return fmt.Errorf("replace stale Ollama runtime: %w", err)
			}
		} else {
			if !insp.State.Running {
				if err := docker.Start(ctx, ollamaContainerName); err != nil {
					return fmt.Errorf("start Ollama runtime: %w", err)
				}
			}
			return WaitForReady(ctx, client, cfg.BaseURL)
		}
	} else if !errors.Is(err, dockerapi.ErrContainerNotFound) {
		return fmt.Errorf("inspect Ollama runtime: %w", err)
	}
	if cfg.Release == "" || cfg.Release == "development" {
		return errors.New("Ollama must be started through the local-models profile in development")
	}
	if expected == "" {
		if err := acquireImage(); err != nil {
			return err
		}
	}
	if _, err := docker.Create(ctx, ollamaContainerName, dockerapi.CreateSpec{Image: expected, Env: []string{"OLLAMA_MODELS=/ollama-models"}, VolumeBinds: []string{ollamaModelsVolumeName + ":/ollama-models"}, NetworkNames: []string{"pocketcoder-model", "pocketcoder-ollama-control"}, NetworkAliases: map[string][]string{"pocketcoder-model": {"ollama"}, "pocketcoder-ollama-control": {"ollama"}}, Labels: map[string]string{"pc_managed": "pocketcoder", "pc_release": cfg.Release, "pc_capability": "ollama"}}); err != nil {
		return fmt.Errorf("create Ollama runtime: %w", err)
	}
	if err := docker.Start(ctx, ollamaContainerName); err != nil {
		return fmt.Errorf("start Ollama runtime: %w", err)
	}
	return WaitForReady(ctx, client, cfg.BaseURL)
}
func WaitForReady(ctx context.Context, client *http.Client, baseURL string) error {
	c, cancel := context.WithTimeout(ctx, 90*time.Second)
	defer cancel()
	t := time.NewTicker(500 * time.Millisecond)
	defer t.Stop()
	for {
		if _, err := FetchTags(c, client, baseURL); err == nil {
			return nil
		}
		select {
		case <-c.Done():
			return errors.New("Ollama runtime did not become ready")
		case <-t.C:
		}
	}
}
