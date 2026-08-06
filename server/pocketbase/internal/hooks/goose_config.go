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

// @pocketcoder-core: Goose Config Hooks. Renders config.yaml + keys.env from
// PocketBase agent-definition records, writes them goose-uid-owned, then
// restarts the goose container so the new config takes effect. Permission
// policy is enforced centrally by the coordinator's ACP callback; this hook
// never calls a Goose-private permission API.
package hooks

import (
	"fmt"
	"log"
	"os"
	"path/filepath"

	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/gooseconfig"
)

// gooseConfigDir is the PocketBase-side mount of the shared goose_config volume.
// Goose 1.43.0 derives its config dir from GOOSE_PATH_ROOT=/goose, reading
// /goose/config/config.yaml (confirmed via `goose info`), NOT ~/.config/goose.
var gooseConfigDir = "/goose-config"

// gooseUID/GID own the rendered files so the non-root goose user can read them.
var gooseUID, gooseGID = 1000, 1000

// RegisterGooseConfigHooks renders only system-level control-plane config on
// startup. User profiles, prompts, skills, and provider keys belong to the
// dynamically provisioned per-user harness containers and must never be
// copied into the shared control-plane Goose container.
func RegisterGooseConfigHooks(app core.App) {
	log.Println("🪿 [GooseConfig] Registering Goose config hooks...")

	app.OnServe().BindFunc(func(e *core.ServeEvent) error {
		if err := renderGooseConfig(app); err != nil {
			log.Printf("⚠️ [GooseConfig] initial render failed: %v", err)
		}
		return e.Next()
	})
}

// renderGooseConfig walks the agent-definition collections and writes the two
// files Goose consumes: config.yaml (model/provider/mode) and keys.env
// (merged provider_keys env_vars). Returns nil if there is no default
// agent_profile — Goose then runs on compose-env defaults.
func renderGooseConfig(app core.App) error {
	if err := os.MkdirAll(gooseConfigDir, 0o755); err != nil {
		return fmt.Errorf("mkdir goose config dir: %w", err)
	}

	// The compose Goose receives provider credentials from its own compose
	// environment. There are no system provider_keys records to render here.
	keyRecs, err := app.FindRecordsByFilter("provider_keys", "1 = 0", "", 0, 0)
	if err != nil {
		return fmt.Errorf("query provider_keys: %w", err)
	}
	sets := make([]map[string]any, 0, len(keyRecs))
	for _, r := range keyRecs {
		m := map[string]any{}
		if err := r.UnmarshalJSONField("env_vars", &m); err != nil {
			log.Printf("⚠️ [GooseConfig] bad env_vars on provider_keys/%s: %v", r.Id, err)
			continue
		}
		sets = append(sets, m)
	}
	if err := writeGoose("keys.env", gooseconfig.RenderKeysEnv(sets), 0o600); err != nil {
		return err
	}

	def, err := defaultPocoConfig(app)
	if err != nil {
		return err
	}
	if def == nil {
		log.Println("ℹ️  [GooseConfig] no default agent_profile; goose runs on compose-env defaults")
		return nil
	}

	in, err := configInputFor(app, def)
	if err != nil {
		return err
	}

	yamlBytes, err := gooseconfig.RenderConfigYAML(in)
	if err != nil {
		return fmt.Errorf("render config.yaml: %w", err)
	}
	return writeGoose("config.yaml", yamlBytes, 0o640)
}

// defaultPocoConfig returns the single agent definition that drives the global
// goose config, applying the spec §5.2 tie-break: is_default=true, deterministic
// first-on-multiple, nil-on-none.
func defaultPocoConfig(app core.App) (*core.Record, error) {
	recs, err := app.FindRecordsByFilter("agent_profiles", "is_default = true && is_system = true", "name", 0, 0)
	if err != nil {
		return nil, fmt.Errorf("query default agent_profiles: %w", err)
	}
	if len(recs) == 0 {
		return nil, nil
	}
	if len(recs) > 1 {
		log.Printf("⚠️ [GooseConfig] %d agent_profiles marked is_default; using first by name %q", len(recs), recs[0].GetString("name"))
	}
	return recs[0], nil
}

// configInputFor resolves the provider/model/mode for the given default
// agent_profile. Tool permissions are enforced by the coordinator.
func configInputFor(app core.App, def *core.Record) (gooseconfig.ConfigInput, error) {
	in := gooseconfig.ConfigInput{
		Mode: "approve",
	}
	if modeID := def.GetString("permission_mode"); modeID != "" {
		mode, err := app.FindRecordById("permission_modes", modeID)
		if err != nil {
			return in, fmt.Errorf("resolve agent_profiles.permission_mode=%s: %w", modeID, err)
		}
		in.Mode = mode.GetString("base_session_mode")
	}

	if hmID := def.GetString("harness_model"); hmID != "" {
		hm, err := app.FindRecordById("harness_models", hmID)
		if err != nil {
			return in, fmt.Errorf("resolve agent_profiles.harness_model=%s: %w", hmID, err)
		}
		in.Model = hm.GetString("harness_model_id")
		if mID := hm.GetString("model"); mID != "" {
			m, err := app.FindRecordById("models", mID)
			if err != nil {
				return in, fmt.Errorf("resolve harness_models.model=%s: %w", mID, err)
			}
			in.Provider = m.GetString("provider")
		}
	}
	return in, nil
}

// activeToolPermissionRows resolves the active rows in the default agent
// profile's selected permission mode.
// writeGoose writes data to gooseConfigDir/name with the given mode and best-
// effort chown to the goose uid. On dev hosts the chown may fail (not root)
// — log, don't fail the render.
func writeGoose(name string, data []byte, mode os.FileMode) error {
	path := filepath.Join(gooseConfigDir, name)
	if err := os.WriteFile(path, data, mode); err != nil {
		return fmt.Errorf("write %s: %w", name, err)
	}
	if gooseUID >= 0 && gooseGID >= 0 {
		if err := os.Chown(path, gooseUID, gooseGID); err != nil {
			log.Printf("⚠️ [GooseConfig] chown %s failed (dev host?): %v", name, err)
		}
	}
	return nil
}
