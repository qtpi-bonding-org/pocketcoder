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

package hooks

import (
	"database/sql"
	"errors"
	"fmt"
	"log"
	"path/filepath"
	"strings"

	"github.com/pocketbase/pocketbase/core"
)

// RegisterChatsHarnessPinHook registers a fast-fail UX check for two of the
// design spec's §5.6/§5.8 invariants. It is NOT the source of truth for
// either — establishSession's own check (coordinator package) is what
// actually prevents a mismatched dial. Uses the non-Request hook variants
// specifically (per hooks/timestamps.go's precedent) so backend app.Save
// calls — including the agent role's own writes — are not skipped.
func RegisterChatsHarnessPinHook(app core.App) {
	app.OnRecordUpdate("chats").BindFunc(func(e *core.RecordEvent) error {
		orig := e.Record.Original()
		if orig != nil && orig.GetString("harness") != e.Record.GetString("harness") {
			hasSession, err := chatHasAgentSession(e.App, e.Record.Id)
			if err != nil {
				return err
			}
			if hasSession {
				return fmt.Errorf("this chat's harness cannot be changed after a session has been created — start a new chat")
			}
		}
		if err := validateWorkspaceOverride(e.Record); err != nil {
			return err
		}
		return e.Next()
	})
	app.OnRecordCreate("chats").BindFunc(func(e *core.RecordEvent) error {
		if err := validateWorkspaceOverride(e.Record); err != nil {
			return err
		}
		return e.Next()
	})
}

func chatHasAgentSession(app core.App, chatID string) (bool, error) {
	_, err := app.FindFirstRecordByFilter("agent_sessions", "chat = {:c}", map[string]any{"c": chatID})
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return false, nil
		}
		return false, err
	}
	return true, nil
}

const workspaceRoot = "/workspace" // duplicated from internal/api/profile.go's identical check deliberately — these are two different packages and this hook must not import internal/api

func validateWorkspaceOverride(rec *core.Record) error {
	var folders []string
	if err := rec.UnmarshalJSONField("workspace_override", &folders); err != nil {
		log.Printf("⚠️ [Chats] Failed to parse workspace_override: %v", err)
	}
	for _, f := range folders {
		clean := filepath.Clean(f)
		if clean != workspaceRoot && !strings.HasPrefix(clean, workspaceRoot+"/") {
			return fmt.Errorf("workspace_override path %q is outside %s", f, workspaceRoot)
		}
	}
	return nil
}
