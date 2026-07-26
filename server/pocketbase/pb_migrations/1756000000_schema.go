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

// This file defines PocketCoder's full PocketBase schema in its final,
// current-state form. It replaces what used to be 10 separate create/
// alter/drop migrations (spanning 1740000100-1755000100) with one import
// of a schema snapshot — see schema.json in this directory, which is the
// literal JSON PocketBase's own /api/collections export uses (the same
// shape scripts/export_schema.sh produces). To change the schema going
// forward, edit schema.json directly (or make the change via the
// PocketBase Admin UI locally and re-export it) rather than adding
// another timestamped migration file, until this file grows large enough
// that splitting it out makes sense again.
package pb_migrations

import (
	_ "embed"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

//go:embed schema.json
var schemaJSON []byte

func init() {
	migrations.Register(func(app core.App) error {
		return app.ImportCollectionsByMarshaledJSON(schemaJSON, false)
	}, func(app core.App) error {
		// No-op: there is no production data to protect via rollback, and
		// this repo's existing deletion migrations already establish the
		// precedent of a no-op down for schema changes with nothing worth
		// reverting to.
		return nil
	})
}
