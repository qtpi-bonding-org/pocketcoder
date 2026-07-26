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
	"os"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

func init() {
	migrations.Register(func(app core.App) error {
		seedUser := func(email, password, role string) error {
			if email == "" || password == "" {
				return nil
			}
			existing, _ := app.FindAuthRecordByEmail("users", email)
			if existing != nil {
				return nil
			}
			collection, err := app.FindCollectionByNameOrId("users")
			if err != nil {
				return err
			}
			record := core.NewRecord(collection)
			record.SetEmail(email)
			record.SetPassword(password)
			record.Set("role", role)
			record.Set("verified", true)
			return app.Save(record)
		}

		if err := seedUser(os.Getenv("POCKETBASE_ADMIN_EMAIL"), os.Getenv("POCKETBASE_ADMIN_PASSWORD"), "admin"); err != nil {
			return err
		}
		if err := seedUser(os.Getenv("AGENT_EMAIL"), os.Getenv("AGENT_PASSWORD"), "agent"); err != nil {
			return err
		}

		superEmail := os.Getenv("POCKETBASE_SUPERUSER_EMAIL")
		superPass := os.Getenv("POCKETBASE_SUPERUSER_PASSWORD")
		if superEmail != "" && superPass != "" {
			existing, _ := app.FindAuthRecordByEmail("_superusers", superEmail)
			if existing == nil {
				collection, err := app.FindCollectionByNameOrId("_superusers")
				if err != nil {
					return err
				}
				super := core.NewRecord(collection)
				super.SetEmail(superEmail)
				super.SetPassword(superPass)
				if err := app.Save(super); err != nil {
					return err
				}
			}
		}

		tpColl, err := app.FindCollectionByNameOrId("tool_permissions")
		if err != nil {
			return err
		}
		seedToolPerm := func(tool, pattern, action string) error {
			rec := core.NewRecord(tpColl)
			rec.Set("tool", tool)
			rec.Set("pattern", pattern)
			rec.Set("action", action)
			rec.Set("active", true)
			return app.Save(rec)
		}

		defaults := [][3]string{
			{"*", "*", "ask"},
			{"bash", "ls *", "allow"},
			{"check_pc_updates", "*", "allow"},
			{"mcp_catalog", "*", "allow"},
			{"mcp_status", "*", "allow"},
			{"mcp_request", "*", "ask"},
			{"bash", "*", "ask"},
			{"edit", "*", "ask"},
			{"skill", "*", "ask"},
			{"poco-agents_*", "*", "ask"},
		}
		for _, d := range defaults {
			if err := seedToolPerm(d[0], d[1], d[2]); err != nil {
				return err
			}
		}

		return nil
	}, func(app core.App) error {
		// No-op: matches 1756000000_schema.go's down and this repo's
		// existing deletion-migration precedent — no data to protect.
		return nil
	})
}
