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

	events "github.com/ag-ui-protocol/ag-ui/sdks/community/go/pkg/core/events"
	acpsdk "github.com/coder/acp-go-sdk"
	"github.com/pocketbase/pocketbase/core"
)

// AgentRuntime is the execution surface shared by agent and schedule routes.
type AgentRuntime interface {
	StartPrompt(chatID, prompt string, resolve ResolveSession, profileFn ProfileFunc, created OnSessionCreated, finished OnRunFinished) (string, error)
	Attach(chatID string, cursor int) Attachment
	NextSeq(chatID string) int
	StreamColdReplay(ctx context.Context, chatID, sessionID string, profileFn ProfileFunc, emit func(seq int, ev events.Event) error) error
	Cancel(ctx context.Context, chatID string) error
	SetMode(ctx context.Context, chatID, modeID string) error
	SetConfigOption(ctx context.Context, chatID string, req acpsdk.SetSessionConfigOptionRequest) error
	Approve(ctx context.Context, chatID, requestID, optionID string) error
	DenyPermission(chatID, requestID string) error
	ResolveElicitation(chatID, id string, resp acpsdk.UnstableCreateElicitationResponse) error
	DeleteSession(ctx context.Context, app core.App, chatID string) error
	Shutdown(ctx context.Context)
}
