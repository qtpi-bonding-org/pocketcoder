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

// Drops the "cron_jobs" collection (pc_cron_jobs). It is dead code, not
// merely unused: its firing handler (the now-deleted
// internal/hooks/cron.go) wrote to chats.agent and referenced a
// "messages" collection, both deleted by earlier migrations
// (1753000000_prune_legacy_ai_config.go, 1752000000_prune_legacy_runtime.go)
// — it errored at runtime on every fire. Replaced by
// schedule_owners + the Scheduler UI's live passthrough to Goose's own
// scheduler. See
// docs/superpowers/specs/2026-07-23-scheduler-ui-design.md's Retirement
// section. Zero surviving relation fields point at this collection
// (confirmed by grep across all migrations at plan-writing time), so —
// like 1754000000's now-superseded skills-collection removal, but unlike
// ai_agents in 1753000000_prune_legacy_ai_config.go — no relation needs
// dropping first.
func init() {
	migrations.Register(func(app core.App) error {
		col, err := app.FindCollectionByNameOrId("cron_jobs")
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
