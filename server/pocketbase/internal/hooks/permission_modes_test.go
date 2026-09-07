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

package hooks

import (
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	_ "github.com/qtpi-bonding-org/pocketcoder/backend/pb_migrations"
)

// TestDeletingPermissionModeClearsAgentProfileReference locks in a property
// this feature depends on but does not implement itself: PocketBase's own
// delete path already unsets a non-cascade, non-required relation (like
// agent_profiles.permission_mode) rather than leaving it dangling. If
// schema.json ever changes that field's required/cascadeDelete flags, this
// test should fail -- a dangling permission_mode id makes
// sessionprofile.Build error out entirely instead of falling back to a
// default mode.
func TestDeletingPermissionModeClearsAgentProfileReference(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	users, err := app.FindCollectionByNameOrId("_pb_users_auth_")
	if err != nil {
		t.Fatal(err)
	}
	user := core.NewRecord(users)
	user.SetEmail("test-permission-mode-delete@example.com")
	user.SetPassword("password123")
	if err := app.Save(user); err != nil {
		t.Fatal(err)
	}

	modes, err := app.FindCollectionByNameOrId("permission_modes")
	if err != nil {
		t.Fatal(err)
	}
	mode := core.NewRecord(modes)
	mode.Set("name", "my-custom-mode")
	mode.Set("base_session_mode", "approve")
	mode.Set("user", user.Id)
	if err := app.Save(mode); err != nil {
		t.Fatal(err)
	}

	profiles, err := app.FindCollectionByNameOrId("agent_profiles")
	if err != nil {
		t.Fatal(err)
	}
	profile := core.NewRecord(profiles)
	profile.Set("name", "test-profile")
	profile.Set("user", user.Id)
	profile.Set("permission_mode", mode.Id)
	if err := app.Save(profile); err != nil {
		t.Fatal(err)
	}

	if err := app.Delete(mode); err != nil {
		t.Fatalf("delete permission mode: %v", err)
	}

	reloaded, err := app.FindRecordById("agent_profiles", profile.Id)
	if err != nil {
		t.Fatal(err)
	}
	if reloaded.GetString("permission_mode") != "" {
		t.Errorf("expected permission_mode cleared by PocketBase's own delete path, got %q", reloaded.GetString("permission_mode"))
	}
}
