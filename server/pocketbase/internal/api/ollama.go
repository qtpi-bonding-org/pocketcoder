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
	"log"
	"net/http"
	"os"
	"regexp"
	"strings"
	"time"

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

type ollamaPullEvent struct {
	Status string `json:"status"`
	Error  string `json:"error"`
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

// syncOllamaModels makes installed local models selectable through the
// existing realtime models/harness_models catalog. No new schema or per-user
// data is introduced: an installed model is a host-level capability.
func syncOllamaModels(app core.App, installed []ollamaModel) error {
	models, err := app.FindCollectionByNameOrId("models")
	if err != nil {
		return err
	}
	harnessModels, err := app.FindCollectionByNameOrId("harness_models")
	if err != nil {
		return err
	}

	var targets []*core.Record
	for _, cliID := range []string{"goose", "opencode"} {
		harness, findErr := app.FindFirstRecordByFilter("harnesses", "cli_id = {:cli}", map[string]any{"cli": cliID})
		if findErr != nil {
			return fmt.Errorf("find %s harness: %w", cliID, findErr)
		}
		targets = append(targets, harness)
	}

	for _, installedModel := range installed {
		if !ollamaModelName.MatchString(installedModel.Name) {
			continue
		}
		model, findErr := app.FindFirstRecordByFilter(
			"models",
			"provider = {:provider} && name = {:name}",
			map[string]any{"provider": "ollama", "name": installedModel.Name},
		)
		if findErr != nil {
			model = core.NewRecord(models)
			model.Set("name", installedModel.Name)
			model.Set("display_name", installedModel.Name+" (local)")
			model.Set("provider", "ollama")
			model.Set("description", "Installed in PocketCoder's local Ollama runtime.")
			if err := app.Save(model); err != nil {
				return fmt.Errorf("save local model %s: %w", installedModel.Name, err)
			}
		}
		for _, harness := range targets {
			existing, findErr := app.FindRecordsByFilter(
				"harness_models",
				"harness = {:harness} && model = {:model}",
				"",
				1,
				0,
				map[string]any{"harness": harness.Id, "model": model.Id},
			)
			if findErr != nil {
				return fmt.Errorf("find local harness model: %w", findErr)
			}
			if len(existing) != 0 {
				continue
			}
			link := core.NewRecord(harnessModels)
			link.Set("harness", harness.Id)
			link.Set("model", model.Id)
			link.Set("harness_model_id", installedModel.Name)
			if err := app.Save(link); err != nil {
				return fmt.Errorf("save %s local model link: %w", harness.GetString("cli_id"), err)
			}
		}
	}
	return nil
}

// RegisterOllamaApi exposes a small authenticated control plane. Model pulls
// stream Ollama's native NDJSON progress to the caller; once a pull completes,
// the installed model is synchronized into PocketBase's existing catalog.
func RegisterOllamaApi(app *pocketbase.PocketBase, e *core.ServeEvent) {
	client := ollamaHTTPClient()

	e.Router.GET("/api/pocketcoder/ollama/models", func(re *core.RequestEvent) error {
		if err := requireAdmin(re); err != nil {
			return err
		}
		models, err := fetchOllamaTags(re.Request.Context(), client, ollamaURL())
		if err != nil {
			return re.JSON(http.StatusBadGateway, map[string]string{"error": "Ollama is unavailable"})
		}
		return re.JSON(http.StatusOK, map[string]any{"models": models})
	}).Bind(apis.RequireAuth())

	e.Router.POST("/api/pocketcoder/ollama/refresh", func(re *core.RequestEvent) error {
		if err := requireAdmin(re); err != nil {
			return err
		}
		models, err := fetchOllamaTags(re.Request.Context(), client, ollamaURL())
		if err != nil {
			return re.JSON(http.StatusBadGateway, map[string]string{"error": "Ollama is unavailable"})
		}
		if err := syncOllamaModels(app, models); err != nil {
			return re.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to synchronize local models"})
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
		completed := false
		for scanner.Scan() {
			line := scanner.Bytes()
			if _, err := re.Response.Write(append(line, '\n')); err != nil {
				return nil
			}
			if flusher, ok := re.Response.(http.Flusher); ok {
				flusher.Flush()
			}
			var event ollamaPullEvent
			if json.Unmarshal(line, &event) == nil && event.Status == "success" {
				completed = true
			}
		}
		if err := scanner.Err(); err != nil {
			log.Printf("Ollama pull stream for %s ended: %v", input.Model, err)
		}
		if completed {
			ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
			defer cancel()
			models, err := fetchOllamaTags(ctx, client, ollamaURL())
			if err != nil {
				log.Printf("Ollama pull completed but model refresh failed: %v", err)
			} else if err := syncOllamaModels(app, models); err != nil {
				log.Printf("Ollama pull completed but catalog sync failed: %v", err)
			}
		}
		return nil
	}).Bind(apis.RequireAuth())
}
