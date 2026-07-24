package hooks_test

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/hooks"
)

func TestRenderCogneeConfigWritesEnvFile(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	dir := t.TempDir()
	hooks.SetCogneeConfigDirForTest(dir)
	defer hooks.SetCogneeConfigDirForTest("/cognee-config")

	coll, err := app.FindCollectionByNameOrId("cognee_config")
	if err != nil {
		t.Fatal(err)
	}
	rec := core.NewRecord(coll)
	rec.Set("llm_provider", "openai")
	rec.Set("llm_model", "gpt-4o-mini")
	rec.Set("llm_base_url", "")
	rec.Set("llm_api_key", "sk-test-123")
	if err := app.Save(rec); err != nil {
		t.Fatal(err)
	}

	hooks.RegisterCogneeConfigHooks(app)

	envPath := filepath.Join(dir, "cognee.env")
	data, err := os.ReadFile(envPath)
	if err != nil {
		t.Fatalf("cognee.env not written: %v", err)
	}
	content := string(data)
	for _, want := range []string{"LLM_PROVIDER=openai", "LLM_MODEL=gpt-4o-mini", "LLM_API_KEY=sk-test-123"} {
		if !contains(content, want) {
			t.Errorf("cognee.env missing %q, got:\n%s", want, content)
		}
	}
}

func contains(haystack, needle string) bool {
	return len(haystack) >= len(needle) && (func() bool {
		for i := 0; i+len(needle) <= len(haystack); i++ {
			if haystack[i:i+len(needle)] == needle {
				return true
			}
		}
		return false
	})()
}
