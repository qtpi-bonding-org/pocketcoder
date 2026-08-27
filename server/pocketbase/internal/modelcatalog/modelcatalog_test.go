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
	if anthropic.APIKeyEnv != "ANTHROPIC_API_KEY" {
		t.Errorf("anthropic.APIKeyEnv = %q, want ANTHROPIC_API_KEY", anthropic.APIKeyEnv)
	}
	model, ok := anthropic.Models["claude-sonnet-5"]
	if !ok {
		t.Fatal("missing claude-sonnet-5 model")
	}
	if model.ContextWindow != 1000000 {
		t.Errorf("ContextWindow = %d, want 1000000", model.ContextWindow)
	}

	google := providers["google"]
	if google.APIKeyEnv != "GOOGLE_API_KEY" {
		t.Errorf("google.APIKeyEnv = %q, want GOOGLE_API_KEY (env[0]), not one of its alternates", google.APIKeyEnv)
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

func TestSyncPopulatesModelsForSelfScopedHarnessFromItsPinnedProvider(t *testing.T) {
	app := testApp(t)
	srv := fixtureServer(t)
	if err := Sync(context.Background(), app, http.DefaultClient, srv.URL); err != nil {
		t.Fatal(err)
	}
	codex, err := app.FindFirstRecordByFilter("harnesses", "cli_id = 'codex'", nil)
	if err != nil {
		t.Fatal(err)
	}
	if codex.GetString("models_dev_provider") != "openai" {
		t.Fatalf("codex.models_dev_provider = %q, want openai (seed data)", codex.GetString("models_dev_provider"))
	}
	hms, err := app.FindRecordsByFilter("harness_models", "harness = {:h}", "", 0, 0, map[string]any{"h": codex.Id})
	if err != nil {
		t.Fatal(err)
	}
	if len(hms) != 1 {
		t.Fatalf("got %d harness_models for codex, want 1 (only its pinned openai provider's model)", len(hms))
	}
	if hms[0].GetString("harness_model_id") != "gpt-5.2" {
		t.Errorf("harness_model_id = %q, want gpt-5.2", hms[0].GetString("harness_model_id"))
	}
}

func TestSyncPopulatesModelsForAnyScopedHarnessFromTheAllowlist(t *testing.T) {
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
	// anthropic (1 model) + openai (1 model) from the allowlist; google has
	// none in the fixture and some-tiny-reseller isn't on the allowlist.
	if len(hms) != 2 {
		t.Fatalf("got %d harness_models for goose, want 2 (anthropic + openai models, not the reseller)", len(hms))
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
	if len(models) != 2 {
		t.Fatalf("got %d models after two syncs, want 2 (claude-sonnet-5, gpt-5.2)", len(models))
	}
}
