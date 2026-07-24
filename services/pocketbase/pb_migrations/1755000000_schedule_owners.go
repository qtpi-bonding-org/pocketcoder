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

// schedule_owners is the one piece of PocketBase-side state the Scheduler
// UI needs (see docs/superpowers/specs/2026-07-23-scheduler-ui-design.md's
// Component 1). Goose owns everything about a schedule's execution (cron,
// paused state, last run, the recipe itself) in its own flat, userless
// namespace, keyed by a schedule id PocketBase must generate and supply at
// creation time. This collection only tracks what Goose cannot: who a
// schedule belongs to, and a user-editable display name decoupled from
// Goose's immutable id (Goose has no rename RPC). Per the "PocketBase
// Schema Conventions" rule in root CLAUDE.md, this collection's own `id`
// is PocketBase's normal auto id — goose_schedule_id is a plain
// unique-indexed field, never the PK.
func init() {
	migrations.Register(func(app core.App) error {
		users, err := app.FindCollectionByNameOrId("_pb_users_auth_")
		if err != nil {
			return err
		}

		collection := core.NewBaseCollection("schedule_owners")
		collection.Id = "pc_schedule_owners"
		collection.Fields.Add(
			&core.RelationField{Name: "user", Required: true, CollectionId: users.Id, MaxSelect: 1, CascadeDelete: true},
			&core.TextField{Name: "goose_schedule_id", Required: true},
			&core.TextField{Name: "display_name", Required: true},
		)
		collection.ListRule = ptr("@request.auth.id != '' && user = @request.auth.id")
		collection.ViewRule = ptr("@request.auth.id != '' && user = @request.auth.id")
		collection.Indexes = []string{
			"CREATE UNIQUE INDEX idx_schedule_owners_goose_schedule_id ON schedule_owners (goose_schedule_id)",
		}
		return app.Save(collection)
	}, func(app core.App) error {
		collection, err := app.FindCollectionByNameOrId("schedule_owners")
		if err != nil {
			return err
		}
		return app.Delete(collection)
	})
}
