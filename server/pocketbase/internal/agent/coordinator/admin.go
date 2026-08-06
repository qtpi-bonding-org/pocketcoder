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

// @pocketcoder-core: ACP Transport. Session-free admin connection to Goose for
// callers that need to invoke custom extension methods (tool permissions, MCP
// extensions, skills, schedules — see
// spikes/goose-acp-config-surface/ownership-map.md) without spinning up an
// AG-UI run/session.
package coordinator

import (
	"context"

	acpsdk "github.com/coder/acp-go-sdk"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/acp"
)

// adminClient satisfies acpsdk.Client for connections that never create a
// session. Every server-to-client callback here is unreachable in practice
// (Goose only calls these mid-prompt/mid-tool-call, and AdminConn never
// starts a prompt), so each returns "unsupported" rather than panicking,
// matching the existing sessionClient's own unsupported() helper for the
// file/terminal methods it doesn't implement (run.go:383-402).
type adminClient struct{}

func (adminClient) SessionUpdate(context.Context, acpsdk.SessionNotification) error { return nil }
func (adminClient) ReadTextFile(context.Context, acpsdk.ReadTextFileRequest) (acpsdk.ReadTextFileResponse, error) {
	return acpsdk.ReadTextFileResponse{}, unsupported()
}
func (adminClient) WriteTextFile(context.Context, acpsdk.WriteTextFileRequest) (acpsdk.WriteTextFileResponse, error) {
	return acpsdk.WriteTextFileResponse{}, unsupported()
}
func (adminClient) CreateTerminal(context.Context, acpsdk.CreateTerminalRequest) (acpsdk.CreateTerminalResponse, error) {
	return acpsdk.CreateTerminalResponse{}, unsupported()
}
func (adminClient) KillTerminal(context.Context, acpsdk.KillTerminalRequest) (acpsdk.KillTerminalResponse, error) {
	return acpsdk.KillTerminalResponse{}, unsupported()
}
func (adminClient) TerminalOutput(context.Context, acpsdk.TerminalOutputRequest) (acpsdk.TerminalOutputResponse, error) {
	return acpsdk.TerminalOutputResponse{}, unsupported()
}
func (adminClient) ReleaseTerminal(context.Context, acpsdk.ReleaseTerminalRequest) (acpsdk.ReleaseTerminalResponse, error) {
	return acpsdk.ReleaseTerminalResponse{}, unsupported()
}
func (adminClient) WaitForTerminalExit(context.Context, acpsdk.WaitForTerminalExitRequest) (acpsdk.WaitForTerminalExitResponse, error) {
	return acpsdk.WaitForTerminalExitResponse{}, unsupported()
}
func (adminClient) RequestPermission(context.Context, acpsdk.RequestPermissionRequest) (acpsdk.RequestPermissionResponse, error) {
	return acpsdk.RequestPermissionResponse{}, unsupported()
}
func (adminClient) UnstableCreateElicitation(context.Context, acpsdk.UnstableCreateElicitationRequest) (acpsdk.UnstableCreateElicitationResponse, error) {
	return acpsdk.UnstableCreateElicitationResponse{}, unsupported()
}

// AdminConn dials Goose and completes the initialize handshake for
// session-free custom methods (tool permissions, MCP extensions, skills,
// schedules — see spikes/goose-acp-config-surface/ownership-map.md). It
// does not call session/new. Callers must Close the returned Conn.
// Lifetime is meant to match one PocketBase-side request: dial, make
// whichever calls that request needs, close — not a standing connection.
func (c *Coordinator) AdminConn(ctx context.Context) (acp.Conn, error) {
	conn, err := c.config.Dial(ctx, adminClient{}, Target{})
	if err != nil {
		return nil, err
	}
	if _, err := conn.Initialize(ctx, initializeRequest()); err != nil {
		_ = conn.Close()
		return nil, err
	}
	return conn, nil
}
