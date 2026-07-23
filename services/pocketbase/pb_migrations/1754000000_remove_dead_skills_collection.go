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

// Drops the "skills" collection (pc_skills), created by
// 1748000100_acp_schema.go before the ownership-map's "zero PocketBase
// schema" conclusion for skills was reached. Nothing in Go or Flutter has
// ever read or written it — see
// docs/superpowers/specs/2026-07-23-skills-ui-design.md's Component 5.
// Skills are managed entirely via ACP passthrough
// (services/pocketbase/internal/api/skills.go) with no PocketBase storage
// at all. Zero surviving relation fields point at this collection
// (confirmed by grep across all migrations at plan-writing time), so —
// unlike ai_agents in 1753000000_prune_legacy_ai_config.go — no relation
// needs dropping first.
func init() {
	migrations.Register(func(app core.App) error {
		col, err := app.FindCollectionByNameOrId("skills")
		if err != nil {
			return err
		}
		return app.Delete(col)
	}, func(app core.App) error {
		// Down migration intentionally does not recreate the collection —
		// matches 1753000000_prune_legacy_ai_config.go's precedent of a
		// no-op down migration for a deliberately-dead-code removal.
		return nil
	})
}
