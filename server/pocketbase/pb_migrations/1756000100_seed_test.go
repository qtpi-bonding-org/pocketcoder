package pb_migrations_test

import (
	"os"
	"testing"

	"github.com/pocketbase/pocketbase/tests"
	_ "github.com/qtpi-automaton/pocketcoder/backend/pb_migrations"
)

func TestSeedCreatesAdminAgentAndSuperuser(t *testing.T) {
	os.Setenv("POCKETBASE_ADMIN_EMAIL", "admin@example.com")
	os.Setenv("POCKETBASE_ADMIN_PASSWORD", "adminpass123")
	os.Setenv("AGENT_EMAIL", "agent@example.com")
	os.Setenv("AGENT_PASSWORD", "agentpass123")
	os.Setenv("POCKETBASE_SUPERUSER_EMAIL", "super@example.com")
	os.Setenv("POCKETBASE_SUPERUSER_PASSWORD", "superpass123")
	defer func() {
		os.Unsetenv("POCKETBASE_ADMIN_EMAIL")
		os.Unsetenv("POCKETBASE_ADMIN_PASSWORD")
		os.Unsetenv("AGENT_EMAIL")
		os.Unsetenv("AGENT_PASSWORD")
		os.Unsetenv("POCKETBASE_SUPERUSER_EMAIL")
		os.Unsetenv("POCKETBASE_SUPERUSER_PASSWORD")
	}()

	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	admin, err := app.FindAuthRecordByEmail("users", "admin@example.com")
	if err != nil {
		t.Fatalf("admin user not seeded: %v", err)
	}
	if admin.GetString("role") != "admin" {
		t.Errorf("expected admin role, got %q", admin.GetString("role"))
	}

	agent, err := app.FindAuthRecordByEmail("users", "agent@example.com")
	if err != nil {
		t.Fatalf("agent user not seeded: %v", err)
	}
	if agent.GetString("role") != "agent" {
		t.Errorf("expected agent role, got %q", agent.GetString("role"))
	}

	if _, err := app.FindAuthRecordByEmail("_superusers", "super@example.com"); err != nil {
		t.Fatalf("superuser not seeded: %v", err)
	}
}

func TestSeedCreatesBalancedPermissionMode(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	col, err := app.FindCollectionByNameOrId("permission_mode_tools")
	if err != nil {
		t.Fatal(err)
	}
	recs, err := app.FindAllRecords(col)
	if err != nil {
		t.Fatal(err)
	}
	if len(recs) != 10 {
		t.Fatalf("expected 10 seeded permission_mode_tools rows, got %d", len(recs))
	}

	found := false
	for _, r := range recs {
		if r.GetString("tool") == "bash" && r.GetString("pattern") == "ls *" && r.GetString("action") == "allow" {
			found = true
		}
	}
	if !found {
		t.Error("expected a bash/'ls *'/allow row among seeded permission_mode_tools")
	}
}

func TestSeedDoesNotCreateAComposeHarnessInstance(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	harnesses, err := app.FindRecordsByFilter("harnesses", "cli_id = 'goose'", "", 0, 0)
	if err != nil || len(harnesses) != 1 {
		t.Fatalf("expected exactly one seeded goose harness, got %d, err %v", len(harnesses), err)
	}

	instances, err := app.FindRecordsByFilter("harness_instances", "harness = {:h}", "", 0, 0, map[string]any{"h": harnesses[0].Id})
	if err != nil || len(instances) != 0 {
		t.Fatalf("expected no seeded goose harness_instances rows, got %d, err %v", len(instances), err)
	}
	if harnesses[0].GetString("container_image") != "pocketcoder-goose:1.43.0" {
		t.Errorf("goose container_image = %q, want pocketcoder-goose:1.43.0", harnesses[0].GetString("container_image"))
	}
	var launch struct {
		Port        int               `json:"port"`
		EnvTemplate map[string]string `json:"env_template"`
	}
	if err := harnesses[0].UnmarshalJSONField("launch_template", &launch); err != nil {
		t.Fatal(err)
	}
	if launch.Port != 3000 || launch.EnvTemplate["GOOSE_SERVER__SECRET_KEY"] != "{{.__adapter_secret}}" {
		t.Errorf("goose launch template = %+v, want port 3000 and per-instance secret", launch)
	}
}

func TestSeedCreatesManagedPeerHarnessCatalogEntries(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	tests := []struct {
		cliID, version, image, command, apiKeyEnv string
	}{
		{"claude-code", "0.64.2", "pocketcoder-harness-claude-code:0.64.2", "claude-agent-acp", "ANTHROPIC_API_KEY"},
		{"codex", "1.1.9", "pocketcoder-harness-codex:1.1.9", "codex-acp", "OPENAI_API_KEY"},
		{"opencode", "1.18.11", "pocketcoder-harness-opencode:1.18.11", "opencode acp", "OPENCODE_API_KEY"},
	}
	for _, tc := range tests {
		t.Run(tc.cliID, func(t *testing.T) {
			recs, err := app.FindRecordsByFilter("harnesses", "cli_id = {:cli}", "", 0, 0, map[string]any{"cli": tc.cliID})
			if err != nil || len(recs) != 1 {
				t.Fatalf("expected one %s harness, got %d, err %v", tc.cliID, len(recs), err)
			}
			rec := recs[0]
			if rec.GetString("version") != tc.version || rec.GetString("container_image") != tc.image {
				t.Errorf("version/image = %q/%q, want %q/%q", rec.GetString("version"), rec.GetString("container_image"), tc.version, tc.image)
			}
			if rec.GetString("acp_transport") != "stdio" || !rec.GetBool("single_connection_only") {
				t.Errorf("unexpected capability flags for %s", tc.cliID)
			}
			var launch struct {
				Cmd         []string          `json:"cmd"`
				Port        int               `json:"port"`
				EnvTemplate map[string]string `json:"env_template"`
			}
			if err := rec.UnmarshalJSONField("launch_template", &launch); err != nil {
				t.Fatal(err)
			}
			if len(launch.Cmd) < 2 || launch.Cmd[1] != tc.command || launch.Port != 3000 {
				t.Errorf("launch template = %+v, want command %q on port 3000", launch, tc.command)
			}
			if launch.EnvTemplate[tc.apiKeyEnv] != "{{.API_KEY}}" || launch.EnvTemplate["HARNESS_ADAPTER_SECRET"] != "{{.__adapter_secret}}" {
				t.Errorf("env_template = %v, missing API key or adapter secret mapping", launch.EnvTemplate)
			}
			if tc.cliID == "opencode" && launch.EnvTemplate["OLLAMA_HOST"] != "{{.__ollama_host}}" {
				t.Errorf("OpenCode env_template = %v, missing private Ollama endpoint", launch.EnvTemplate)
			}
			instances, err := app.FindRecordsByFilter("harness_instances", "harness = {:h}", "", 0, 0, map[string]any{"h": rec.Id})
			if err != nil || len(instances) != 0 {
				t.Errorf("managed harness should be provisioned lazily; instances=%d err=%v", len(instances), err)
			}
		})
	}
}
