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

	// Register hooks BEFORE saving the record: RegisterCogneeConfigHooks only
	// renders synchronously via app.OnServe() (never fired here, matching
	// production — see cognee_config.go's comment on why this must not run
	// before app.Bootstrap()/migrations, which OnServe is guaranteed to be
	// after but a bare RegisterCogneeConfigHooks(app) call is not). The
	// CRUD hook (OnRecordAfterCreateSuccess) is what actually exercises
	// renderCogneeConfig in this test, exactly as it will fire in
	// production when a real cognee_config row is created after startup.
	hooks.RegisterCogneeConfigHooks(app)

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
