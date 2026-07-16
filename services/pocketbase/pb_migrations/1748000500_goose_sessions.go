package pb_migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

// goose_sessions is intentionally the only c1 persistence for a Goose-backed
// chat. Goose owns conversation, tool, approval, and run state.
func init() {
	migrations.Register(func(app core.App) error {
		chats, err := app.FindCollectionByNameOrId("chats")
		if err != nil {
			return err
		}
		users, err := app.FindCollectionByNameOrId("_pb_users_auth_")
		if err != nil {
			return err
		}

		collection := core.NewBaseCollection("goose_sessions")
		collection.Id = "pc_goose_sessions"
		collection.Fields.Add(
			&core.RelationField{Name: "chat", Required: true, CollectionId: chats.Id, MaxSelect: 1, CascadeDelete: true},
			&core.RelationField{Name: "user", Required: true, CollectionId: users.Id, MaxSelect: 1, CascadeDelete: true},
			&core.TextField{Name: "goose_session_id", Required: true},
			&core.TextField{Name: "goose_version"},
			&core.TextField{Name: "provider"},
		)
		collection.ListRule = ptr("@request.auth.id != '' && user = @request.auth.id")
		collection.ViewRule = ptr("@request.auth.id != '' && user = @request.auth.id")
		collection.Indexes = []string{
			"CREATE UNIQUE INDEX idx_goose_sessions_chat ON goose_sessions (chat)",
			"CREATE UNIQUE INDEX idx_goose_sessions_goose_session_id ON goose_sessions (goose_session_id)",
		}
		return app.Save(collection)
	}, func(app core.App) error {
		collection, err := app.FindCollectionByNameOrId("goose_sessions")
		if err != nil {
			return err
		}
		return app.Delete(collection)
	})
}
