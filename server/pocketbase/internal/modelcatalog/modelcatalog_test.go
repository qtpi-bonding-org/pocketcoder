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

package modelcatalog

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	_ "github.com/qtpi-bonding-org/pocketcoder/backend/pb_migrations"
)

// fixtureCatalog is a small, hand-written stand-in for models.dev's real
// api.json -- only the fields this package reads.
const fixtureCatalog = `{
  "anthropic": {
    "id": "anthropic",
    "name": "Anthropic",
    "env": ["ANTHROPIC_API_KEY"],
    "models": {
      "claude-sonnet-5": {
        "id": "claude-sonnet-5",
        "name": "Claude Sonnet 5",
        "description": "Everyday coding model",
        "limit": {"context": 1000000, "output": 128000}
      }
    }
  },
  "openai": {
    "id": "openai",
    "name": "OpenAI",
    "env": ["OPENAI_API_KEY"],
    "models": {
      "gpt-5.2": {
        "id": "gpt-5.2",
        "name": "GPT-5.2",
        "description": "General purpose model",
        "limit": {"context": 400000, "output": 128000}
      }
    }
  },
  "google": {
    "id": "google",
    "name": "Google",
    "env": ["GOOGLE_API_KEY", "GOOGLE_GENERATIVE_AI_API_KEY", "GEMINI_API_KEY"],
    "models": {}
  },
  "some-tiny-reseller": {
    "id": "some-tiny-reseller",
    "name": "Some Tiny Reseller",
    "env": ["SOME_TINY_RESELLER_API_KEY"],
    "models": {
      "reseller-model": {"id": "reseller-model", "name": "Reseller Model", "limit": {"context": 8192}}
    }
  }
}`

func fixtureServer(t *testing.T) *httptest.Server {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(fixtureCatalog))
	}))
	t.Cleanup(srv.Close)
	return srv
}

func testApp(t *testing.T) core.App {
	t.Helper()
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(app.Cleanup)
	return app
}

func TestFetchParsesProvidersAndModels(t *testing.T) {
	srv := fixtureServer(t)
	providers, err := Fetch(context.Background(), http.DefaultClient, srv.URL)
	if err != nil {
		t.Fatal(err)
	}
	if len(providers) != 4 {
		t.Fatalf("got %d providers, want 4", len(providers))
	}
	anthropic, ok := providers["anthropic"]
	if !ok {
		t.Fatal("missing anthropic provider")
	}
	if anthropic.PrimaryAPIKeyEnv() != "ANTHROPIC_API_KEY" {
		t.Errorf("anthropic.PrimaryAPIKeyEnv() = %q, want ANTHROPIC_API_KEY", anthropic.PrimaryAPIKeyEnv())
	}
	model, ok := anthropic.Models["claude-sonnet-5"]
	if !ok {
		t.Fatal("missing claude-sonnet-5 model")
	}
	if model.ContextWindow != 1000000 {
		t.Errorf("ContextWindow = %d, want 1000000", model.ContextWindow)
	}

	// Google is exactly the motivating case: models.dev lists three
	// accepted names, not one -- PrimaryAPIKeyEnv is env[0] for display,
	// but APIKeyEnvs must keep all three so renderEnv can inject every one
	// rather than guess which single name a given harness actually reads.
	google := providers["google"]
	if google.PrimaryAPIKeyEnv() != "GOOGLE_API_KEY" {
		t.Errorf("google.PrimaryAPIKeyEnv() = %q, want GOOGLE_API_KEY (env[0])", google.PrimaryAPIKeyEnv())
	}
	wantGoogleEnvs := []string{"GOOGLE_API_KEY", "GOOGLE_GENERATIVE_AI_API_KEY", "GEMINI_API_KEY"}
	if len(google.APIKeyEnvs) != len(wantGoogleEnvs) {
		t.Fatalf("google.APIKeyEnvs = %v, want %v", google.APIKeyEnvs, wantGoogleEnvs)
	}
	for i, want := range wantGoogleEnvs {
		if google.APIKeyEnvs[i] != want {
			t.Errorf("google.APIKeyEnvs[%d] = %q, want %q", i, google.APIKeyEnvs[i], want)
		}
	}
}

func TestSyncUpsertsAllProvidersRegardlessOfHarnessUsage(t *testing.T) {
	app := testApp(t)
	srv := fixtureServer(t)
	if err := Sync(context.Background(), app, http.DefaultClient, srv.URL); err != nil {
		t.Fatal(err)
	}
	// The provider cache is meant to back the Provider Keys dropdown fully --
	// including a provider no seeded harness happens to use yet.
	rec, err := app.FindFirstRecordByFilter("providers", "provider_id = 'some-tiny-reseller'", nil)
	if err != nil {
		t.Fatalf("expected some-tiny-reseller in the providers cache: %v", err)
	}
	if rec.GetString("api_key_env") != "SOME_TINY_RESELLER_API_KEY" {
		t.Errorf("api_key_env = %q, want SOME_TINY_RESELLER_API_KEY", rec.GetString("api_key_env"))
	}
}

func TestSyncPopulatesModelsForSelfScopedHarnessFromItsPinnedProviderEdge(t *testing.T) {
	app := testApp(t)
	srv := fixtureServer(t)
	if err := Sync(context.Background(), app, http.DefaultClient, srv.URL); err != nil {
		t.Fatal(err)
	}
	codex, err := app.FindFirstRecordByFilter("harnesses", "cli_id = 'codex'", nil)
	if err != nil {
		t.Fatal(err)
	}
	openai, err := app.FindFirstRecordByFilter("providers", "provider_id = 'openai'", nil)
	if err != nil {
		t.Fatal(err)
	}
	edge, err := app.FindFirstRecordByFilter("harness_providers", "harness = {:h} && provider = {:p}", map[string]any{"h": codex.Id, "p": openai.Id})
	if err != nil {
		t.Fatalf("expected the seeded pinned edge to still exist after a sync: %v", err)
	}
	if !edge.GetBool("is_pinned") {
		t.Error("sync must never clear is_pinned on an existing pinned edge")
	}
	hms, err := app.FindRecordsByFilter("harness_models", "harness = {:h}", "", 0, 0, map[string]any{"h": codex.Id})
	if err != nil {
		t.Fatal(err)
	}
	if len(hms) != 1 || hms[0].GetString("harness_model_id") != "gpt-5.2" {
		t.Errorf("harness_models for codex = %+v, want exactly one row for gpt-5.2", hms)
	}
}

func TestSyncFansOutOnProviderFanoutFlagNotLegacyProviderScope(t *testing.T) {
	app := testApp(t)
	coll, err := app.FindCollectionByNameOrId("harnesses")
	if err != nil {
		t.Fatal(err)
	}
	future := core.NewRecord(coll)
	future.Set("name", "Future Fanout Harness")
	future.Set("cli_id", "future-fanout-harness")
	future.Set("acp_transport", "stdio")
	future.Set("provider_fanout", true)
	if err := app.Save(future); err != nil {
		t.Fatal(err)
	}
	srv := fixtureServer(t)
	if err := Sync(context.Background(), app, http.DefaultClient, srv.URL); err != nil {
		t.Fatal(err)
	}
	hms, err := app.FindRecordsByFilter("harness_models", "harness = {:h}", "", 0, 0, map[string]any{"h": future.Id})
	if err != nil {
		t.Fatal(err)
	}
	if len(hms) != 3 {
		t.Fatalf("got %d harness_models, want 3 (every fetched provider's models)", len(hms))
	}
}

// TestSyncPopulatesModelsForAnyScopedHarnessFromEveryProvider verifies a
// multi-provider harness draws from every fetched provider, not a
// PocketCoder-curated subset -- Goose and OpenCode both already let a user
// pick from models.dev's full catalog themselves, so there's no principled
// place to cut it down; the client's own picker is expected to offer
// search/filtering over the full list instead.
func TestSyncPopulatesModelsForAnyScopedHarnessFromEveryProvider(t *testing.T) {
	app := testApp(t)
	srv := fixtureServer(t)
	if err := Sync(context.Background(), app, http.DefaultClient, srv.URL); err != nil {
		t.Fatal(err)
	}
	goose, err := app.FindFirstRecordByFilter("harnesses", "cli_id = 'goose'", nil)
	if err != nil {
		t.Fatal(err)
	}
	hms, err := app.FindRecordsByFilter("harness_models", "harness = {:h}", "", 0, 0, map[string]any{"h": goose.Id})
	if err != nil {
		t.Fatal(err)
	}
	// anthropic (1) + openai (1) + some-tiny-reseller (1); google has none
	// in the fixture.
	if len(hms) != 3 {
		t.Fatalf("got %d harness_models for goose, want 3 (every fetched provider's models, including the reseller)", len(hms))
	}
	found := map[string]bool{}
	for _, hm := range hms {
		found[hm.GetString("harness_model_id")] = true
	}
	for _, want := range []string{"claude-sonnet-5", "gpt-5.2", "reseller-model"} {
		if !found[want] {
			t.Errorf("harness_models for goose = %v, missing %q", found, want)
		}
	}
}

func TestSyncPrefixesOpenCodeModelIdsWithProviderButNotGoose(t *testing.T) {
	app := testApp(t)
	srv := fixtureServer(t)
	if err := Sync(context.Background(), app, http.DefaultClient, srv.URL); err != nil {
		t.Fatal(err)
	}
	anthropic, err := app.FindFirstRecordByFilter("providers", "provider_id = 'anthropic'", nil)
	if err != nil {
		t.Fatal(err)
	}
	model, err := app.FindFirstRecordByFilter("models", "provider = {:p} && name = 'claude-sonnet-5'", map[string]any{"p": anthropic.Id})
	if err != nil {
		t.Fatal(err)
	}

	opencode, err := app.FindFirstRecordByFilter("harnesses", "cli_id = 'opencode'", nil)
	if err != nil {
		t.Fatal(err)
	}
	opencodeHM, err := app.FindFirstRecordByFilter("harness_models", "harness = {:h} && model = {:m}", map[string]any{"h": opencode.Id, "m": model.Id})
	if err != nil {
		t.Fatal(err)
	}
	if got, want := opencodeHM.GetString("harness_model_id"), "anthropic/claude-sonnet-5"; got != want {
		t.Errorf("opencode harness_model_id = %q, want %q", got, want)
	}

	goose, err := app.FindFirstRecordByFilter("harnesses", "cli_id = 'goose'", nil)
	if err != nil {
		t.Fatal(err)
	}
	gooseHM, err := app.FindFirstRecordByFilter("harness_models", "harness = {:h} && model = {:m}", map[string]any{"h": goose.Id, "m": model.Id})
	if err != nil {
		t.Fatal(err)
	}
	if got, want := gooseHM.GetString("harness_model_id"), "claude-sonnet-5"; got != want {
		t.Errorf("goose harness_model_id = %q, want %q (unprefixed)", got, want)
	}
}

func TestHarnessModelIDDoesNotDoublePrefixAlreadyPrefixedID(t *testing.T) {
	app := testApp(t)
	coll, err := app.FindCollectionByNameOrId("harnesses")
	if err != nil {
		t.Fatal(err)
	}
	opencode := core.NewRecord(coll)
	opencode.Set("name", "OpenCode")
	opencode.Set("cli_id", "opencode")
	opencode.Set("acp_transport", "stdio")
	if got, want := harnessModelID(opencode, "anthropic", "anthropic/claude-sonnet-5"), "anthropic/claude-sonnet-5"; got != want {
		t.Errorf("harnessModelID = %q, want %q (no double prefix)", got, want)
	}
}

// TestSyncCoversAnyFutureAnyScopedHarnessNotJustGooseOrOpenCode proves the
// sync isn't special-cased to today's two multi-provider harnesses: it
// keys purely off harnesses.provider_fanout, so a brand-new harness seeded
// with provider_fanout=true (never mentioned anywhere in this package)
// gets the exact same full-catalog treatment automatically.
func TestSyncCoversAnyFutureAnyScopedHarnessNotJustGooseOrOpenCode(t *testing.T) {
	app := testApp(t)
	coll, err := app.FindCollectionByNameOrId("harnesses")
	if err != nil {
		t.Fatal(err)
	}
	future := core.NewRecord(coll)
	future.Set("name", "Future Agnostic Harness")
	future.Set("cli_id", "future-agnostic-harness")
	future.Set("acp_transport", "stdio")
	future.Set("provider_fanout", true)
	if err := app.Save(future); err != nil {
		t.Fatal(err)
	}

	srv := fixtureServer(t)
	if err := Sync(context.Background(), app, http.DefaultClient, srv.URL); err != nil {
		t.Fatal(err)
	}

	hms, err := app.FindRecordsByFilter("harness_models", "harness = {:h}", "", 0, 0, map[string]any{"h": future.Id})
	if err != nil {
		t.Fatal(err)
	}
	if len(hms) != 3 {
		t.Fatalf("got %d harness_models for the new any-scoped harness, want 3, same as Goose/OpenCode get", len(hms))
	}
}

func TestSyncIsIdempotent(t *testing.T) {
	app := testApp(t)
	srv := fixtureServer(t)
	if err := Sync(context.Background(), app, http.DefaultClient, srv.URL); err != nil {
		t.Fatal(err)
	}
	if err := Sync(context.Background(), app, http.DefaultClient, srv.URL); err != nil {
		t.Fatal(err)
	}
	providers, err := app.FindRecordsByFilter("providers", "", "", 0, 0, nil)
	if err != nil {
		t.Fatal(err)
	}
	if len(providers) != 4 {
		t.Fatalf("got %d providers after two syncs, want 4 (re-sync must update, not duplicate)", len(providers))
	}
	models, err := app.FindRecordsByFilter("models", "", "", 0, 0, nil)
	if err != nil {
		t.Fatal(err)
	}
	if len(models) != 3 {
		t.Fatalf("got %d models after two syncs, want 3 (claude-sonnet-5, gpt-5.2, reseller-model)", len(models))
	}
}

// TestSyncSkipsSavingUnchangedRows verifies recordUnchanged actually
// prevents a no-op re-Save: with curation removed, a full sync now touches
// several thousand rows, and unconditionally re-Saving all of them on
// every run (startup + every 6h) would mean that many writes against
// SQLite's single writer for no reason when models.dev simply hasn't
// changed since the last sync. providers/models/harness_models have no
// created/updated autodate fields to compare (matching every sibling
// collection), so this counts actual PocketBase save events directly via
// OnModelAfterCreateSuccess/OnModelAfterUpdateSuccess rather than
// inferring "did a Save happen" from a timestamp.
func TestSyncSkipsSavingUnchangedRows(t *testing.T) {
	app := testApp(t)
	srv := fixtureServer(t)
	if err := Sync(context.Background(), app, http.DefaultClient, srv.URL); err != nil {
		t.Fatal(err)
	}

	var saves int
	countSave := func(e *core.ModelEvent) error {
		saves++
		return e.Next()
	}
	app.OnModelAfterCreateSuccess("providers", "models", "harness_models").BindFunc(countSave)
	app.OnModelAfterUpdateSuccess("providers", "models", "harness_models").BindFunc(countSave)

	if err := Sync(context.Background(), app, http.DefaultClient, srv.URL); err != nil {
		t.Fatal(err)
	}
	if saves != 0 {
		t.Errorf("re-sync with identical upstream data triggered %d Save(s), want 0 -- an unchanged row must not be re-Saved", saves)
	}
}

// smallerFixtureServer serves a catalog missing "some-tiny-reseller" (and
// its model), simulating that provider disappearing from models.dev
// between syncs.
func smallerFixtureServer(t *testing.T) *httptest.Server {
	t.Helper()
	const shrunk = `{
		"anthropic": {
			"id": "anthropic", "name": "Anthropic", "env": ["ANTHROPIC_API_KEY"],
			"models": {"claude-sonnet-5": {"id": "claude-sonnet-5", "name": "Claude Sonnet 5", "limit": {"context": 1000000}}}
		},
		"openai": {
			"id": "openai", "name": "OpenAI", "env": ["OPENAI_API_KEY"],
			"models": {"gpt-5.2": {"id": "gpt-5.2", "name": "GPT-5.2", "limit": {"context": 400000}}}
		}
	}`
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(shrunk))
	}))
	t.Cleanup(srv.Close)
	return srv
}

// TestSyncNeverDeletesRowsForProvidersRemovedUpstream is the invariant this
// package is built on: a provider or model disappearing from models.dev
// must not cascade into deleting a harness_models row a user's
// chat.harness_model_override may still reference. Sync is strictly
// additive -- upsert only, no delete/reconcile step -- so a stale row
// lingering forever is the correct, safe behavior here, not a gap to close.
func TestSyncNeverDeletesRowsForProvidersRemovedUpstream(t *testing.T) {
	app := testApp(t)
	full := fixtureServer(t)
	if err := Sync(context.Background(), app, http.DefaultClient, full.URL); err != nil {
		t.Fatal(err)
	}
	if _, err := app.FindFirstRecordByFilter("providers", "provider_id = 'some-tiny-reseller'", nil); err != nil {
		t.Fatal("precondition failed: some-tiny-reseller should exist after the first sync")
	}

	shrunk := smallerFixtureServer(t)
	if err := Sync(context.Background(), app, http.DefaultClient, shrunk.URL); err != nil {
		t.Fatal(err)
	}

	if _, err := app.FindFirstRecordByFilter("providers", "provider_id = 'some-tiny-reseller'", nil); err != nil {
		t.Error("some-tiny-reseller provider row was deleted after it disappeared upstream -- Sync must never delete")
	}
	if _, err := app.FindFirstRecordByFilter("models", "name = 'reseller-model'", nil); err != nil {
		t.Error("reseller-model row was deleted after its provider disappeared upstream -- Sync must never delete")
	}
	goose, err := app.FindFirstRecordByFilter("harnesses", "cli_id = 'goose'", nil)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := app.FindFirstRecordByFilter("harness_models", "harness = {:h} && harness_model_id = 'reseller-model'", map[string]any{"h": goose.Id}); err != nil {
		t.Error("goose's harness_models row for reseller-model was deleted -- this would break any chat.harness_model_override still pointing at it")
	}
}

// An empty model id (the map key models.dev keys each model by) fails
// models.name's required-field validation.
func malformedModelFixtureServer(t *testing.T) *httptest.Server {
	t.Helper()
	const malformed = `{
		"anthropic": {
			"id": "anthropic", "name": "Anthropic", "env": ["ANTHROPIC_API_KEY"],
			"models": {
				"": {"id": "", "name": "Broken Model", "limit": {"context": 1}},
				"claude-sonnet-5": {"id": "claude-sonnet-5", "name": "Claude Sonnet 5", "limit": {"context": 1000000}}
			}
		}
	}`
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(malformed))
	}))
	t.Cleanup(srv.Close)
	return srv
}

// A row's Save error must never propagate out of the per-harness
// transaction callback, or it would roll back every already-upserted
// good row in that harness's batch along with the one bad row.
func TestSyncSkipsOneMalformedRowWithoutAbortingRestOfHarnessBatch(t *testing.T) {
	app := testApp(t)
	srv := malformedModelFixtureServer(t)

	if err := Sync(context.Background(), app, http.DefaultClient, srv.URL); err != nil {
		t.Fatal(err)
	}

	if _, err := app.FindFirstRecordByFilter("models", "name = 'claude-sonnet-5'", nil); err != nil {
		t.Error("well-formed sibling model was not saved -- a malformed row must not abort the rest of the batch")
	}
	if _, err := app.FindFirstRecordByFilter("models", "name = ''", nil); err == nil {
		t.Error("malformed (empty-id) model was saved despite failing required-field validation")
	}
}
