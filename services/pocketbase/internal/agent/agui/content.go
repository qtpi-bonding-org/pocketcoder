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

package agui

import (
	"encoding/json"
	"fmt"
	"strings"

	acpsdk "github.com/coder/acp-go-sdk"
)

// MediaDescriptor summarizes one non-text ACP content block for downstream UI.
// Exactly one of (text, media) is populated per call to renderContent.
type MediaDescriptor struct {
	Kind     string `json:"kind"`
	MimeType string `json:"mimeType,omitempty"`
	URI      string `json:"uri,omitempty"`
	Name     string `json:"name,omitempty"`
	Size     int    `json:"size,omitempty"`
}

// ToolDiff is the structured shape AG-UI clients render for an ACP diff result.
// Path is required; OldText is omitted for new-file diffs; NewText is the new content.
type ToolDiff struct {
	Path    string `json:"path"`
	OldText string `json:"oldText,omitempty"`
	NewText string `json:"newText"`
}

// ToolTerminal carries the terminal-id pointer for tools that return one.
type ToolTerminal struct {
	TerminalID string `json:"terminalId"`
	Type       string `json:"type,omitempty"`
}

func deref(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}

// renderContent decodes one ACP content block into either text or a media
// descriptor. No variant falls through: unknown/empty returns ok=false so the
// caller emits RAW rather than silently dropping it.
func renderContent(block acpsdk.ContentBlock) (string, *MediaDescriptor, bool) {
	switch {
	case block.Text != nil:
		return block.Text.Text, nil, true
	case block.Image != nil:
		return "", &MediaDescriptor{
			Kind:     "image",
			MimeType: block.Image.MimeType,
			URI:      deref(block.Image.Uri),
		}, true
	case block.Audio != nil:
		return "", &MediaDescriptor{
			Kind:     "audio",
			MimeType: block.Audio.MimeType,
		}, true
	case block.ResourceLink != nil:
		m := &MediaDescriptor{
			Kind:     "resource_link",
			Name:     block.ResourceLink.Name,
			URI:      block.ResourceLink.Uri,
			MimeType: deref(block.ResourceLink.MimeType),
		}
		if block.ResourceLink.Size != nil {
			m.Size = *block.ResourceLink.Size
		}
		return "", m, true
	case block.Resource != nil:
		return "", &MediaDescriptor{Kind: "resource"}, true
	}
	return "", nil, false
}

// renderToolContent splits ACP tool result content into a fallback text
// rendering (for TOOL_CALL_RESULT.content) plus structured diffs/terminals
// (for CUSTOM pocketcoder:{diff,terminal}). rawOutput is the JSON fallback
// when no content blocks are present.
func renderToolContent(content []acpsdk.ToolCallContent, rawOutput any) (string, []ToolDiff, []ToolTerminal, bool, error) {
	var textParts []string
	var diffs []ToolDiff
	var terminals []ToolTerminal
	for _, c := range content {
		switch {
		case c.Content != nil:
			if t, _, ok := renderContent(c.Content.Content); ok && t != "" {
				textParts = append(textParts, t)
			}
		case c.Diff != nil:
			diffs = append(diffs, ToolDiff{
				Path:    c.Diff.Path,
				OldText: deref(c.Diff.OldText),
				NewText: c.Diff.NewText,
			})
		case c.Terminal != nil:
			terminals = append(terminals, ToolTerminal{
				TerminalID: c.Terminal.TerminalId,
				Type:       c.Terminal.Type,
			})
		}
	}
	text := strings.Join(textParts, "\n")
	has := text != "" || len(diffs) > 0 || len(terminals) > 0
	if !has && rawOutput != nil {
		encoded, err := json.Marshal(rawOutput)
		if err != nil {
			return "", nil, nil, false, fmt.Errorf("encode tool rawOutput: %w", err)
		}
		return string(encoded), nil, nil, true, nil
	}
	return text, diffs, terminals, has, nil
}
