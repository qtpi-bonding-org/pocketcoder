// @pocketcoder-core: Ollama control API. PocketBase is the only service on
// the control network, so clients never receive a route or a port to the
// local-model runtime directly.
package api

import (
	"bufio"
	"bytes"
	"encoding/json"
	"github.com/pocketbase/pocketbase/apis"
	"io"
	"log"
	"net/http"
	"strings"
	"sync"

	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/dockerapi"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/ollama"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/operation"
)

type ollamaPullRequest struct {
	Model string `json:"model"`
}
type OllamaDeps struct {
	Docker     ollama.Docker
	HTTP       *http.Client
	StreamHTTP *http.Client
	Config     ollama.Config
	RuntimeMu  *sync.Mutex
}

func ListOllamaModels(re *core.RequestEvent, client *http.Client, baseURL string) ([]ollama.Model, bool, error) {
	if err := requireRole(re, "admin"); err != nil {
		return nil, false, err
	}
	models, err := ollama.FetchTags(re.Request.Context(), client, baseURL)
	if err != nil {
		log.Printf("[Ollama] fetch tags failed: %v", err)
		return []ollama.Model{}, false, nil
	}
	return models, true, nil
}

func AddOllamaOperations(registry *operation.Registry, deps OllamaDeps) {
	docker := deps.Docker
	if docker == nil {
		docker = dockerapi.New()
	}

	client := deps.HTTP
	if client == nil {
		client = ollama.HTTPClient()
	}
	streamClient := deps.StreamHTTP
	if streamClient == nil {
		streamClient = ollama.StreamingHTTPClient()
	}
	config := deps.Config
	if strings.TrimSpace(config.BaseURL) == "" {
		config.BaseURL = ollama.ResolveBaseURL()
	}
	if strings.TrimSpace(config.Release) == "" {
		config.Release = ollama.ResolveRelease()
	}
	runtimeMu := deps.RuntimeMu
	if runtimeMu == nil {
		runtimeMu = &sync.Mutex{}
	}

	registry.Add(operation.Route{OperationID: "listOllamaModels", Method: http.MethodGet, Path: "/api/pocketcoder/v1/ollama/models", Auth: true, Action: func(re *core.RequestEvent) error {
		// Model inventory exposes deployment configuration; keep this admin-only
		// even though single-user Pro deployments always authenticate as admin.
		// This deliberate restriction also applies to FOSS users seeded with the
		// user role, rather than treating the model picker as generally readable.
		models, enabled, err := ListOllamaModels(re, client, config.BaseURL)
		if err != nil {
			return err
		}
		return re.JSON(http.StatusOK, map[string]any{"models": models, "enabled": enabled})
	}})

	registry.Add(operation.Route{OperationID: "pullOllamaModel", Method: http.MethodPost, Path: "/api/pocketcoder/v1/ollama/pull", Auth: true, Direct: true, Action: func(re *core.RequestEvent) error {
		if err := requireRole(re, "admin"); err != nil {
			return err
		}
		var input ollamaPullRequest
		if err := re.BindBody(&input); err != nil || !ollama.ModelNameValid(input.Model) {
			return re.BadRequestError("model must be a valid Ollama model name", nil)
		}
		if err := ollama.EnsureRuntime(re.Request.Context(), docker, client, config, nil, runtimeMu); err != nil {
			log.Printf("[Ollama] ensure runtime failed: %v", err)
			return apis.NewApiError(http.StatusServiceUnavailable, err.Error(), nil)
		}
		payload, err := json.Marshal(map[string]string{"model": input.Model})
		if err != nil {
			log.Printf("[Ollama] marshal pull request payload failed: %v", err)
		}
		request, err := http.NewRequestWithContext(re.Request.Context(), http.MethodPost, config.BaseURL+"/api/pull", bytes.NewReader(payload))
		if err != nil {
			log.Printf("[Ollama] create pull request failed: %v", err)
			return re.InternalServerError("create Ollama pull request", nil)
		}
		request.Header.Set("Content-Type", "application/json")
		response, err := streamClient.Do(request)
		if err != nil {
			log.Printf("[Ollama] pull request failed: %v", err)
			return apis.NewApiError(http.StatusBadGateway, "Ollama is unavailable", nil)
		}
		defer response.Body.Close()
		if response.StatusCode < http.StatusOK || response.StatusCode >= http.StatusMultipleChoices {
			body, _ := io.ReadAll(io.LimitReader(response.Body, 4096))
			log.Printf("[Ollama] pull request returned status %d: %q", response.StatusCode, strings.TrimSpace(string(body)))
			return apis.NewApiError(http.StatusBadGateway, strings.TrimSpace(string(body)), nil)
		}

		re.Response.Header().Set("Content-Type", "application/x-ndjson")
		re.Response.Header().Set("Cache-Control", "no-cache")
		re.Response.WriteHeader(http.StatusOK)
		scanner := bufio.NewScanner(response.Body)
		scanner.Buffer(make([]byte, 4096), 1024*1024)
		for scanner.Scan() {
			line := scanner.Bytes()
			if _, err := re.Response.Write(append(line, '\n')); err != nil {
				log.Printf("[Ollama] ollama pull stream write failed (client likely disconnected): %v", err)
				return nil
			}
			if flusher, ok := re.Response.(http.Flusher); ok {
				flusher.Flush()
			}
		}
		if err := scanner.Err(); err != nil {
			log.Printf("[Ollama] ollama pull stream scan failed: %v", err)
			return err
		}
		return nil
	}})
}
