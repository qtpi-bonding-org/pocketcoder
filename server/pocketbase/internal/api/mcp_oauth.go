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

// @pocketcoder-core: MCP OAuth Token Intake. Receives the
// {access_token, refresh_token} pair a client obtained via
// workers/oauth-relay's PKCE exchange (see
// docs/superpowers/specs/2026-07-27-mcp-oauth-flow-design.md, Component 3)
// and writes it into the same mcp_servers.config JSON blob hooks/mcp.go's
// renderMcpConfig already turns into mcp.env — this is not a new
// secret-delivery path, it reuses the existing one. NOT written into
// mcp-gateway's own OAuth credential-helper store
// (pkg/oauth/token_store.go) — that store belongs to the gateway's own
// DCR-based OAuth subsystem, which this design does not use (see the
// spec's Problem section).
package api

import (
	"fmt"
	"log"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
)

var (
	errOAuthServerNotFound = fmt.Errorf("mcp_servers row not found")
	errOAuthNotConfigured  = fmt.Errorf("mcp_servers row has no oauth_token_env_var set")
)

// RegisterMcpOAuthApi registers the OAuth token-intake endpoint.
func RegisterMcpOAuthApi(app *pocketbase.PocketBase, e *core.ServeEvent) {
	e.Router.POST("/api/pocketcoder/mcp/oauth/store", func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return pocketCoderError(re, 401, "Authentication required")
		}

		var input struct {
			ServerName   string `json:"server_name"`
			AccessToken  string `json:"access_token"`
			RefreshToken string `json:"refresh_token"`
		}
		if err := re.BindBody(&input); err != nil {
			return pocketCoderError(re, 400, "Invalid request body")
		}
		if input.ServerName == "" || input.AccessToken == "" {
			return pocketCoderError(re, 400, "server_name and access_token are required")
		}

		if err := storeOAuthToken(app, input.ServerName, input.AccessToken, input.RefreshToken); err != nil {
			switch err {
			case errOAuthServerNotFound:
				return pocketCoderError(re, 404, "mcp server not found")
			case errOAuthNotConfigured:
				return pocketCoderError(re, 400, "mcp server is not configured for OAuth (oauth_token_env_var unset)")
			default:
				log.Printf("❌ [MCPOAuth] store failed for %q: %v", input.ServerName, err)
				return pocketCoderError(re, 500, "internal error")
			}
		}

		log.Printf("✅ [MCPOAuth] stored OAuth token for server %q", input.ServerName)
		return re.JSON(200, map[string]any{"stored": true})
	}).Bind(apis.RequireAuth())
}

// storeOAuthToken merges access_token (and, if present, refresh_token) into
// the target mcp_servers row's existing `config` map — the same field
// hooks/mcp.go's renderMcpConfig already writes into mcp.env as `KEY=value`
// lines for every approved server. The env var name comes from that row's
// oauth_token_env_var field; the refresh token, if any, lands under
// "{oauth_token_env_var}_REFRESH_TOKEN" — a naming convention, not a
// separate schema field, since nothing consumes it yet (token refresh is
// out of scope, see the spec's Out of scope section).
//
// Saving the record fires hooks/mcp.go's OnRecordAfterUpdateSuccess
// handler, which re-renders mcp.env and restarts the gateway container
// whenever the row's *current* status is "approved" or "revoked" — no
// separate re-render call is needed here, and a still-"pending" row is
// correctly left out of the catalog until it's explicitly approved.
func storeOAuthToken(app core.App, serverName, accessToken, refreshToken string) error {
	records, err := app.FindRecordsByFilter(
		"mcp_servers",
		"name = {:name} && status != 'denied' && status != 'revoked'",
		"-created",
		1,
		0,
		map[string]any{"name": serverName},
	)
	if err != nil {
		return fmt.Errorf("query mcp_servers: %w", err)
	}
	if len(records) == 0 {
		return errOAuthServerNotFound
	}
	record := records[0]

	envVar := record.GetString("oauth_token_env_var")
	if envVar == "" {
		return errOAuthNotConfigured
	}

	config := map[string]any{}
	// Tolerant of no/malformed existing config, mirroring
	// renderMcpConfig's own UnmarshalJSONField usage — start fresh rather
	// than fail the whole request over an unrelated pre-existing field.
	_ = record.UnmarshalJSONField("config", &config)

	config[envVar] = accessToken
	if refreshToken != "" {
		config[envVar+"_REFRESH_TOKEN"] = refreshToken
	}
	record.Set("config", config)

	if err := app.Save(record); err != nil {
		return fmt.Errorf("save mcp_servers/%s: %w", record.Id, err)
	}
	return nil
}
