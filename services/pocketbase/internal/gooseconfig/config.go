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
