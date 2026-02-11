package relay

import (
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
	// "Always Ask" policy for Poco.
	// We want everything to be a 'draft' so it's gated by the signature.
	return false
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
