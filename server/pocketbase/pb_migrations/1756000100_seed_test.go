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

func TestSeedCreatesTenToolPermissions(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	col, err := app.FindCollectionByNameOrId("tool_permissions")
	if err != nil {
		t.Fatal(err)
	}
	recs, err := app.FindAllRecords(col)
	if err != nil {
		t.Fatal(err)
	}
	if len(recs) != 10 {
		t.Fatalf("expected 10 seeded tool_permissions rows, got %d", len(recs))
	}

	found := false
	for _, r := range recs {
		if r.GetString("tool") == "bash" && r.GetString("pattern") == "ls *" && r.GetString("action") == "allow" {
			found = true
		}
	}
	if !found {
		t.Error("expected a bash/'ls *'/allow row among seeded tool_permissions")
	}
}

func TestSeedCreatesDefaultGooseHarnessInstance(t *testing.T) {
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
	if err != nil || len(instances) != 1 {
		t.Fatalf("expected exactly one seeded goose harness_instance, got %d, err %v", len(instances), err)
	}

	inst := instances[0]
	if inst.GetBool("managed") {
		t.Error("seeded default goose harness_instances row must have managed = false")
	}
	if inst.GetString("container_name") != "pocketcoder-goose" {
		t.Errorf("container_name = %q, want pocketcoder-goose", inst.GetString("container_name"))
	}
	if inst.GetString("acp_endpoint") != "" {
		t.Error("seeded default row's acp_endpoint must be empty (means: use Coordinator.Config defaults)")
	}
}
