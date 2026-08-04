package api

import (
	"testing"

	"github.com/pocketbase/pocketbase/tests"
	_ "github.com/qtpi-automaton/pocketcoder/backend/pb_migrations"
)

func TestSyncOllamaModelsLinksInstalledModelToGooseAndOpenCode(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(app.Cleanup)

	installed := []ollamaModel{{Name: "qwen3:0.6b", Size: 523 * 1024 * 1024}}
	if err := syncOllamaModels(app, installed); err != nil {
		t.Fatal(err)
	}
	// Reconciliation is safe to call after every completed pull/refresh.
	if err := syncOllamaModels(app, installed); err != nil {
		t.Fatal(err)
	}

	models, err := app.FindRecordsByFilter(
		"models",
		"provider = 'ollama' && name = 'qwen3:0.6b'",
		"",
		0,
		0,
	)
	if err != nil || len(models) != 1 {
		t.Fatalf("local model records = %d, err = %v; want exactly one", len(models), err)
	}
	links, err := app.FindRecordsByFilter(
		"harness_models",
		"model = {:model}",
		"",
		0,
		0,
		map[string]any{"model": models[0].Id},
	)
	if err != nil {
		t.Fatal(err)
	}
	if len(links) != 2 {
		t.Fatalf("local model links = %d, want Goose + OpenCode", len(links))
	}
}
