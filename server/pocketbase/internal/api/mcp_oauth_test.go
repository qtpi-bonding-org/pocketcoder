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

package api

import (
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	_ "github.com/qtpi-bonding-org/pocketcoder/backend/pb_migrations"
)

func newMcpServer(t *testing.T, app core.App, name, status string, extra map[string]any) *core.Record {
	t.Helper()
	col, err := app.FindCollectionByNameOrId("mcp_servers")
	if err != nil {
		t.Fatal(err)
	}
	rec := core.NewRecord(col)
	rec.Set("name", name)
	rec.Set("status", status)
	for k, v := range extra {
		rec.Set(k, v)
	}
	if err := app.Save(rec); err != nil {
		t.Fatalf("save mcp_servers: %v", err)
	}
	return rec
}

func TestStoreOAuthToken_MergesIntoExistingConfig(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	rec := newMcpServer(t, app, "github-mcp-server", "approved", map[string]any{
		"oauth_token_env_var": "GITHUB_PERSONAL_ACCESS_TOKEN",
		"config":              map[string]any{"OTHER_KEY": "keep-me"},
	})

	if err := storeOAuthToken(app, "github-mcp-server", "tok123", "refresh456"); err != nil {
		t.Fatalf("storeOAuthToken: %v", err)
	}

	got, err := app.FindRecordById("mcp_servers", rec.Id)
	if err != nil {
		t.Fatal(err)
	}
	config := map[string]any{}
	if err := got.UnmarshalJSONField("config", &config); err != nil {
		t.Fatal(err)
	}
	if config["OTHER_KEY"] != "keep-me" {
		t.Errorf("config = %v, want OTHER_KEY preserved", config)
	}
	if config["GITHUB_PERSONAL_ACCESS_TOKEN"] != "tok123" {
		t.Errorf("config = %v, want GITHUB_PERSONAL_ACCESS_TOKEN=tok123", config)
	}
	if config["GITHUB_PERSONAL_ACCESS_TOKEN_REFRESH_TOKEN"] != "refresh456" {
		t.Errorf("config = %v, want refresh token under the derived key", config)
	}
}

func TestStoreOAuthToken_NoRefreshToken_OmitsRefreshKey(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	newMcpServer(t, app, "github-mcp-server", "approved", map[string]any{
		"oauth_token_env_var": "GITHUB_PERSONAL_ACCESS_TOKEN",
	})

	if err := storeOAuthToken(app, "github-mcp-server", "tok123", ""); err != nil {
		t.Fatalf("storeOAuthToken: %v", err)
	}

	recs, err := app.FindRecordsByFilter("mcp_servers", "name = 'github-mcp-server'", "", 1, 0)
	if err != nil || len(recs) != 1 {
		t.Fatalf("lookup failed: %v", err)
	}
	config := map[string]any{}
	_ = recs[0].UnmarshalJSONField("config", &config)
	if _, ok := config["GITHUB_PERSONAL_ACCESS_TOKEN_REFRESH_TOKEN"]; ok {
		t.Errorf("config = %v, want no refresh-token key when refreshToken is empty", config)
	}
}

func TestStoreOAuthToken_ServerNotFound(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	err = storeOAuthToken(app, "does-not-exist", "tok", "")
	if err != errOAuthServerNotFound {
		t.Fatalf("err = %v, want errOAuthServerNotFound", err)
	}
}

func TestStoreOAuthToken_MissingOAuthTokenEnvVar(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	newMcpServer(t, app, "plain-secret-server", "approved", nil)

	err = storeOAuthToken(app, "plain-secret-server", "tok", "")
	if err != errOAuthNotConfigured {
		t.Fatalf("err = %v, want errOAuthNotConfigured", err)
	}
}
