package pb_migrations_test

import (
	"os"
	"testing"

	"github.com/pocketbase/pocketbase/tests"
	_ "github.com/qtpi-bonding-org/pocketcoder/backend/pb_migrations"
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
		cliID, version, image, command string
	}{
		{"claude-code", "0.64.2", "pocketcoder-harness-claude-code:0.64.2", "claude-agent-acp"},
		{"codex", "1.1.9", "pocketcoder-harness-codex:1.1.9", "codex-acp"},
		// OpenCode is multi-provider: there is no
		// single fixed env var name, so its env_template has no static
		// per-key entry at all -- renderEnv derives the right
		// <PROVIDER>_API_KEY name at runtime from each provider API-key row's
		// own provider field instead. apiKeyEnv left "" here means "skip
		// this check", not "expect a literal OPENCODE_API_KEY".
		{"opencode", "1.18.11", "pocketcoder-harness-opencode:1.18.11", "opencode acp"},
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
			if rec.GetString("acp_transport") != "stdio" {
				t.Errorf("acp_transport = %q for %s, want stdio", rec.GetString("acp_transport"), tc.cliID)
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
			if launch.EnvTemplate["HARNESS_ADAPTER_SECRET"] != "{{.__adapter_secret}}" {
				t.Errorf("env_template = %v, missing adapter secret mapping", launch.EnvTemplate)
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

func TestSeedPinsOAuthCapableHarnessProviderEdges(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()
	for _, tc := range []struct{ cliID, providerID, authenticator string }{
		{"claude-code", "anthropic", "claude"}, {"codex", "openai", "codex"},
	} {
		harness, err := app.FindFirstRecordByFilter("harnesses", "cli_id = {:c}", map[string]any{"c": tc.cliID})
		if err != nil {
			t.Fatalf("%s: %v", tc.cliID, err)
		}
		provider, err := app.FindFirstRecordByFilter("providers", "provider_id = {:p}", map[string]any{"p": tc.providerID})
		if err != nil {
			t.Fatalf("%s: expected a seeded placeholder provider row for %s: %v", tc.cliID, tc.providerID, err)
		}
		edge, err := app.FindFirstRecordByFilter("harness_providers", "harness = {:h} && provider = {:p}", map[string]any{"h": harness.Id, "p": provider.Id})
		if err != nil {
			t.Fatalf("%s: expected a harness_providers edge: %v", tc.cliID, err)
		}
		if !edge.GetBool("is_pinned") {
			t.Errorf("%s: edge.is_pinned = false, want true", tc.cliID)
		}
		if !edge.GetBool("supports_oauth") {
			t.Errorf("%s: edge.supports_oauth = false, want true", tc.cliID)
		}
		if got := edge.GetString("oauth_authenticator"); got != tc.authenticator {
			t.Errorf("%s: edge.oauth_authenticator = %q, want %q", tc.cliID, got, tc.authenticator)
		}
	}
	for _, cliID := range []string{"goose", "opencode"} {
		harness, err := app.FindFirstRecordByFilter("harnesses", "cli_id = {:c}", map[string]any{"c": cliID})
		if err != nil {
			t.Fatal(err)
		}
		if !harness.GetBool("provider_fanout") {
			t.Errorf("%s: provider_fanout = false, want true", cliID)
		}
	}
}

func TestSeedManagedHarnessEnvTemplateHasNoPerHarnessAPIKeyEntry(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()
	for _, cliID := range []string{"claude-code", "codex", "opencode"} {
		harness, err := app.FindFirstRecordByFilter("harnesses", "cli_id = {:c}", map[string]any{"c": cliID})
		if err != nil {
			t.Fatal(err)
		}
		var launch struct {
			EnvTemplate map[string]string `json:"env_template"`
		}
		if err := harness.UnmarshalJSONField("launch_template", &launch); err != nil {
			t.Fatal(err)
		}
		for name := range launch.EnvTemplate {
			if name != "HARNESS_ADAPTER_SECRET" && name != "POCKETCODER_HARNESS_CLI_ID" && name != "OLLAMA_HOST" {
				t.Errorf("%s: env_template has unexpected static entry %q -- API key env vars must come from providers/harness_providers at launch time, not be seeded", cliID, name)
			}
		}
	}
}
