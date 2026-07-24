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

// @pocketcoder-core: Cognee Extension Registration. One-time, idempotent
// registration of the cognee memory MCP server as a Goose extension,
// independent of the mcp_servers/Docker-MCP-gateway catalog path (cognee is
// not a catalog server). Mirrors mcp_gateway.go's registration shape. See
// docs/superpowers/specs/2026-07-24-cognee-agent-memory-design.md §3.2 and
// docs/superpowers/plans/2026-07-24-cognee-transport-decision.md for the
// verified transport/port this depends on.
package hooks

import (
	"context"
	"encoding/json"
	"log"
	"os"
	"time"

	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/coordinator"
)

// cogneeExtensionName must match the "name" field in the request built by
// registerCogneeExtensionOnce below.
const cogneeExtensionName = "cognee"

// cogneeURL is cognee's endpoint on the dedicated goose<->cognee Docker
// network (docker-compose.yml). Port/transport verified in
// docs/superpowers/plans/2026-07-24-cognee-transport-decision.md (genuine
// MCP Streamable HTTP on :8000, path /mcp — cognee-mcp's default `--path`).
const cogneeURL = "http://cognee:8000/mcp"

// RegisterCogneeExtension attempts cognee registration in a bounded retry
// loop and returns once it either succeeds, confirms the extension is
// already present, or exhausts its retries. Intended to be called with `go`
// from main.go's OnServe handler — never blocks PocketBase startup.
func RegisterCogneeExtension(coord func() *coordinator.Coordinator) {
	if os.Getenv("GOOSE_ACP_URL") == "" || os.Getenv("GOOSE_SERVER__SECRET_KEY") == "" || os.Getenv("GOOSE_WORKSPACE") == "" {
		log.Println("ℹ️  [Cognee] agent profile not configured (GOOSE_ACP_URL/GOOSE_SERVER__SECRET_KEY/GOOSE_WORKSPACE unset); skipping cognee registration")
		return
	}

	const maxAttempts = 6
	const retryDelay = 10 * time.Second

	for attempt := 1; attempt <= maxAttempts; attempt++ {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		ok := registerCogneeExtensionOnce(ctx, coord)
		cancel()
		if ok {
			return
		}
		if attempt < maxAttempts {
			log.Printf("🧠 [Cognee] registration attempt %d/%d failed, retrying in %s", attempt, maxAttempts, retryDelay)
			time.Sleep(retryDelay)
		}
	}
	log.Printf("❌ [Cognee] gave up registering cognee extension after %d attempts", maxAttempts)
}

// registerCogneeExtensionOnce does one gate-check-add pass. Returns true if
// the caller should stop retrying (success or already-registered).
func registerCogneeExtensionOnce(ctx context.Context, coord func() *coordinator.Coordinator) bool {
	c := coord()
	if c == nil {
		log.Println("⚠️ [Cognee] agent profile configured but coordinator not yet available")
		return false
	}

	conn, err := c.AdminConn(ctx)
	if err != nil {
		log.Printf("⚠️ [Cognee] AdminConn failed: %v", err)
		return false
	}
	defer conn.Close()

	listRaw, err := conn.CallExtension(ctx, "_goose/unstable/config/extensions/list", struct{}{})
	if err != nil {
		log.Printf("⚠️ [Cognee] config/extensions/list failed: %v", err)
		return false
	}
	var listResp struct {
		Extensions []struct {
			Extension struct {
				Name   string `json:"name"`
				Server struct {
					Name string `json:"name"`
				} `json:"server"`
			} `json:"extension"`
		} `json:"extensions"`
	}
	if err := json.Unmarshal(listRaw, &listResp); err != nil {
		log.Printf("⚠️ [Cognee] failed to parse config/extensions/list response: %v", err)
		return false
	}
	for _, e := range listResp.Extensions {
		name := e.Extension.Server.Name
		if name == "" {
			name = e.Extension.Name
		}
		if name == cogneeExtensionName {
			log.Println("✅ [Cognee] cognee extension already registered")
			return true
		}
	}

	addReq := addConfigExtensionParams{
		Extension: gooseExtensionParam{
			Type: "mcp",
			Server: mcpServerHttpParam{
				Type:    "http",
				Name:    cogneeExtensionName,
				URL:     cogneeURL,
				Headers: []httpHeaderParam{},
			},
		},
		Enabled: true,
	}
	if _, err := conn.CallExtension(ctx, "_goose/unstable/config/extensions/add", addReq); err != nil {
		log.Printf("⚠️ [Cognee] config/extensions/add failed: %v", err)
		return false
	}
	log.Println("✅ [Cognee] registered cognee extension")
	return true
}
