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

func init() {
	migrations.Register(func(app core.App) error {
		poco, err := app.FindCollectionByNameOrId("poco_configs")
		if err != nil {
			return err
		}
		if poco.Fields.GetByName("mode") == nil {
			// Values are provisional (spec §13.3): only "approve" is verified
			// against the pinned Goose build. Confirm advertised modes first.
			poco.Fields.Add(&core.SelectField{
				Name:      "mode",
				MaxSelect: 1,
				Values:    []string{"auto", "approve", "smart_approve", "chat"},
			})
		}
		if f := poco.Fields.GetByName("config"); f != nil { // dead OpenCode bundle
			poco.Fields.RemoveById(f.GetId())
		}
		return app.Save(poco)
	}, func(app core.App) error {
		poco, err := app.FindCollectionByNameOrId("poco_configs")
		if err != nil {
			return err
		}
		if f := poco.Fields.GetByName("mode"); f != nil {
			poco.Fields.RemoveById(f.GetId())
		}
		if poco.Fields.GetByName("config") == nil {
			poco.Fields.Add(&core.TextField{Name: "config"})
		}
		return app.Save(poco)
	})
}
