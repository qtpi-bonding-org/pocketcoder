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

// Custom event constructors for AG-UI.
//
// PocketCoder uses four CUSTOM events (`pocketcoder:tool`, `pocketcoder:diff`,
// `pocketcoder:terminal`, `pocketcoder:content`) to carry structured per-item
// enrichment that AG-UI's standard timeline types can't represent on their own.
// `rawEvent` is the redaction-safe fallback for unmapped ACP update variants —
// it never leaks the original `_meta` blob or vendor internals to the client.
package agui

import (
	"github.com/ag-ui-protocol/ag-ui/sdks/community/go/pkg/core/events"
	acpsdk "github.com/coder/acp-go-sdk"
)

// customTool emits `pocketcoder:tool` carrying identifier, title, kind, status,
// and follow-along file locations. Mirrors ACP's startTool/updateTool arms.
func customTool(id, title, kind, status string, locations []acpsdk.ToolCallLocation) events.Event {
	locs := make([]map[string]any, 0, len(locations))
	for _, l := range locations {
		m := map[string]any{"path": l.Path}
		if l.Line != nil {
			m["line"] = *l.Line
		}
		locs = append(locs, m)
	}
	return events.NewCustomEvent("pocketcoder:tool", events.WithValue(map[string]any{
		"toolCallId": id,
		"title":      title,
		"kind":       kind,
		"status":     status,
		"locations":  locs,
	}))
}

// customDiff emits `pocketcoder:diff` for a single tool-call diff hunk.
func customDiff(toolCallID string, d ToolDiff) events.Event {
	return events.NewCustomEvent("pocketcoder:diff", events.WithValue(map[string]any{
		"toolCallId": toolCallID,
		"path":       d.Path,
		"oldText":    d.OldText,
		"newText":    d.NewText,
	}))
}

// customTerminal emits `pocketcoder:terminal` to attach a terminal handle to a
// tool call so the UI can stream its output.
func customTerminal(toolCallID string, term ToolTerminal) events.Event {
	return events.NewCustomEvent("pocketcoder:terminal", events.WithValue(map[string]any{
		"toolCallId": toolCallID,
		"terminalId": term.TerminalID,
		"type":       term.Type,
	}))
}

// customContent emits `pocketcoder:content` for media-bearing message chunks
// (image / audio / resource / resource_link) that AG-UI's TEXT_MESSAGE_*
// events can't represent on their own.
func customContent(messageID string, m MediaDescriptor) events.Event {
	return events.NewCustomEvent("pocketcoder:content", events.WithValue(map[string]any{
		"messageId": messageID,
		"kind":      m.Kind,
		"mimeType":  m.MimeType,
		"uri":       m.URI,
		"name":      m.Name,
		"size":      m.Size,
	}))
}

// rawEvent is the redacted fallback emitted for any unmapped ACP update
// variant. It only ships `{"unmapped": <kind>}` (plus source); the payload
// argument is intentionally ignored so ACP `_meta` / cost blobs cannot leak.
// Callers debug-gate by choosing to emit this at all; the default stays
// redacted per the spec.
func rawEvent(kind string, _ any) events.Event {
	return events.NewRawEvent(map[string]any{"unmapped": kind}, events.WithSource("acp"))
}
