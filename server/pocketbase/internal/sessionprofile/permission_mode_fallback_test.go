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

package sessionprofile

import (
	"testing"

	"github.com/pocketbase/pocketbase/core"
)

func TestDefaultPermissionModeIDPrefersUserDefault(t *testing.T) {
	app := testApp(t)

	users, err := app.FindCollectionByNameOrId("_pb_users_auth_")
	if err != nil {
		t.Fatal(err)
	}
	user := core.NewRecord(users)
	user.SetEmail("permission-mode-fallback-test@example.com")
	user.SetPassword("password123")
	if err := app.Save(user); err != nil {
		t.Fatal(err)
	}

	modes, err := app.FindCollectionByNameOrId("permission_modes")
	if err != nil {
		t.Fatal(err)
	}

	// The seed migration already creates exactly one is_default=true,
	// is_system=true row ("manual") -- reuse it as the expected system
	// fallback rather than seeding a second one, which would make the
	// unscoped system-default query ambiguous between two matching rows.
	systemMode, err := app.FindFirstRecordByFilter("permission_modes", "is_default = true && is_system = true", nil)
	if err != nil {
		t.Fatal(err)
	}

	userMode := core.NewRecord(modes)
	userMode.Set("name", "user-default-test")
	userMode.Set("base_session_mode", "approve")
	userMode.Set("user", user.Id)
	userMode.Set("is_system", false)
	userMode.Set("is_default", true)
	if err := app.Save(userMode); err != nil {
		t.Fatal(err)
	}

	if got := defaultPermissionModeID(app, user.Id); got != userMode.Id {
		t.Fatalf("user default = %q, want %q", got, userMode.Id)
	}
	if got := defaultPermissionModeID(app, "user-without-personal-default"); got != systemMode.Id {
		t.Fatalf("system fallback = %q, want %q", got, systemMode.Id)
	}
}
