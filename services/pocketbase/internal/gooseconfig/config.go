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

// @pocketcoder-core: Goose Config. Renders config.yaml and keys.env consumed by the c2 goose container.
package gooseconfig

import "gopkg.in/yaml.v3"

// ConfigInput captures the resolved default poco_config fields needed to render
// a Goose config.yaml. The hook layer fills this from the default poco_config
// + RenderPermissions; this package stays pure (no I/O, no PB types).
type ConfigInput struct {
	Provider, Model, Mode string
	AvailableTools        map[string][]string // extension -> allowlist
	// Instructions is intentionally omitted: config.yaml has no documented
	// global system-prompt key (spec §13.5). Add only if verification confirms one.
}

// RenderConfigYAML renders a Goose config.yaml: GOOSE_PROVIDER/MODEL/MODE plus
// an extensions: map of named builtins with available_tools allowlists. No
// secrets (they live in keys.env). No per-chat MCP (delivered over ACP only).
func RenderConfigYAML(in ConfigInput) ([]byte, error) {
	doc := map[string]any{
		"GOOSE_PROVIDER": in.Provider,
		"GOOSE_MODEL":    in.Model,
		"GOOSE_MODE":     in.Mode,
	}
	if len(in.AvailableTools) > 0 {
		exts := map[string]any{}
		for ext, tools := range in.AvailableTools {
			exts[ext] = map[string]any{
				"name":            ext,
				"enabled":         true,
				"available_tools": tools,
			}
		}
		doc["extensions"] = exts
	}
	return yaml.Marshal(doc)
}
