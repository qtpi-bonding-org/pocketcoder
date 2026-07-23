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

package gooseconfig

import (
	"fmt"
	"sort"
)

// DefaultToolExtension is the single builtin extension all tool_permissions
// rows are assumed to govern; per-extension policy is a future enhancement.
const DefaultToolExtension = "developer"

type PermRow struct{ Tool, Pattern, Action string }

// Goose's _goose/unstable/tools/permissions/set ToolPermissionLevel enum,
// verified against acp-schema.json's ToolPermissionLevel def.
const (
	PermissionAlwaysAllow = "always_allow"
	PermissionAskBefore   = "ask_before"
	PermissionNeverAllow  = "never_allow"
)

// ToolPermissionEntry mirrors one entry of Goose's
// _goose/unstable/tools/permissions/set request
// (SetToolPermissionsRequest_unstable.toolPermissions[]:
// {toolName, permission}). Plain strings, not acp-go-sdk types — this
// package stays pure (no I/O, no ACP SDK dependency); the hooks layer maps
// this onto the real request struct.
type ToolPermissionEntry struct {
	ToolName   string
	Permission string
}

// RenderToolPermissions maps tool_permissions rows onto Goose's per-tool
// tools/permissions/set entries. Non-"*" patterns are dropped (Goose's
// ToolPermissionEntry is tool-name-only, same limitation the old file-render
// allowlist had). Same-tool conflicts resolve deny > ask > allow — deny
// always wins (noted in dropped); otherwise ask beats allow only because a
// tool can carry both an explicit ask row and a broader allow row and the
// more cautious one should apply. Unlike the old config.yaml allowlist,
// "ask" is never dropped — ask_before is a real permission level here.
func RenderToolPermissions(rows []PermRow) ([]ToolPermissionEntry, []string) {
	actions := map[string]map[string]bool{}
	var dropped []string

	for _, r := range rows {
		if r.Pattern != "" && r.Pattern != "*" {
			dropped = append(dropped, fmt.Sprintf("pattern dropped (Goose tool permissions are tool-name-only): %s pattern=%q", r.Tool, r.Pattern))
		}
		switch r.Action {
		case "allow", "deny", "ask":
		default:
			continue
		}
		if actions[r.Tool] == nil {
			actions[r.Tool] = map[string]bool{}
		}
		actions[r.Tool][r.Action] = true
	}

	tools := make([]string, 0, len(actions))
	for tool := range actions {
		tools = append(tools, tool)
	}
	sort.Strings(tools)

	entries := make([]ToolPermissionEntry, 0, len(tools))
	for _, tool := range tools {
		seen := actions[tool]
		switch {
		case seen["deny"]:
			if seen["allow"] {
				dropped = append(dropped, fmt.Sprintf("allow/deny conflict, deny wins: %s", tool))
			}
			entries = append(entries, ToolPermissionEntry{ToolName: tool, Permission: PermissionNeverAllow})
		case seen["ask"]:
			entries = append(entries, ToolPermissionEntry{ToolName: tool, Permission: PermissionAskBefore})
		case seen["allow"]:
			entries = append(entries, ToolPermissionEntry{ToolName: tool, Permission: PermissionAlwaysAllow})
		}
	}
	return entries, dropped
}
