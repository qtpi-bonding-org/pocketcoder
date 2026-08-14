// @pocketcoder-core: Ollama control API. PocketBase is the only service on
// the control network, so clients never receive a route or a port to the
// local-model runtime directly.
package api

import (
	"bufio"
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"os"
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
		config.Release = strings.TrimSpace(os.Getenv("POCKETCODER_RELEASE"))
	}
	runtimeMu := deps.RuntimeMu
	if runtimeMu == nil {
		runtimeMu = &sync.Mutex{}
	}

	registry.Add(operation.Route{OperationID: "listOllamaModels", Method: http.MethodGet, Path: "/api/pocketcoder/v1/ollama/models", Auth: true, Action: func(re *core.RequestEvent) error {
		models, err := ollama.FetchTags(re.Request.Context(), client, config.BaseURL)
		if err != nil {
			return re.JSON(http.StatusOK, map[string]any{
				"models":  []ollama.Model{},
				"enabled": false,
			})
		}
		return re.JSON(http.StatusOK, map[string]any{"models": models, "enabled": true})
	}})

	registry.Add(operation.Route{OperationID: "pullOllamaModel", Method: http.MethodPost, Path: "/api/pocketcoder/v1/ollama/pull", Auth: true, Direct: true, Action: func(re *core.RequestEvent) error {
		if err := requireRole(re, "admin"); err != nil {
			return err
		}
		var input ollamaPullRequest
		if err := re.BindBody(&input); err != nil || !ollama.ModelNameValid(input.Model) {
			return pocketCoderError(re, http.StatusBadRequest, "model must be a valid Ollama model name")
		}
		if err := ollama.EnsureRuntime(re.Request.Context(), docker, client, config, nil, runtimeMu); err != nil {
			return pocketCoderError(re, http.StatusServiceUnavailable, err.Error())
		}
		payload, _ := json.Marshal(map[string]string{"model": input.Model})
		request, err := http.NewRequestWithContext(re.Request.Context(), http.MethodPost, config.BaseURL+"/api/pull", bytes.NewReader(payload))
		if err != nil {
			return pocketCoderError(re, http.StatusInternalServerError, "create Ollama pull request")
		}
		request.Header.Set("Content-Type", "application/json")
		response, err := streamClient.Do(request)
		if err != nil {
			return pocketCoderError(re, http.StatusBadGateway, "Ollama is unavailable")
		}
		defer response.Body.Close()
		if response.StatusCode < http.StatusOK || response.StatusCode >= http.StatusMultipleChoices {
			body, _ := io.ReadAll(io.LimitReader(response.Body, 4096))
			return pocketCoderError(re, http.StatusBadGateway, strings.TrimSpace(string(body)))
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
	}})
}
