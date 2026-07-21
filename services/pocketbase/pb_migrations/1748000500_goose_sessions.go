/*
PocketCoder: An accessible, secure, and user-friendly open-source coding assistant platform.
Copyright (C) 2026 Qtpi Bonding LLC

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

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
