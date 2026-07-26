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

// @pocketcoder-core: Cognee Config Hooks. Renders cognee.env from the
// cognee_config collection, then restarts the cognee container so the new
// settings take effect. cognee's LLM credentials are self-contained here —
// deliberately not derived from provider_keys (per-user, no "which user"
// story for a global background service) or ANTHROPIC_API_KEY (goose's own
// key, a separate concern) — see spec 2026-07-24-cognee-agent-memory-design.md §3.4.
package hooks

import (
	"fmt"
	"log"
	"os"
	"path/filepath"

	"github.com/pocketbase/pocketbase/core"
)

// cogneeConfigDir is the PocketBase-side mount of the shared cognee_config
// volume (docker-compose.yml).
var cogneeConfigDir = "/cognee-config"

// SetCogneeConfigDirForTest overrides cogneeConfigDir for tests. Not for
// production use.
func SetCogneeConfigDirForTest(dir string) {
	cogneeConfigDir = dir
}

// RegisterCogneeConfigHooks wires CRUD events on cognee_config to a
// render+restart handler, and runs an initial render on serve startup.
func RegisterCogneeConfigHooks(app core.App) {
	log.Println("🧠 [CogneeConfig] Registering cognee config hooks...")

	handler := func(e *core.RecordEvent) error {
		return renderAndRestart("[CogneeConfig]", func() error { return renderCogneeConfig(app) }, CogneeContainer, e)
	}
	registerCrudHooks(app, "cognee_config", handler)

	app.OnServe().BindFunc(func(e *core.ServeEvent) error {
		if err := renderCogneeConfig(app); err != nil {
			log.Printf("⚠️ [CogneeConfig] initial render failed: %v", err)
		}
		return e.Next()
	})
}

// renderCogneeConfig writes cognee.env from the single cognee_config record,
// if one exists. Returns nil (no-op) if there is no row — cognee then runs
// on whatever's baked into its own image/compose defaults.
func renderCogneeConfig(app core.App) error {
	if err := os.MkdirAll(cogneeConfigDir, 0o755); err != nil {
		return fmt.Errorf("mkdir cognee config dir: %w", err)
	}

	recs, err := app.FindRecordsByFilter("cognee_config", "1=1", "", 1, 0)
	if err != nil {
		return fmt.Errorf("query cognee_config: %w", err)
	}
	if len(recs) == 0 {
		log.Println("ℹ️  [CogneeConfig] no cognee_config row; cognee runs on compose-env defaults")
		return nil
	}
	rec := recs[0]

	lines := fmt.Sprintf(
		"LLM_PROVIDER=%s\nLLM_MODEL=%s\nLLM_BASE_URL=%s\nLLM_API_KEY=%s\n",
		rec.GetString("llm_provider"),
		rec.GetString("llm_model"),
		rec.GetString("llm_base_url"),
		rec.GetString("llm_api_key"),
	)

	path := filepath.Join(cogneeConfigDir, "cognee.env")
	if err := os.WriteFile(path, []byte(lines), 0o600); err != nil {
		return fmt.Errorf("write cognee.env: %w", err)
	}
	return nil
}
