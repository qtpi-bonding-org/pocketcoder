package relay

import (
	"log"
	"regexp"
	"strings"
)

// resolveChatID attempts to find a chat associated with an OpenCode session ID.
func (r *RelayService) resolveChatID(sessionID string) string {
	if sessionID == "" {
		return ""
	}

	record, err := r.app.FindFirstRecordByFilter("chats", "opencode_id = {:id}", map[string]any{"id": sessionID})
	if err != nil {
		return ""
	}

	return record.Id
}

// checkWhitelist replicates the "Sovereign Authority" logic from main.go
func (r *RelayService) checkWhitelist(permission string, patterns []interface{}, metadata map[string]interface{}) bool {
	isWhitelisted := false

	// 1. Evaluate Verb (whitelist_actions)
	actions, _ := r.app.FindRecordsByFilter(
		"whitelist_actions",
		"active = true && permission = {:perm}",
		"-created", 100, 0,
		map[string]any{"perm": permission},
	)

	for _, rule := range actions {
		kind := rule.GetString("kind")
		value := rule.GetString("value")
		commandID := rule.GetString("command")

		if permission == "bash" {
			cmdStr, _ := metadata["command"].(string)
			if kind == "strict" && commandID != "" {
				cmdRec, _ := r.app.FindFirstRecordByFilter("commands", "id = {:id} && command = {:cmd}", map[string]any{"id": commandID, "cmd": cmdStr})
				if cmdRec != nil {
					isWhitelisted = true
					break
				}
			} else if kind == "pattern" && value != "" {
				if matchWildcard(cmdStr, value) {
					isWhitelisted = true
					break
				}
			}
		} else {
			if kind == "pattern" {
				if value == "*" || value == "" {
					isWhitelisted = true
					break
				}
			}
		}
	}

	// 2. Evaluate Noun (whitelist_targets)
	if isWhitelisted && len(patterns) > 0 {
		targets, _ := r.app.FindRecordsByFilter("whitelist_targets", "active = true", "-created", 300, 0, nil)

		for _, p := range patterns {
			pStr, ok := p.(string)
			if !ok || pStr == "" {
				continue
			}
			
			patternMatch := false
			for _, target := range targets {
				if matchWildcard(pStr, target.GetString("pattern")) {
					patternMatch = true
					break
				}
			}
			if !patternMatch {
				isWhitelisted = false
				log.Printf("🛑 [Noun Rejected] %s", pStr)
				break
			}
		}
	}

	return isWhitelisted
}

// matchWildcard implements simple glob-like pattern matching (helper moved from main.go or duplicated for package isolation)
func matchWildcard(str string, pattern string) bool {
	escaped := regexp.QuoteMeta(pattern)
	escaped = strings.ReplaceAll(escaped, "\\*", ".*")
	escaped = strings.ReplaceAll(escaped, "\\?", ".")

	if strings.HasSuffix(escaped, " .*") {
		escaped = escaped[:len(escaped)-3] + "( .*|$|\\n)?"
	}

	re, err := regexp.Compile("(?s)^" + escaped + "$")
	if err != nil {
		return false
	}
	return re.MatchString(str)
}
