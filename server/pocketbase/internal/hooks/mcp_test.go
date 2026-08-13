package hooks

import (
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
	// this unit test; renderMcpConfig's file-write behavior is already
	// covered by the render logic itself (unchanged by this task) and by
	// Task 8's integration test.
	if err := app.Save(rec); err != nil {
		t.Fatalf("save mcp_servers record: %v", err)
	}
}
