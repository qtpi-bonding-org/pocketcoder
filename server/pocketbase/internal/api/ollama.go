// @pocketcoder-core: Ollama control API. PocketBase is the only service on
// the control network, so clients never receive a route or a port to the
// local-model runtime directly.
package api

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"regexp"
	"strings"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
)

const defaultOllamaURL = "http://ollama:11434"

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

// RegisterOllamaApi exposes a private local-model control plane. Installed
// tags are virtual choices, never models/harness_models catalog records.
func RegisterOllamaApi(_ *pocketbase.PocketBase, e *core.ServeEvent) {
	client := ollamaHTTPClient()

	e.Router.GET("/api/pocketcoder/ollama/models", func(re *core.RequestEvent) error {
		models, err := fetchOllamaTags(re.Request.Context(), client, ollamaURL())
		if err != nil {
			return re.JSON(http.StatusBadGateway, map[string]string{"error": "Ollama is unavailable"})
		}
		return re.JSON(http.StatusOK, map[string]any{"models": models})
	}).Bind(apis.RequireAuth())

	e.Router.POST("/api/pocketcoder/ollama/pull", func(re *core.RequestEvent) error {
		if err := requireAdmin(re); err != nil {
			return err
		}
		var input ollamaPullRequest
		if err := re.BindBody(&input); err != nil || !ollamaModelName.MatchString(input.Model) {
			return re.JSON(http.StatusBadRequest, map[string]string{"error": "model must be a valid Ollama model name"})
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
