package pb_migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

func init() {
	migrations.Register(func(app core.App) error {
		// =========================================================================
		// MCP SERVERS COLLECTION
		// =========================================================================
		// This collection tracks MCP server requests and their approval status.
		// Poco requests servers, users approve/deny via the Flutter app,
		// and PocketBase provisions approved servers by writing gateway config.

		mcpServers, err := app.FindCollectionByNameOrId("mcp_servers")
		if err != nil {
			// Collection doesn't exist, create it
			mcpServers = core.NewCollection("mcp_servers", core.CollectionTypeBase)
			mcpServers.Id = "mcp_servers"
		}

		// Add fields if they don't exist
		addField := func(name string, f core.Field) {
			if existing := mcpServers.Fields.GetByName(name); existing == nil {
				mcpServers.Fields.Add(f)
			}
		}

		// name: Text, required - Server name from catalog (e.g., "postgres")
		addField("name", &core.TextField{Name: "name", Required: true})

		// status: Select, required - pending/approved/denied/revoked
		addField("status", &core.SelectField{
			Name:      "status",
			Required:  true,
			MaxSelect: 1,
			Values:    []string{"pending", "approved", "denied", "revoked"},
		})

		// requested_by: Text - Session ID or agent identifier
		addField("requested_by", &core.TextField{Name: "requested_by"})

		// approved_by: Relation to users - Who approved the request
		users, _ := app.FindCollectionByNameOrId("users")
		if users != nil {
			addField("approved_by", &core.RelationField{
				Name:         "approved_by",
				CollectionId: users.Id,
				MaxSelect:    1,
			})
		}

		// approved_at: Date - When it was approved
		addField("approved_at", &core.DateField{Name: "approved_at"})

		// config: JSON - Per-server config overrides
		addField("config", &core.JSONField{Name: "config"})

		// catalog: Text - Default: "docker-mcp"
		addField("catalog", &core.TextField{Name: "catalog"})

		// reason: Text - Why the server was requested
		addField("reason", &core.TextField{Name: "reason"})

		// Set collection rules
		// List/View: require authentication
		mcpServers.ListRule = ptr("@request.auth.id != ''")
		mcpServers.ViewRule = ptr("@request.auth.id != ''")

		// Create: agent or admin roles only
		mcpServers.CreateRule = ptr("@request.auth.role = 'agent' || @request.auth.role = 'admin'")

		// Update: admin role only
		mcpServers.UpdateRule = ptr("@request.auth.role = 'admin'")

		// Delete: admin role only
		mcpServers.DeleteRule = ptr("@request.auth.role = 'admin'")

		// Save the collection
		if err := app.Save(mcpServers); err != nil {
			return err
		}

		return nil
	}, func(app core.App) error {
		// No rollback needed for MVP
		return nil
	})
}