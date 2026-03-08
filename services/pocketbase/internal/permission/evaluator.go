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

// @pocketcoder-core: Permission Evaluator. All permissions default to "draft" (user approval required).
package permission

import (
	"log"

	"github.com/pocketbase/pocketbase/core"
)

// EvaluationInput represents the data needed to evaluate a permission request.
type EvaluationInput struct {
	Permission string
	Patterns   []string
	Metadata   map[string]any
}

// Evaluate checks a permission request. Currently all requests default to
// "draft" status, requiring explicit user approval via the Flutter UI.
func Evaluate(app core.App, input EvaluationInput) (bool, string) {
	log.Printf("🛡️ [Authority] Evaluating Verb: %s, Nouns: %v", input.Permission, input.Patterns)

	return false, "draft"
}
