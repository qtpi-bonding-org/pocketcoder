package permission

import (
	"log"

	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/utils"
)

// EvaluationInput represents the data needed to evaluate a permission request.
type EvaluationInput struct {
	Permission string
	Patterns   []string
	Metadata   map[string]any
}

// Evaluate checks if a permission request is whitelisted based on actions and targets.
func Evaluate(app core.App, input EvaluationInput) (bool, string) {
	log.Printf("🛡️ [Authority] Evaluating Verb: %s, Nouns: %v", input.Permission, input.Patterns)

	isWhitelisted := false

	// --- A. EVALUATE VERB (whitelist_actions) ---
	actions, _ := app.FindRecordsByFilter(
		"whitelist_actions",
		"active = true && permission = {:perm}",
		"-created", 100, 0,
		map[string]any{"perm": input.Permission},
	)

	for _, rule := range actions {
		kind := rule.GetString("kind")
		value := rule.GetString("value")

		if input.Permission == "bash" {
			cmdStr, _ := input.Metadata["command"].(string)
			// For bash commands, use pattern matching only
			// Note: The "commands" collection was never created, so we removed that dead code path
			if kind == "pattern" && value != "" {
				// Check if the command matches a glob pattern
				if utils.MatchWildcard(cmdStr, value) {
					isWhitelisted = true
					break
				}
			}
		} else {
			// For non-bash tools (read, write, etc), a pattern of "*" allows all.
			if kind == "pattern" {
				if value == "*" || value == "" {
					isWhitelisted = true
					break
				}
			}
		}
	}

	// --- B. EVALUATE NOUN (whitelist_targets) ---
	// If the verb is whitelisted, we must ensure ALL noun patterns (files/dirs) are also whitelisted.
	if isWhitelisted && len(input.Patterns) > 0 {
		targets, _ := app.FindRecordsByFilter("whitelist_targets", "active = true", "-created", 300, 0, nil)

		for _, p := range input.Patterns {
			patternMatch := false
			if p == "" {
				continue
			}
			for _, target := range targets {
				if utils.MatchWildcard(p, target.GetString("pattern")) {
					patternMatch = true
					break
				}
			}
			if !patternMatch {
				isWhitelisted = false
				log.Printf("🛑 [Noun Rejected] Path not in whitelist: %s", p)
				break
			}
		}
	}

	status := "draft"
	if isWhitelisted {
		status = "authorized"
	}

	return isWhitelisted, status
}
