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
	"fmt"
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
		if err := seedUser(os.Getenv("API_TEST_EMAIL"), os.Getenv("API_TEST_PASSWORD"), "user"); err != nil {
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

		modeColl, err := app.FindCollectionByNameOrId("permission_modes")
		if err != nil {
			return err
		}
		balanced := core.NewRecord(modeColl)
		balanced.Set("name", "Balanced")
		balanced.Set("description", "Ask before tools that can change the workspace.")
		balanced.Set("base_session_mode", "approve")
		balanced.Set("is_system", true)
		balanced.Set("is_default", true)
		if err := app.Save(balanced); err != nil {
			return err
		}

		agentProfiles, err := app.FindCollectionByNameOrId("agent_profiles")
		if err != nil {
			return err
		}
		poco := core.NewRecord(agentProfiles)
		poco.Set("name", "Poco")
		poco.Set("is_system", true)
		poco.Set("is_default", true)
		poco.Set("permission_mode", balanced.Id)
		if err := app.Save(poco); err != nil {
			return fmt.Errorf("seed Poco agent profile: %w", err)
		}

		tpColl, err := app.FindCollectionByNameOrId("permission_mode_tools")
		if err != nil {
			return err
		}
		seedToolPerm := func(tool, pattern, action string) error {
			rec := core.NewRecord(tpColl)
			rec.Set("tool", tool)
			rec.Set("pattern", pattern)
			rec.Set("action", action)
			rec.Set("active", true)
			rec.Set("permission_mode", balanced.Id)
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

		harnessesColl, err := app.FindCollectionByNameOrId("harnesses")
		if err != nil {
			return err
		}
		gooseHarness := core.NewRecord(harnessesColl)
		gooseHarness.Set("name", "Goose")
		gooseHarness.Set("cli_id", "goose")
		gooseHarness.Set("version", "1.43.0")
		gooseHarness.Set("description", "Goose through its ACP server.")
		gooseHarness.Set("acp_transport", "websocket")
		gooseHarness.Set("container_image", "pocketcoder-goose:1.43.0")
		gooseHarness.Set("launch_template", map[string]any{
			"cmd":  []string{},
			"port": 3000,
			"env_template": map[string]string{
				"GOOSE_SERVER__SECRET_KEY": "{{.__adapter_secret}}",
				"GOOSE_PROVIDER":           "{{.__provider}}",
				"GOOSE_MODEL":              "{{.__model}}",
				// No static *_API_KEY entry here: Goose's actual env var name
				// depends on which provider is selected (GOOSE_PROVIDER=openai
				// wants OPENAI_API_KEY, =anthropic wants ANTHROPIC_API_KEY,
				// =openrouter wants OPENROUTER_API_KEY, etc. -- see Goose's own
				// docs). A single hardcoded "OPENROUTER_API_KEY" placeholder
				// here both required a literally-named key entry
				// nothing in the app ever writes (every key the UI creates is
				// generically named "API_KEY") and would have been wrong for
				// any provider other than OpenRouter anyway. renderEnv derives
				// the correct <PROVIDER>_API_KEY name for the resolved
				// provider and injects it directly, so no template entry is
				// needed for it at all.
				"GOOSE_PATH_ROOT":         "/workspace/.pocketcoder_auth",
				"GOOSE_DISABLE_KEYRING":   "1",
				"GOOSE_TELEMETRY_ENABLED": "false",
				"OLLAMA_HOST":             "{{.__ollama_host}}",
			},
		})
		gooseHarness.Set("supports_live_config", true)
		gooseHarness.Set("provider_fanout", true)
		gooseHarness.Set("supports_ollama", true)
		gooseHarness.Set("supports_session_delete", true)
		gooseHarness.Set("supports_additional_directories", true)
		if err := app.Save(gooseHarness); err != nil {
			return fmt.Errorf("seed goose harness: %w", err)
		}

		// Peer ACP harnesses are catalog entries, not compose services. Their
		// images are built during bootstrap and PocketBase creates the actual
		// container lazily when a user first selects the harness for a chat.
		seedManagedHarness := func(name, cliID, version, description, image, command string) error {
			rec := core.NewRecord(harnessesColl)
			envTemplate := map[string]string{
				"HARNESS_ADAPTER_SECRET": "{{.__adapter_secret}}",
				// entrypoint.sh's per-harness branching used to key off the
				// container's $1, which is always "--cmd" (main.go parses it
				// as a named flag, not a positional arg) -- that check could
				// never actually match "opencode". This is a real,
				// deliberate literal value (not a Go-template expansion; a
				// plain string with no {{}} renders as itself), so
				// entrypoint.sh can branch on it directly and correctly.
				"POCKETCODER_HARNESS_CLI_ID": cliID,
			}
			if cliID == "opencode" {
				// The peer entrypoint discovers installed models through this
				// private endpoint and exports OPENCODE_CONFIG_CONTENT.
				envTemplate["OLLAMA_HOST"] = "{{.__ollama_host}}"
			}
			rec.Set("name", name)
			rec.Set("cli_id", cliID)
			rec.Set("version", version)
			rec.Set("description", description)
			rec.Set("acp_transport", "stdio")
			rec.Set("container_image", image)
			rec.Set("provider_fanout", cliID == "opencode")
			rec.Set("launch_template", map[string]any{
				"cmd":          []string{"--cmd", command, "--port", "3000"},
				"port":         3000,
				"env_template": envTemplate,
			})
			rec.Set("supports_live_config", true)
			rec.Set("supports_ollama", cliID == "opencode")
			rec.Set("supports_session_delete", cliID != "opencode")
			rec.Set("supports_additional_directories", cliID != "opencode")
			if err := app.Save(rec); err != nil {
				return fmt.Errorf("seed %s harness: %w", cliID, err)
			}
			return nil
		}
		if err := seedManagedHarness(
			"Claude Code", "claude-code", "0.64.2",
			"Claude Agent SDK through the official ACP adapter.",
			"pocketcoder-harness-claude-code:0.64.2", "claude-agent-acp",
		); err != nil {
			return err
		}
		if err := seedManagedHarness(
			"Codex", "codex", "1.1.9",
			"OpenAI Codex through the official ACP adapter.",
			"pocketcoder-harness-codex:1.1.9", "codex-acp",
		); err != nil {
			return err
		}
		if err := seedManagedHarness(
			"OpenCode", "opencode", "1.18.11",
			"OpenCode through its native ACP server.",
			"pocketcoder-harness-opencode:1.18.11", "opencode acp",
		); err != nil {
			return err
		}

		ensureProvider := func(providerID, displayName string) (*core.Record, error) {
			if existing, err := app.FindFirstRecordByFilter("providers", "provider_id = {:id}", map[string]any{"id": providerID}); err == nil {
				return existing, nil
			}
			coll, err := app.FindCollectionByNameOrId("providers")
			if err != nil {
				return nil, err
			}
			rec := core.NewRecord(coll)
			rec.Set("provider_id", providerID)
			rec.Set("name", displayName)
			if err := app.Save(rec); err != nil {
				return nil, fmt.Errorf("seed placeholder provider %s: %w", providerID, err)
			}
			return rec, nil
		}
		pinHarnessProvider := func(harness, provider *core.Record, supportsOAuth bool, authenticator string) error {
			coll, err := app.FindCollectionByNameOrId("harness_providers")
			if err != nil {
				return err
			}
			rec := core.NewRecord(coll)
			rec.Set("harness", harness.Id)
			rec.Set("provider", provider.Id)
			rec.Set("supports_oauth", supportsOAuth)
			rec.Set("oauth_authenticator", authenticator)
			rec.Set("is_pinned", true)
			return app.Save(rec)
		}
		anthropic, err := ensureProvider("anthropic", "Anthropic")
		if err != nil {
			return err
		}
		openai, err := ensureProvider("openai", "OpenAI")
		if err != nil {
			return err
		}
		claudeCodeHarness, err := app.FindFirstRecordByFilter("harnesses", "cli_id = 'claude-code'", nil)
		if err != nil {
			return err
		}
		if err := pinHarnessProvider(claudeCodeHarness, anthropic, true, "claude"); err != nil {
			return fmt.Errorf("pin claude-code/anthropic: %w", err)
		}
		codexHarness, err := app.FindFirstRecordByFilter("harnesses", "cli_id = 'codex'", nil)
		if err != nil {
			return err
		}
		if err := pinHarnessProvider(codexHarness, openai, true, "codex"); err != nil {
			return fmt.Errorf("pin codex/openai: %w", err)
		}

		return nil
	}, func(app core.App) error {
		// No-op: matches 1756000000_schema.go's down and this repo's
		// existing deletion-migration precedent — no data to protect.
		return nil
	})
}
