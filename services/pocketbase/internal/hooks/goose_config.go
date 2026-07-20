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
// restarts the goose container so the new config takes effect.
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
// Resolved verify item (spec §13.1): Goose 1.43.0 derives its config dir from
// GOOSE_PATH_ROOT=/goose, reading /goose/config/config.yaml (confirmed via
// `goose info`), NOT ~/.config/goose. The goose container mounts this same
// volume at /goose/config, so files written here reach the path Goose reads.
var gooseConfigDir = "/goose-config"

// gooseUID/GID own the rendered files so the non-root goose user can read them
// (spec §6.4 / §13.4). Confirm against the pinned goose image; -1 leaves
// ownership unchanged (dev host).
var gooseUID, gooseGID = 1000, 1000

// RegisterGooseConfigHooks wires CRUD events on the agent-definition
// collections to a single render+restart handler, and runs an initial render
// on serve startup (no restart — goose may not exist yet).
func RegisterGooseConfigHooks(app core.App) {
	log.Println("🪿 [GooseConfig] Registering Goose config hooks...")

	handler := func(e *core.RecordEvent) error {
		return renderAndRestart("[GooseConfig]", func() error { return renderGooseConfig(app) }, GooseContainer, e)
	}

	for _, coll := range []string{"poco_configs", "provider_keys", "tool_permissions", "harness_models", "prompts"} {
		registerCrudHooks(app, coll, handler)
	}

	app.OnServe().BindFunc(func(e *core.ServeEvent) error {
		if err := renderGooseConfig(app); err != nil {
			log.Printf("⚠️ [GooseConfig] initial render failed: %v", err)
		}
		return e.Next()
	})
}

// renderGooseConfig walks the agent-definition collections and writes the two
// files Goose consumes: config.yaml (model/provider/mode + extensions
// allowlist) and keys.env (merged provider_keys env_vars). Returns nil if
// there is no default poco_config — Goose then runs on compose-env defaults.
func renderGooseConfig(app core.App) error {
	if err := os.MkdirAll(gooseConfigDir, 0o755); err != nil {
		return fmt.Errorf("mkdir goose config dir: %w", err)
	}

	// keys.env from every provider_keys row. Later rows win on collision;
	// RenderKeysEnv sorts the merged result.
	keyRecs, err := app.FindRecordsByFilter("provider_keys", "1=1", "", 0, 0)
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

	// config.yaml from the default poco_config + tool permissions.
	def, err := defaultPocoConfig(app)
	if err != nil {
		return err
	}
	if def == nil {
		log.Println("ℹ️  [GooseConfig] no default poco_config; goose runs on compose-env defaults")
		return nil
	}

	in, dropped, err := configInputFor(app, def)
	if err != nil {
		return err
	}
	for _, d := range dropped {
		log.Printf("⚠️ [GooseConfig] %s", d)
	}

	yamlBytes, err := gooseconfig.RenderConfigYAML(in)
	if err != nil {
		return fmt.Errorf("render config.yaml: %w", err)
	}
	return writeGoose("config.yaml", yamlBytes, 0o640)
}

// defaultPocoConfig returns the single agent definition that drives the
// global goose config, applying the spec §5.2 tie-break: is_default=true,
// oldest-on-multiple (take first), nil-on-none.
func defaultPocoConfig(app core.App) (*core.Record, error) {
	recs, err := app.FindRecordsByFilter("poco_configs", "is_default = true", "created", 0, 0)
	if err != nil {
		return nil, fmt.Errorf("query default poco_configs: %w", err)
	}
	if len(recs) == 0 {
		return nil, nil
	}
	if len(recs) > 1 {
		log.Printf("⚠️ [GooseConfig] %d poco_configs marked is_default; using oldest %q", len(recs), recs[0].GetString("name"))
	}
	return recs[0], nil
}

// configInputFor resolves the provider/model/mode + tool allowlist for the
// given default poco_config. Field names are verified against
// 1748000100_acp_schema.go:
//
//	poco_configs.harness_model → harness_models.id
//	harness_models.harness_model_id  → GOOSE_MODEL
//	harness_models.model → models.id  → models.provider  → GOOSE_PROVIDER
//
// `mode` is read from poco_configs.mode (added by the Task 5 migration; absent
// today → empty string, which RenderConfigYAML serializes as GOOSE_MODE: "").
func configInputFor(app core.App, def *core.Record) (gooseconfig.ConfigInput, []string, error) {
	in := gooseconfig.ConfigInput{
		Mode: def.GetString("mode"),
	}

	if hmID := def.GetString("harness_model"); hmID != "" {
		hm, err := app.FindRecordById("harness_models", hmID)
		if err != nil {
			return in, nil, fmt.Errorf("resolve poco_configs.harness_model=%s: %w", hmID, err)
		}
		in.Model = hm.GetString("harness_model_id")
		if mID := hm.GetString("model"); mID != "" {
			m, err := app.FindRecordById("models", mID)
			if err != nil {
				return in, nil, fmt.Errorf("resolve harness_models.model=%s: %w", mID, err)
			}
			in.Provider = m.GetString("provider")
		}
	}

	// Tool allowlist: active global rows + rows scoped to this poco_config
	// (poco_config is either empty for global or matches def.Id).
	perms, err := app.FindRecordsByFilter("tool_permissions", "active = true", "", 0, 0)
	if err != nil {
		return in, nil, fmt.Errorf("query tool_permissions: %w", err)
	}
	defID := def.Id
	rows := make([]gooseconfig.PermRow, 0, len(perms))
	for _, p := range perms {
		scope := p.GetString("poco_config")
		if scope != "" && scope != defID {
			continue
		}
		rows = append(rows, gooseconfig.PermRow{
			Tool:    p.GetString("tool"),
			Pattern: p.GetString("pattern"),
			Action:  p.GetString("action"),
		})
	}
	allow, dropped := gooseconfig.RenderPermissions(rows)
	if len(allow) > 0 {
		in.AvailableTools = map[string][]string{gooseconfig.DefaultToolExtension: allow}
	}
	return in, dropped, nil
}

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
