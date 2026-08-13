// @pocketcoder-core: Ollama control API. PocketBase is the only service on
// the control network, so clients never receive a route or a port to the
// local-model runtime directly.
package api

import (
	"bufio"
	"bytes"
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

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/dockerapi"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/releaseartifact"
)

const (
	defaultOllamaURL       = "http://ollama:11434"
	ollamaContainerName    = "pocketcoder-ollama"
	ollamaModelsVolumeName = "pocketcoder_ollama_models"
)

var ollamaModelName = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._/-]*(?::[A-Za-z0-9][A-Za-z0-9._-]*)?$`)

type ollamaModel struct {
	Name string `json:"name"`
	Size int64  `json:"size"`
}

type ollamaTagsResponse struct {
	Models []ollamaModel `json:"models"`
}

type ollamaPullRequest struct {
	Model string `json:"model"`
}

type ollamaDocker interface {
	releaseartifact.DockerLoader
	Inspect(context.Context, string) (dockerapi.ContainerInspect, error)
	Create(context.Context, string, dockerapi.CreateSpec) (string, error)
	Start(context.Context, string) error
	Remove(context.Context, string) error
}

var (
	ollamaRuntimeMu          sync.Mutex
	ensureOllamaReleaseImage = releaseartifact.EnsureOptionalImage
)

func ollamaURL() string {
	if value := strings.TrimRight(os.Getenv("OLLAMA_API_URL"), "/"); value != "" {
		return value
	}
	return defaultOllamaURL
}

func ollamaHTTPClient() *http.Client {
	return &http.Client{Timeout: 0}
}

func fetchOllamaTags(ctx context.Context, client *http.Client, baseURL string) ([]ollamaModel, error) {
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
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		return nil, fmt.Errorf("Ollama tags returned %s: %s", resp.Status, strings.TrimSpace(string(body)))
	}
	var tags ollamaTagsResponse
	if err := json.NewDecoder(resp.Body).Decode(&tags); err != nil {
		return nil, fmt.Errorf("decode Ollama tags: %w", err)
	}
	return tags.Models, nil
}

// ollamaModelInstalled checks the runtime's source of truth rather than a
// PocketBase catalog cache. A deleted model immediately becomes unavailable.
func ollamaModelInstalled(ctx context.Context, client *http.Client, name string) (bool, error) {
	models, err := fetchOllamaTags(ctx, client, ollamaURL())
	if err != nil {
		return false, err
	}
	for _, model := range models {
		if model.Name == name {
			return true, nil
		}
	}
	return false, nil
}

// ensureOllamaRuntime is invoked only by the explicit administrator model-pull
// operation. Listing models must remain cheap and must never turn opening a
// picker into an unexpected multi-gigabyte runtime download.
func ensureOllamaRuntime(ctx context.Context, docker ollamaDocker, client *http.Client, baseURL string) error {
	ollamaRuntimeMu.Lock()
	defer ollamaRuntimeMu.Unlock()

	release := os.Getenv("POCKETCODER_RELEASE")
	expectedImage := "pocketcoder-ollama:" + release
	insp, err := docker.Inspect(ctx, ollamaContainerName)
	if err == nil {
		if release != "" && release != "development" && insp.Config.Image != expectedImage {
			if err := docker.Remove(ctx, ollamaContainerName); err != nil {
				return fmt.Errorf("replace stale Ollama runtime: %w", err)
			}
		} else {
			if !insp.State.Running {
				if err := docker.Start(ctx, ollamaContainerName); err != nil {
					return fmt.Errorf("start Ollama runtime: %w", err)
				}
			}
			return waitForOllama(ctx, client, baseURL)
		}
	} else if !errors.Is(err, dockerapi.ErrContainerNotFound) {
		return fmt.Errorf("inspect Ollama runtime: %w", err)
	}

	if release == "" || release == "development" {
		return errors.New("Ollama must be started through the local-models profile in development")
	}
	if err := ensureOllamaReleaseImage(ctx, docker, "ollama", expectedImage); err != nil {
		return fmt.Errorf("acquire Ollama runtime: %w", err)
	}
	if _, err := docker.Create(ctx, ollamaContainerName, dockerapi.CreateSpec{
		Image: expectedImage,
		Env:   []string{"OLLAMA_MODELS=/ollama-models"},
		VolumeBinds: []string{
			ollamaModelsVolumeName + ":/ollama-models",
		},
		NetworkNames: []string{"pocketcoder-model", "pocketcoder-ollama-control"},
		NetworkAliases: map[string][]string{
			"pocketcoder-model":          {"ollama"},
			"pocketcoder-ollama-control": {"ollama"},
		},
		Labels: map[string]string{
			"pc_managed":    "pocketcoder",
			"pc_release":    release,
			"pc_capability": "ollama",
		},
	}); err != nil {
		return fmt.Errorf("create Ollama runtime: %w", err)
	}
	if err := docker.Start(ctx, ollamaContainerName); err != nil {
		return fmt.Errorf("start Ollama runtime: %w", err)
	}
	return waitForOllama(ctx, client, baseURL)
}

func waitForOllama(ctx context.Context, client *http.Client, baseURL string) error {
	readyCtx, cancel := context.WithTimeout(ctx, 90*time.Second)
	defer cancel()
	ticker := time.NewTicker(500 * time.Millisecond)
	defer ticker.Stop()
	for {
		if _, err := fetchOllamaTags(readyCtx, client, baseURL); err == nil {
			return nil
		}
		select {
		case <-readyCtx.Done():
			return errors.New("Ollama runtime did not become ready")
		case <-ticker.C:
		}
	}
}

// RegisterOllamaApi exposes a private local-model control plane. Installed
// tags are virtual choices, never models/harness_models catalog records.
func RegisterOllamaApi(_ *pocketbase.PocketBase, e *core.ServeEvent) {
	client := ollamaHTTPClient()
	docker := dockerapi.New()

	e.Router.GET("/api/pocketcoder/ollama/models", func(re *core.RequestEvent) error {
		models, err := fetchOllamaTags(re.Request.Context(), client, ollamaURL())
		if err != nil {
			return re.JSON(http.StatusOK, map[string]any{
				"models":  []ollamaModel{},
				"enabled": false,
			})
		}
		return re.JSON(http.StatusOK, map[string]any{"models": models, "enabled": true})
	}).Bind(apis.RequireAuth())

	e.Router.POST("/api/pocketcoder/ollama/pull", func(re *core.RequestEvent) error {
		if err := requireAdmin(re); err != nil {
			return err
		}
		var input ollamaPullRequest
		if err := re.BindBody(&input); err != nil || !ollamaModelName.MatchString(input.Model) {
			return re.JSON(http.StatusBadRequest, map[string]string{"error": "model must be a valid Ollama model name"})
		}
		if err := ensureOllamaRuntime(re.Request.Context(), docker, client, ollamaURL()); err != nil {
			return re.JSON(http.StatusServiceUnavailable, map[string]string{"error": err.Error()})
		}
		payload, _ := json.Marshal(map[string]string{"model": input.Model})
		request, err := http.NewRequestWithContext(re.Request.Context(), http.MethodPost, ollamaURL()+"/api/pull", bytes.NewReader(payload))
		if err != nil {
			return re.InternalServerError("create Ollama pull request", err)
		}
		request.Header.Set("Content-Type", "application/json")
		response, err := client.Do(request)
		if err != nil {
			return re.JSON(http.StatusBadGateway, map[string]string{"error": "Ollama is unavailable"})
		}
		defer response.Body.Close()
		if response.StatusCode < http.StatusOK || response.StatusCode >= http.StatusMultipleChoices {
			body, _ := io.ReadAll(io.LimitReader(response.Body, 4096))
			return re.JSON(http.StatusBadGateway, map[string]string{"error": strings.TrimSpace(string(body))})
		}

		re.Response.Header().Set("Content-Type", "application/x-ndjson")
		re.Response.Header().Set("Cache-Control", "no-cache")
		re.Response.WriteHeader(http.StatusOK)
		scanner := bufio.NewScanner(response.Body)
		scanner.Buffer(make([]byte, 4096), 1024*1024)
		for scanner.Scan() {
			line := scanner.Bytes()
			if _, err := re.Response.Write(append(line, '\n')); err != nil {
				return nil
			}
			if flusher, ok := re.Response.(http.Flusher); ok {
				flusher.Flush()
			}
		}
		return scanner.Err()
	}).Bind(apis.RequireAuth())
}
