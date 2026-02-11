package utils

import (
	"regexp"
	"strings"
)

// MatchWildcard implements a simple glob-like pattern matching (e.g. /workspace/**).
// It converts internal wildcards (*, ?) into regex patterns.
func MatchWildcard(str string, pattern string) bool {
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
