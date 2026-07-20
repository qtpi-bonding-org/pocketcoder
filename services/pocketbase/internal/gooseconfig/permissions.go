package gooseconfig

import (
	"fmt"
	"sort"
)

// DefaultToolExtension is the single builtin extension all tool_permissions
// rows are assumed to govern (see Task 2 DECISION); per-extension policy is a
// future extension-field enhancement.
const DefaultToolExtension = "developer"

type PermRow struct{ Tool, Pattern, Action string }

// RenderPermissions maps rich allow/ask/deny rows onto Goose's available_tools
// allowlist (non-empty = only those tools) for the default extension. Lossy by
// design (spec §7): non-"*" patterns are discarded, per-tool `ask` has no
// equivalent, and same-tool allow+deny resolves deny-wins. Every degradation is
// returned in `dropped` for the caller to log.
func RenderPermissions(rows []PermRow) ([]string, []string) {
	allow := map[string]struct{}{}
	deny := map[string]struct{}{}
	var dropped []string

	for _, r := range rows {
		if r.Pattern != "" && r.Pattern != "*" {
			dropped = append(dropped, fmt.Sprintf("pattern dropped (Goose allowlist is tool-name-only): %s pattern=%q", r.Tool, r.Pattern))
		}
		switch r.Action {
		case "allow":
			allow[r.Tool] = struct{}{}
		case "deny":
			deny[r.Tool] = struct{}{}
		case "ask":
			dropped = append(dropped, fmt.Sprintf("ask dropped (no per-tool Goose equivalent; governed by mode): %s", r.Tool))
		}
	}

	var tools []string
	for tool := range allow {
		if _, denied := deny[tool]; denied {
			dropped = append(dropped, fmt.Sprintf("allow/deny conflict, deny wins: %s", tool))
			continue
		}
		tools = append(tools, tool)
	}
	// deny-only (no allow rows) intentionally yields no allowlist: we cannot
	// enumerate the full tool set to subtract from.
	sort.Strings(tools)
	return tools, dropped
}
