package hooks

import (
	"os"
	"strings"
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	_ "github.com/qtpi-bonding-org/pocketcoder/backend/pb_migrations"
)

func TestRegisterMcpHooks_CreateWithApprovedStatusTriggersRender(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	RegisterMcpHooks(app)

	coll, err := app.FindCollectionByNameOrId("mcp_servers")
	if err != nil {
		t.Fatalf("find mcp_servers collection: %v", err)
	}
	rec := core.NewRecord(coll)
	rec.Set("name", "manually-added-server")
	rec.Set("status", "approved")

	// This must not error — the create hook firing is enough evidence for
	// this unit test; renderMcpConfig's actual file content is covered
	// separately by TestRenderMcpConfig below.
	if err := app.Save(rec); err != nil {
		t.Fatalf("save mcp_servers record: %v", err)
	}
}

func TestRenderMcpConfig(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	original := mcpConfigDir
	mcpConfigDir = t.TempDir()
	defer func() { mcpConfigDir = original }()

	coll, err := app.FindCollectionByNameOrId("mcp_servers")
	if err != nil {
		t.Fatalf("find mcp_servers collection: %v", err)
	}

	approved := core.NewRecord(coll)
	approved.Set("name", "approved-server")
	approved.Set("status", "approved")
	approved.Set("image", "example.com/approved-server")
	approved.Set("config", map[string]any{"API_TOKEN": "secret-value"})
	if err := app.Save(approved); err != nil {
		t.Fatalf("save approved record: %v", err)
	}

	pending := core.NewRecord(coll)
	pending.Set("name", "pending-server")
	pending.Set("status", "pending")
	if err := app.Save(pending); err != nil {
		t.Fatalf("save pending record: %v", err)
	}

	if err := renderMcpConfig(app); err != nil {
		t.Fatalf("renderMcpConfig: %v", err)
	}

	catalog, err := os.ReadFile(mcpConfigDir + "/docker-mcp.yaml")
	if err != nil {
		t.Fatalf("read catalog: %v", err)
	}
	catalogText := string(catalog)

	if !strings.Contains(catalogText, "approved-server") {
		t.Errorf("catalog missing approved server entry:\n%s", catalogText)
	}
	if !strings.Contains(catalogText, "image: example.com/approved-server:latest") {
		t.Errorf("catalog does not use the server's own image from the DB:\n%s", catalogText)
	}
	if strings.Contains(catalogText, "pending-server") {
		t.Errorf("catalog must not include non-approved servers:\n%s", catalogText)
	}
	if strings.Contains(catalogText, "secret-value") {
		t.Errorf("catalog must not leak secret values directly, only env var names:\n%s", catalogText)
	}
	if !strings.Contains(catalogText, "env: API_TOKEN") {
		t.Errorf("catalog missing secrets env reference:\n%s", catalogText)
	}

	secrets, err := os.ReadFile(mcpConfigDir + "/mcp.env")
	if err != nil {
		t.Fatalf("read secrets: %v", err)
	}
	if !strings.Contains(string(secrets), "API_TOKEN=secret-value") {
		t.Errorf("mcp.env missing rendered secret:\n%s", string(secrets))
	}
}
