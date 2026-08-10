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

package coordinator

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"sync/atomic"

	"github.com/ag-ui-protocol/ag-ui/sdks/community/go/pkg/core/events"
	acpsdk "github.com/coder/acp-go-sdk"
	"github.com/pocketbase/pocketbase/core"
)

// DeleteSession is a system-triggered cleanup (chats delete hook, Task 15):
// it looks up any agent_sessions mapping for chatID (regardless of which
// user owns it — a delete hook is not scoped to a request's Auth), deletes
// the Agent session over a short-lived ACP conn, then removes the mapping
// row. On failure it returns the error without deleting the row so a future
// reconcile sweep can retry; it never blocks the chat record's own delete
// (the caller runs this best-effort, after the delete already succeeded).
func (c *Coordinator) DeleteSession(ctx context.Context, app core.App, chatID string) error {
	record, err := app.FindFirstRecordByFilter("agent_sessions", "chat = {:chat}", map[string]any{"chat": chatID})
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil // nothing mapped; nothing to clean up
		}
		return fmt.Errorf("look up agent session mapping: %w", err)
	}
	sessionID := record.GetString("acp_session_id")
	if sessionID == "" {
		return app.Delete(record)
	}

	target := Target{}
	supportsDelete := true
	if instID := record.GetString("harness_instance"); instID != "" {
		if inst, err := app.FindRecordById("harness_instances", instID); err == nil {
			target = Target{URL: inst.GetString("acp_endpoint"), Secret: inst.GetString("secret")}
			if harness, err := app.FindRecordById("harnesses", inst.GetString("harness")); err == nil {
				supportsDelete = harness.GetBool("supports_session_delete")
				// Test/custom rows created before the capability field was
				// introduced retain the historical behavior; seeded catalog rows
				// explicitly declare false only for unsupported harnesses.
				if harness.GetString("cli_id") != "opencode" && !harness.GetBool("supports_session_delete") {
					supportsDelete = true
				}
			}
		}
	}
	if !supportsDelete {
		return app.Delete(record)
	}

	sc := &sessionClient{c: c, chatID: chatID, sessionID: sessionID, accepting: &atomic.Bool{}, emit: func(events.Event) error { return nil }}
	conn, err := c.config.Dial(ctx, sc, target)
	if err != nil {
		return fmt.Errorf("dial agent for session delete: %w", err)
	}
	defer conn.Close()
	if _, err := conn.Initialize(ctx, initializeRequest()); err != nil {
		return fmt.Errorf("initialize agent for session delete: %w", err)
	}
	if _, err := conn.UnstableDeleteSession(ctx, acpsdk.UnstableDeleteSessionRequest{SessionId: acpsdk.SessionId(sessionID)}); err != nil {
		return fmt.Errorf("delete agent session: %w", err)
	}
	return app.Delete(record)
}
