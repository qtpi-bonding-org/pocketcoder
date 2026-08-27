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

// @pocketcoder-core: Model Catalog Sync. Both Goose and OpenCode build their
// own provider/model catalogs from models.dev at runtime or compile time, so
// it's the natural shared source of truth for PocketCoder's own "providers",
// "models", and "harness_models" catalog rows -- rather than requiring an
// admin to hand-populate them, or PocketCoder guessing an API key's env var
// name by naively uppercasing a provider id (wrong for e.g. Google, which
// accepts GOOGLE_API_KEY, GOOGLE_GENERATIVE_AI_API_KEY, or GEMINI_API_KEY).
package modelcatalog

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"time"

	"github.com/pocketbase/pocketbase/core"
)

// DefaultCatalogURL is models.dev's published catalog endpoint -- the same
// one OpenCode fetches at startup and Goose's Canonical Model Registry is
// compiled from.
const DefaultCatalogURL = "https://models.dev/api.json"

// MultiProviderAllowlist is the curated set of models.dev providers synced
// for multi-provider (harnesses.provider_scope == "any") harnesses: today
// Goose and OpenCode. Deliberately small -- models.dev lists 200+ providers,
// most of them niche OpenAI-compatible resellers, so syncing all of them
// into harness_models would drown the model picker. Extend this list to add
// a provider; no schema change is needed.
var MultiProviderAllowlist = []string{
	"anthropic", "openai", "openrouter", "google", "groq", "deepseek", "mistral", "xai",
}

// ProviderInfo is the trimmed shape of one models.dev provider entry --
// only the fields PocketCoder actually needs, decoded defensively so
// unrelated upstream schema growth (pricing, capability flags, etc.) never
// breaks this sync.
type ProviderInfo struct {
	ID        string
	Name      string
	APIKeyEnv string // env[0]; empty if the provider declares no env var (e.g. a local-only backend)
	Models    map[string]ModelInfo
}

// ModelInfo is the trimmed shape of one models.dev model entry.
type ModelInfo struct {
	ID            string
	Name          string
	Description   string
	ContextWindow int
}

type rawCatalog map[string]rawProvider

type rawProvider struct {
	ID     string              `json:"id"`
	Name   string              `json:"name"`
	Env    []string            `json:"env"`
	Models map[string]rawModel `json:"models"`
}

type rawModel struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Limit       struct {
		Context int `json:"context"`
	} `json:"limit"`
}

// Fetch retrieves and parses the models.dev provider catalog from url.
func Fetch(ctx context.Context, client *http.Client, url string) (map[string]ProviderInfo, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, fmt.Errorf("build models.dev request: %w", err)
	}
	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("fetch models.dev catalog: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, fmt.Errorf("fetch models.dev catalog: %s", resp.Status)
	}
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read models.dev catalog: %w", err)
	}
	var raw rawCatalog
	if err := json.Unmarshal(body, &raw); err != nil {
		return nil, fmt.Errorf("parse models.dev catalog: %w", err)
	}

	providers := make(map[string]ProviderInfo, len(raw))
	for id, p := range raw {
		info := ProviderInfo{ID: id, Name: p.Name, Models: make(map[string]ModelInfo, len(p.Models))}
		if len(p.Env) > 0 {
			info.APIKeyEnv = p.Env[0]
		}
		for modelID, m := range p.Models {
			info.Models[modelID] = ModelInfo{
				ID:            modelID,
				Name:          m.Name,
				Description:   m.Description,
				ContextWindow: m.Limit.Context,
			}
		}
		providers[id] = info
	}
	return providers, nil
}

// Sync fetches the catalog from url and upserts PocketCoder's own catalog
// collections from it:
//   - providers: every fetched provider, so the Provider Keys screen always
//     has an up-to-date list to build its provider dropdown from.
//   - models + harness_models: for each harnesses row, either its one pinned
//     models_dev_provider (provider_scope == "self", e.g. Claude Code ->
//     "anthropic") or MultiProviderAllowlist (provider_scope == "any", e.g.
//     Goose/OpenCode). A harness with provider_scope == "self" and no
//     models_dev_provider set is left untouched -- nothing to sync it from.
func Sync(ctx context.Context, app core.App, client *http.Client, url string) error {
	providers, err := Fetch(ctx, client, url)
	if err != nil {
		return err
	}
	for _, p := range providers {
		if err := upsertProvider(app, p); err != nil {
			return fmt.Errorf("upsert provider %s: %w", p.ID, err)
		}
	}

	harnesses, err := app.FindAllRecords("harnesses")
	if err != nil {
		return fmt.Errorf("list harnesses: %w", err)
	}
	for _, h := range harnesses {
		var providerIDs []string
		switch h.GetString("provider_scope") {
		case "any":
			providerIDs = MultiProviderAllowlist
		default: // "self", or unset
			if pid := h.GetString("models_dev_provider"); pid != "" {
				providerIDs = []string{pid}
			}
		}
		for _, pid := range providerIDs {
			p, ok := providers[pid]
			if !ok {
				continue
			}
			for _, m := range p.Models {
				modelRec, err := upsertModel(app, p, m)
				if err != nil {
					return fmt.Errorf("upsert model %s/%s: %w", p.ID, m.ID, err)
				}
				if err := upsertHarnessModel(app, h, modelRec, m.ID); err != nil {
					return fmt.Errorf("upsert harness_model %s/%s/%s: %w", h.GetString("cli_id"), p.ID, m.ID, err)
				}
			}
		}
	}
	return nil
}

// cronJobID is the app.Cron() job name for the daily resync.
const cronJobID = "pocketcoder-model-catalog-sync"

// RegisterSync runs Sync once eagerly (detached: a slow or unreachable
// models.dev must never block startup) and schedules a daily resync via
// app.Cron(), mirroring internal/schedule's own Cron().Add usage. Call once
// from main's OnServe, after the app is otherwise ready to accept the
// resulting Saves.
func RegisterSync(app core.App) {
	sync := func() {
		defer func() {
			if r := recover(); r != nil {
				log.Printf("[ModelCatalog] sync panicked: %v", r)
			}
		}()
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()
		if err := Sync(ctx, app, http.DefaultClient, DefaultCatalogURL); err != nil {
			log.Printf("[ModelCatalog] sync failed: %v", err)
		}
	}
	go sync()
	if err := app.Cron().Add(cronJobID, "@daily", sync); err != nil {
		log.Printf("[ModelCatalog] failed to schedule daily sync: %v", err)
	}
}

func upsertProvider(app core.App, p ProviderInfo) error {
	rec, err := app.FindFirstRecordByFilter("providers", "provider_id = {:id}", map[string]any{"id": p.ID})
	if err != nil {
		coll, collErr := app.FindCollectionByNameOrId("providers")
		if collErr != nil {
			return collErr
		}
		rec = core.NewRecord(coll)
		rec.Set("provider_id", p.ID)
	}
	rec.Set("name", p.Name)
	rec.Set("api_key_env", p.APIKeyEnv)
	return app.Save(rec)
}

func upsertModel(app core.App, p ProviderInfo, m ModelInfo) (*core.Record, error) {
	rec, err := app.FindFirstRecordByFilter("models", "provider = {:p} && name = {:n}", map[string]any{"p": p.ID, "n": m.ID})
	if err != nil {
		coll, collErr := app.FindCollectionByNameOrId("models")
		if collErr != nil {
			return nil, collErr
		}
		rec = core.NewRecord(coll)
		rec.Set("provider", p.ID)
		rec.Set("name", m.ID)
	}
	rec.Set("display_name", m.Name)
	rec.Set("description", m.Description)
	rec.Set("context_window", m.ContextWindow)
	if err := app.Save(rec); err != nil {
		return nil, err
	}
	return rec, nil
}

func upsertHarnessModel(app core.App, harness, model *core.Record, harnessModelID string) error {
	rec, err := app.FindFirstRecordByFilter("harness_models", "harness = {:h} && model = {:m}", map[string]any{"h": harness.Id, "m": model.Id})
	if err != nil {
		coll, collErr := app.FindCollectionByNameOrId("harness_models")
		if collErr != nil {
			return collErr
		}
		rec = core.NewRecord(coll)
		rec.Set("harness", harness.Id)
		rec.Set("model", model.Id)
	}
	rec.Set("harness_model_id", harnessModelID)
	return app.Save(rec)
}
