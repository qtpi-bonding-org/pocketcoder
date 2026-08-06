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

// ConfigInput captures the resolved default agent_profile fields needed to render
// a Goose config.yaml. The hook layer fills this from the default agent_profile;
// this package stays pure (no I/O, no PB types).
//
// Deliberately does NOT carry tool permissions or extensions: Goose is the
// sole writer of config.yaml's `extensions` key (via _goose/unstable/
// config/extensions/add, called by hooks.RegisterMcpGatewayExtension).
// Permission policy is enforced centrally by the ACP coordinator so peer
// harnesses and Goose share the same PocketBase decision point.
type ConfigInput struct {
	Provider, Model, Mode string
	// Instructions is intentionally omitted: config.yaml has no documented
	// global system-prompt key. Add only if verification confirms one.
}

// RenderConfigYAML renders a Goose config.yaml: GOOSE_PROVIDER/MODEL/MODE
// only. No secrets (they live in keys.env). No extensions (Goose owns that
// key exclusively — see ConfigInput's doc comment).
func RenderConfigYAML(in ConfigInput) ([]byte, error) {
	doc := map[string]any{
		"GOOSE_PROVIDER": in.Provider,
		"GOOSE_MODEL":    in.Model,
		"GOOSE_MODE":     in.Mode,
	}
	return yaml.Marshal(doc)
}
