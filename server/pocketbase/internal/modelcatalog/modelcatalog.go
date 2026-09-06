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
// accepts GOOGLE_API_KEY, GOOGLE_GENERATIVE_AI_API_KEY, or GEMINI_API_KEY --
// this package keeps and injects all three instead of guessing which one a
// given harness actually reads).
//
// Sync is strictly additive: it only ever creates or updates rows, never
// deletes. A model or provider disappearing upstream must not cascade into
// deleting a harness_models row a user's chat.harness_model_override still
// points at -- a stale row lingering forever is harmless; deleting it out
// from under existing user data is not.
package modelcatalog

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/pocketbase/pocketbase/core"
)

// DefaultCatalogURL is models.dev's published catalog endpoint -- the same
// one OpenCode fetches at startup and Goose's Canonical Model Registry is
// compiled from.
const DefaultCatalogURL = "https://models.dev/api.json"

// ProviderInfo is the trimmed shape of one models.dev provider entry --
// only the fields PocketCoder actually needs, decoded defensively so
// unrelated upstream schema growth (pricing, capability flags, etc.) never
// breaks this sync.
type ProviderInfo struct {
	ID   string
	Name string
	// APIKeyEnvs lists every env var name models.dev says this provider's
	// SDK accepts (its raw "env" array), e.g. Google's three alternates.
	// Which one a given *harness* actually reads is not something
	// models.dev encodes -- renderEnv (harness_provision.go) sets all of
	// them to the same value rather than guess a single "the" name.
	APIKeyEnvs []string
	Models     map[string]ModelInfo
}

// PrimaryAPIKeyEnv is APIKeyEnvs[0] (models.dev's own preferred name),
// empty if the provider declares no env var at all (e.g. a local-only
// backend like Ollama or a project-scoped credential like Vertex).
func (p ProviderInfo) PrimaryAPIKeyEnv() string {
	if len(p.APIKeyEnvs) == 0 {
		return ""
	}
	return p.APIKeyEnvs[0]
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
		info := ProviderInfo{ID: id, Name: p.Name, APIKeyEnvs: p.Env, Models: make(map[string]ModelInfo, len(p.Models))}
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
//   - models + harness_models: for each harnesses row, either its pinned
//     harness_providers edge (provider_fanout == false) or every fetched
//     provider (provider_fanout == true, e.g.
//     Goose/OpenCode -- both already let a user pick from models.dev's full
//     catalog themselves, so there is no principled place to cut it down;
//     the resulting few thousand rows are trivial for SQLite, and the
//     client's own picker is expected to offer search/filtering rather than
//     PocketCoder pre-curating the list). A self-scoped harness with no
//     harness_providers edge is left untouched -- nothing to sync it from.
//
// A single malformed upstream row is logged and skipped, not fatal to the
// rest of the sync: models.dev is an external, community-edited registry,
// and one bad entry must not leave every provider after it (in
// nondeterministic map-iteration order) unsynced. ctx is checked between
// each unit of work so a cancelled sync actually stops promptly instead of
// grinding through the full catalog regardless.
func Sync(ctx context.Context, app core.App, client *http.Client, url string) error {
	providers, err := Fetch(ctx, client, url)
	if err != nil {
		return err
	}
	for _, p := range providers {
		if ctx.Err() != nil {
			return ctx.Err()
		}
		if err := upsertProvider(app, p); err != nil {
			log.Printf("[ModelCatalog] skipping provider %s: %v", p.ID, err)
		}
	}

	// Synced independently of the harness loop below: a provider reachable
	// only via an unkeyed fanout harness would otherwise never get a
	// `models` row.
	for _, p := range providers {
		if ctx.Err() != nil {
			return ctx.Err()
		}
		providerRec, err := app.FindFirstRecordByFilter("providers", "provider_id = {:id}", map[string]any{"id": p.ID})
		if err != nil {
			continue
		}
		for _, m := range p.Models {
			if _, err := upsertModel(app, providerRec, p, m); err != nil {
				log.Printf("[ModelCatalog] skipping model %s/%s: %v", p.ID, m.ID, err)
			}
		}
	}

	// A fanout harness only gets harness_models rows for providers this
	// deployment actually has a credential for, not every models.dev
	// provider -- see SyncProviderForFanoutHarnesses for the on-demand path.
	keyed, err := keyedProviderIDs(app)
	if err != nil {
		return fmt.Errorf("resolve keyed providers: %w", err)
	}

	harnesses, err := app.FindAllRecords("harnesses")
	if err != nil {
		return fmt.Errorf("list harnesses: %w", err)
	}
	for _, h := range harnesses {
		if ctx.Err() != nil {
			return ctx.Err()
		}
		var providerIDs []string
		if h.GetBool("provider_fanout") {
			for pid := range providers {
				if !keyed[pid] {
					continue
				}
				providerIDs = append(providerIDs, pid)
			}
		} else {
			edges, err := app.FindRecordsByFilter("harness_providers", "harness = {:h}", "", 0, 0, map[string]any{"h": h.Id})
			if err != nil {
				return fmt.Errorf("list harness_providers for %s: %w", h.GetString("cli_id"), err)
			}
			for _, edge := range edges {
				providerRec, err := app.FindRecordById("providers", edge.GetString("provider"))
				if err != nil {
					continue
				}
				providerIDs = append(providerIDs, providerRec.GetString("provider_id"))
			}
		}
		// One transaction per harness, not one commit per row -- avoids
		// thousands of individual SQLite single-writer commits. Row errors
		// are only logged/skipped, never returned, so one bad row can't
		// roll back the rest of the harness's batch.
		if err := app.RunInTransaction(func(txApp core.App) error {
			for _, pid := range providerIDs {
				p, ok := providers[pid]
				if !ok {
					continue
				}
				if ctx.Err() != nil {
					return ctx.Err()
				}
				providerRec, err := txApp.FindFirstRecordByFilter("providers", "provider_id = {:id}", map[string]any{"id": pid})
				if err != nil {
					continue
				}
				syncHarnessProvider(txApp, h, providerRec, p)
			}
			return nil
		}); err != nil {
			return err
		}
	}
	return nil
}

func syncHarnessProvider(txApp core.App, h, providerRec *core.Record, p ProviderInfo) {
	if h.GetBool("provider_fanout") {
		if err := upsertHarnessProviderEdge(txApp, h, providerRec); err != nil {
			log.Printf("[ModelCatalog] skipping harness_providers edge %s/%s: %v", h.GetString("cli_id"), p.ID, err)
		}
	}
	for _, m := range p.Models {
		modelRec, err := upsertModel(txApp, providerRec, p, m)
		if err != nil {
			log.Printf("[ModelCatalog] skipping model %s/%s: %v", p.ID, m.ID, err)
			continue
		}
		if err := upsertHarnessModel(txApp, h, modelRec, harnessModelID(h, p.ID, m.ID)); err != nil {
			log.Printf("[ModelCatalog] skipping harness_model %s/%s/%s: %v", h.GetString("cli_id"), p.ID, m.ID, err)
		}
	}
}

// keyedProviderIDs is unscoped by owner: a deployment belongs to exactly
// one user.
func keyedProviderIDs(app core.App) (map[string]bool, error) {
	keyed := map[string]bool{}
	addProviderRefs := func(collection string) error {
		recs, err := app.FindAllRecords(collection)
		if err != nil {
			return fmt.Errorf("list %s: %w", collection, err)
		}
		for _, r := range recs {
			providerRec, err := app.FindRecordById("providers", r.GetString("provider"))
			if err != nil {
				continue
			}
			keyed[providerRec.GetString("provider_id")] = true
		}
		return nil
	}
	if err := addProviderRefs("provider_api_keys"); err != nil {
		return nil, err
	}
	if err := addProviderRefs("credential_selections"); err != nil {
		return nil, err
	}
	return keyed, nil
}

func SyncProviderForFanoutHarnesses(ctx context.Context, app core.App, client *http.Client, url string, providerID string) error {
	providers, err := Fetch(ctx, client, url)
	if err != nil {
		return err
	}
	p, ok := providers[providerID]
	if !ok {
		return fmt.Errorf("provider %q not found in models.dev catalog", providerID)
	}
	if err := upsertProvider(app, p); err != nil {
		return fmt.Errorf("upsert provider %s: %w", providerID, err)
	}
	providerRec, err := app.FindFirstRecordByFilter("providers", "provider_id = {:id}", map[string]any{"id": providerID})
	if err != nil {
		return fmt.Errorf("find provider %s: %w", providerID, err)
	}
	harnesses, err := app.FindRecordsByFilter("harnesses", "provider_fanout = true", "", 0, 0, nil)
	if err != nil {
		return fmt.Errorf("list fanout harnesses: %w", err)
	}
	for _, h := range harnesses {
		if err := app.RunInTransaction(func(txApp core.App) error {
			syncHarnessProvider(txApp, h, providerRec, p)
			return nil
		}); err != nil {
			return err
		}
	}
	return nil
}

func RegisterCredentialHooks(app core.App, client *http.Client, url string) {
	syncByProviderRecordID := func(providerRecID string) {
		providerRec, err := app.FindRecordById("providers", providerRecID)
		if err != nil {
			log.Printf("[ModelCatalog] credential hook: find provider %s: %v", providerRecID, err)
			return
		}
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()
		if err := SyncProviderForFanoutHarnesses(ctx, app, client, url, providerRec.GetString("provider_id")); err != nil {
			log.Printf("[ModelCatalog] credential hook: sync provider %s: %v", providerRec.GetString("provider_id"), err)
		}
	}
	app.OnRecordAfterCreateSuccess("provider_api_keys").BindFunc(func(e *core.RecordEvent) error {
		syncByProviderRecordID(e.Record.GetString("provider"))
		return e.Next()
	})
	app.OnRecordAfterCreateSuccess("credential_selections").BindFunc(func(e *core.RecordEvent) error {
		syncByProviderRecordID(e.Record.GetString("provider"))
		return e.Next()
	})
}

// cronJobID is the app.Cron() job name for the periodic resync.
const cronJobID = "pocketcoder-model-catalog-sync"

// syncEvery6Hours runs the resync at :00 past every 6th hour.
const syncEvery6Hours = "0 */6 * * *"

// RegisterSync runs Sync once eagerly (detached: a slow or unreachable
// models.dev must never block startup) and schedules a resync every 6
// hours via app.Cron(), mirroring internal/schedule's own Cron().Add usage.
// Call once from main's OnServe, after the app is otherwise ready to accept
// the resulting Saves.
func RegisterSync(app core.App) {
	sync := func() {
		defer func() {
			if r := recover(); r != nil {
				log.Printf("[ModelCatalog] sync panicked: %v", r)
			}
		}()
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
		defer cancel()
		if err := Sync(ctx, app, http.DefaultClient, DefaultCatalogURL); err != nil {
			log.Printf("[ModelCatalog] sync failed: %v", err)
		}
	}
	go sync()
	if err := app.Cron().Add(cronJobID, syncEvery6Hours, sync); err != nil {
		log.Printf("[ModelCatalog] failed to schedule periodic sync: %v", err)
	}
}

// recordUnchanged reports whether every (key, value) in fields already
// matches rec's current stored value, so upsert* can skip a no-op Save.
// With curation removed, a full sync now touches several thousand rows;
// unconditionally re-Saving all of them on every run (startup + every 6h)
// would mean that many writes against SQLite's single writer for no
// reason on every sync where models.dev simply hasn't changed.
//
// Comparison goes through json.Marshal rather than fmt.Sprintf("%v", ...):
// a freshly computed Go value (e.g. int(1000000)) and the same value
// fetched back from PocketBase's storage layer (e.g. float64(1000000) for
// a "number" field) format completely differently under %v ("1000000" vs
// "1e+06"), which made this always report "changed" for numeric and JSON
// fields specifically -- json.Marshal normalizes both to the same bytes
// regardless of which concrete Go type carries the value.
func recordUnchanged(rec *core.Record, fields map[string]any) bool {
	for k, v := range fields {
		current, err := json.Marshal(rec.Get(k))
		if err != nil {
			return false
		}
		want, err := json.Marshal(v)
		if err != nil {
			return false
		}
		if string(current) != string(want) {
			return false
		}
	}
	return true
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
	fields := map[string]any{
		"name":         p.Name,
		"api_key_env":  p.PrimaryAPIKeyEnv(),
		"api_key_envs": p.APIKeyEnvs,
	}
	if recordUnchanged(rec, fields) {
		return nil
	}
	rec.Set("name", fields["name"])
	rec.Set("api_key_env", fields["api_key_env"])
	rec.Set("api_key_envs", fields["api_key_envs"])
	rec.Set("synced_at", time.Now().UTC())
	return app.Save(rec)
}

func upsertHarnessProviderEdge(app core.App, harness, provider *core.Record) error {
	rec, err := app.FindFirstRecordByFilter("harness_providers", "harness = {:h} && provider = {:p}", map[string]any{"h": harness.Id, "p": provider.Id})
	if err == nil {
		return nil
	}
	coll, collErr := app.FindCollectionByNameOrId("harness_providers")
	if collErr != nil {
		return collErr
	}
	rec = core.NewRecord(coll)
	rec.Set("harness", harness.Id)
	rec.Set("provider", provider.Id)
	rec.Set("is_pinned", false)
	return app.Save(rec)
}

func upsertModel(app core.App, providerRec *core.Record, p ProviderInfo, m ModelInfo) (*core.Record, error) {
	rec, err := app.FindFirstRecordByFilter("models", "provider = {:p} && name = {:n}", map[string]any{"p": providerRec.Id, "n": m.ID})
	if err != nil {
		coll, collErr := app.FindCollectionByNameOrId("models")
		if collErr != nil {
			return nil, collErr
		}
		rec = core.NewRecord(coll)
		rec.Set("provider", providerRec.Id)
		rec.Set("name", m.ID)
	}
	fields := map[string]any{
		"display_name":   m.Name,
		"description":    m.Description,
		"context_window": m.ContextWindow,
	}
	if !recordUnchanged(rec, fields) {
		rec.Set("display_name", fields["display_name"])
		rec.Set("description", fields["description"])
		rec.Set("context_window", fields["context_window"])
		if err := app.Save(rec); err != nil {
			return nil, err
		}
	}
	return rec, nil
}

const opencodeCliID = "opencode"

// harnessModelID computes the model identifier a given harness's ACP
// session/set_config_option call actually needs. OpenCode always addresses
// a model as "<providerID>/<modelID>"; other harnesses use the bare
// models.dev id directly.
func harnessModelID(harness *core.Record, providerID, modelID string) string {
	if harness.GetString("cli_id") != opencodeCliID {
		return modelID
	}
	prefix := providerID + "/"
	if strings.HasPrefix(modelID, prefix) {
		return modelID
	}
	return prefix + modelID
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
	if recordUnchanged(rec, map[string]any{"harness_model_id": harnessModelID}) {
		return nil
	}
	rec.Set("harness_model_id", harnessModelID)
	return app.Save(rec)
}
