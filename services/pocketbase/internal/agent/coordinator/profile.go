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

	acpsdk "github.com/coder/acp-go-sdk"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/acp"
)

// SessionProfile is the per-session configuration resolved from a chat's
// agent definition (poco_config). Not every field is deliverable over ACP
// today — see ProfileApplier.
type SessionProfile struct {
	Model, Provider, Instructions, Cwd string
	AdditionalDirectories              []string
	McpServers                         []acpsdk.McpServer
	Mode                               acpsdk.SessionModeId
}

// mcpServers returns the profile's MCP servers as a non-nil slice. Goose's
// session/new|load deserializer rejects a null mcpServers with -32602
// "invalid type: null, expected a sequence", so a chat with no MCP servers
// must still serialize the field as an empty array.
func (p SessionProfile) mcpServers() []acpsdk.McpServer {
	if p.McpServers == nil {
		return []acpsdk.McpServer{}
	}
	return p.McpServers
}

// additionalDirectories returns the profile's extra directories as a non-nil
// slice, for the same Goose-contract reason as mcpServers.
func (p SessionProfile) additionalDirectories() []string {
	if p.AdditionalDirectories == nil {
		return []string{}
	}
	return p.AdditionalDirectories
}

// ProfileFunc resolves a SessionProfile for the run currently starting.
// Injected from internal/api, mirroring the existing ResolveSession closure,
// so the coordinator stays PocketBase-agnostic.
type ProfileFunc func(context.Context) (SessionProfile, error)

// ProfileApplier delivers the parts of a SessionProfile that ACP allows to
// be set post session/new|load.
type ProfileApplier interface {
	Apply(ctx context.Context, conn acp.Conn, sessionID string, p SessionProfile) error
}

// GlobalConfigApplier delivers only what ACP allows post-create today: the
// session mode. Model/provider/prompt are delivered out-of-band by the
// render pipeline + restart (spec §4).
type GlobalConfigApplier struct{}

func (GlobalConfigApplier) Apply(ctx context.Context, conn acp.Conn, sessionID string, p SessionProfile) error {
	if p.Mode == "" {
		return nil
	}
	_, err := conn.SetSessionMode(ctx, acpsdk.SetSessionModeRequest{
		SessionId: acpsdk.SessionId(sessionID), ModeId: p.Mode,
	})
	return err
}

// PerSessionApplier is the future path (Goose #7596): it will additionally
// deliver model/instructions/recipe per session. Stub until the capability
// exists.
type PerSessionApplier struct{}

func (PerSessionApplier) Apply(ctx context.Context, conn acp.Conn, sessionID string, p SessionProfile) error {
	return GlobalConfigApplier{}.Apply(ctx, conn, sessionID, p) // no extra capability yet
}

// selectApplier gates on advertised capabilities. Today no SDK field
// describes per-session model/prompt config (#7596 unshipped), so this
// always returns the global applier (spec §4/§S8).
func selectApplier(init *acpsdk.InitializeResponse) ProfileApplier {
	return GlobalConfigApplier{}
}
