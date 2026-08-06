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

// @pocketcoder-core: MCP Gateway Registration. One-time, idempotent
// registration of the Docker MCP Gateway as a Goose extension. See
// docs/superpowers/specs/2026-07-23-mcp-governance-ui-design.md Component 3
// and spikes/goose-mcp-gateway-attach/README.md for the verified request
// shapes and the SSE-vs-streaming transport finding this depends on
// (docker-compose.yml's mcp-gateway must run --transport streaming).
package hooks

import (
	"context"
	"encoding/json"
	"log"
	"os"
	"time"

	acpsdk "github.com/coder/acp-go-sdk"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/coordinator"
)

// mcpGatewayExtensionName must match the "name" field in the request built
// by registerMcpGatewayExtensionOnce below.
const mcpGatewayExtensionName = "gateway"

// mcpGatewayURL is the gateway's Streamable-HTTP endpoint on the dedicated
// goose<->mcp-gateway Docker network (docker-compose.yml).
const mcpGatewayURL = "http://mcp-gateway:8811/mcp"

// RegisterMcpGatewayExtension attempts gateway registration in a bounded
// retry loop and returns once it either succeeds, confirms the extension is
// already present, or exhausts its retries. Intended to be called with `go`
// from main.go's OnServe handler — never blocks PocketBase startup.
func RegisterMcpGatewayExtension(coord func() *coordinator.Coordinator) {
	if os.Getenv("GOOSE_ACP_URL") == "" || os.Getenv("GOOSE_SERVER__SECRET_KEY") == "" || os.Getenv("GOOSE_WORKSPACE") == "" {
		log.Println("ℹ️  [MCPGateway] agent profile not configured (GOOSE_ACP_URL/GOOSE_SERVER__SECRET_KEY/GOOSE_WORKSPACE unset); skipping gateway registration")
		return
	}

	const maxAttempts = 6
	const retryDelay = 10 * time.Second

	for attempt := 1; attempt <= maxAttempts; attempt++ {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		ok := registerMcpGatewayExtensionOnce(ctx, coord)
		cancel()
		if ok {
			return
		}
		if attempt < maxAttempts {
			log.Printf("🐳 [MCPGateway] registration attempt %d/%d failed, retrying in %s", attempt, maxAttempts, retryDelay)
			time.Sleep(retryDelay)
		}
	}
	log.Printf("❌ [MCPGateway] gave up registering gateway extension after %d attempts", maxAttempts)
}

// registerMcpGatewayExtensionOnce does one gate-check-add pass. Returns true
// if the caller should stop retrying (success or already-registered). The
// GOOSE_ACP_URL/GOOSE_SERVER__SECRET_KEY/GOOSE_WORKSPACE env-var gate lives in
// RegisterMcpGatewayExtension, not here, so this function stays testable with
// an injected coordinator regardless of the process's real env vars.
func registerMcpGatewayExtensionOnce(ctx context.Context, coord func() *coordinator.Coordinator) bool {
	c := coord()
	if c == nil {
		log.Println("⚠️ [MCPGateway] agent profile configured but coordinator not yet available")
		return false
	}

	conn, err := c.AdminConn(ctx)
	if err != nil {
		log.Printf("⚠️ [MCPGateway] AdminConn failed: %v", err)
		return false
	}
	defer conn.Close()

	listRaw, err := conn.CallExtension(ctx, "_goose/unstable/config/extensions/list", struct{}{})
	if err != nil {
		log.Printf("⚠️ [MCPGateway] config/extensions/list failed: %v", err)
		return false
	}
	// GooseExtension is a oneOf(builtin, platform, mcp) union
	// (acp-schema.json's GooseExtension def). Only builtin/platform carry a
	// top-level "name" — the mcp variant's required fields are only
	// {"type","server"}, and the server's name lives at extension.server.name
	// (McpServerHttp's schema: required ["type","name","url","headers"]).
	// The gateway is always registered as an mcp-type extension, so its name
	// only ever appears at extension.server.name — parse both, preferring
	// server.name, so a future builtin/platform-type collision check (if
	// ever needed) still works too.
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
		log.Printf("⚠️ [MCPGateway] failed to parse config/extensions/list response: %v", err)
		return false
	}
	for _, e := range listResp.Extensions {
		name := e.Extension.Server.Name
		if name == "" {
			name = e.Extension.Name
		}
		if name == mcpGatewayExtensionName {
			log.Println("✅ [MCPGateway] gateway extension already registered")
			return true
		}
	}

	addReq := addConfigExtensionParams{
		Extension: gooseExtensionParam{
			Type: "mcp",
			Server: mcpServerHttpParam{
				Type:    "http",
				Name:    mcpGatewayExtensionName,
				URL:     mcpGatewayURL,
				Headers: mcpGatewayAuthHeaders(),
			},
		},
		Enabled: true,
	}
	if _, err := conn.CallExtension(ctx, "_goose/unstable/config/extensions/add", addReq); err != nil {
		log.Printf("⚠️ [MCPGateway] config/extensions/add failed: %v", err)
		return false
	}
	log.Println("✅ [MCPGateway] registered gateway extension")
	return true
}

// McpGatewayHttpServer returns the gateway as an ACP McpServer.Http entry,
// for delivery via session/new|load.McpServers -- the mechanism the three
// peer stdio ACP harnesses (Claude Code, Codex, OpenCode) all document as
// "client-provided MCP servers", per each adapter's own README. Goose does
// NOT receive it this way: it gets a persistent extension instead via
// RegisterMcpGatewayExtension, since Goose isn't reconnected per-session
// the same way (docs/superpowers/specs/2026-07-23-mcp-governance-ui-design.md
// Component 3). Callers (internal/api's buildSessionProfile) must not call
// this for a Goose session.
//
// Returns nil if MCP_GATEWAY_AUTH_TOKEN isn't set yet (bootstrap secrets
// not rendered) -- a session/new call should omit the entry entirely
// rather than send one the gateway will reject unauthenticated.
func McpGatewayHttpServer() *acpsdk.McpServer {
	token := os.Getenv("MCP_GATEWAY_AUTH_TOKEN")
	if token == "" {
		return nil
	}
	return &acpsdk.McpServer{
		Http: &acpsdk.McpServerHttpInline{
			Type: "http",
			Name: mcpGatewayExtensionName,
			Url:  mcpGatewayURL,
			Headers: []acpsdk.HttpHeader{
				{Name: "Authorization", Value: "Bearer " + token},
			},
		},
	}
}

// mcpGatewayAuthHeaders builds the Authorization header docker-mcp v0.43+
// requires on HTTP/streaming transports by default (previously ran
// unauthenticated in-container). MCP_GATEWAY_AUTH_TOKEN is generated once
// in bootstrap.nix alongside the other bootstrap secrets and set on both
// this container and mcp-gateway's (docker-compose.yml). Empty token means
// the agent profile's secrets haven't rendered yet — same fail-soft
// posture as GOOSE_SERVER__SECRET_KEY elsewhere in this file, not a fatal
// error, so a still-blank .env during early bootstrap doesn't crash
// registration outright; the gateway will simply reject the add and the
// bounded retry in RegisterMcpGatewayExtension tries again.
func mcpGatewayAuthHeaders() []httpHeaderParam {
	token := os.Getenv("MCP_GATEWAY_AUTH_TOKEN")
	if token == "" {
		return []httpHeaderParam{}
	}
	return []httpHeaderParam{{Name: "Authorization", Value: "Bearer " + token}}
}

// addConfigExtensionParams mirrors AddConfigExtensionRequest_unstable
// (acp-schema.json). gooseExtensionParam/mcpServerHttpParam mirror the "mcp"
// variant of GooseExtension and the "http" variant of McpServer respectively
// — verified live in spikes/goose-mcp-gateway-attach/README.md's captured
// request/response.
type addConfigExtensionParams struct {
	Extension gooseExtensionParam `json:"extension"`
	Enabled   bool                `json:"enabled"`
}

type gooseExtensionParam struct {
	Type   string             `json:"type"`
	Server mcpServerHttpParam `json:"server"`
}

type mcpServerHttpParam struct {
	Type    string            `json:"type"`
	Name    string            `json:"name"`
	URL     string            `json:"url"`
	Headers []httpHeaderParam `json:"headers"`
}

// httpHeaderParam mirrors McpServerHttp.headers' item schema (HttpHeader in
// acp-schema.json) — {name, value}, not a bare string. Sent empty today
// (the gateway needs no auth headers), but the type must be right for when
// it does.
type httpHeaderParam struct {
	Name  string `json:"name"`
	Value string `json:"value"`
}
