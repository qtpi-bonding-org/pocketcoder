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
	"fmt"

	acpsdk "github.com/coder/acp-go-sdk"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/acp"
)

// Target identifies the harness_instances row a session should dial —
// empty means "use Coordinator.Config's compose-managed defaults" (the
// convention harness_instances.acp_endpoint/.secret already use).
type Target struct {
	URL, Secret string
}

// SessionProfile is the per-session configuration resolved from a chat's
// agent definition (poco_config). Not every field is deliverable over ACP
// today — see ProfileApplier.
type SessionProfile struct {
	Model, Provider, Instructions, Cwd string
	AdditionalDirectories              []string
	McpServers                         []acpsdk.McpServer
	Mode                               acpsdk.SessionModeId

	Target                  Target
	ResolvedInstanceID      string // the harness_instances id this chat resolves to right now
	PinnedInstanceID        string // the harness_instances id goose_sessions.harness_instance already points at (empty if none yet)
	SupportsLiveConfig      bool
	SupportsGooseExtensions bool
	SingleConnectionOnly    bool
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
	Apply(ctx context.Context, conn acp.Conn, sessionID string, p SessionProfile, modes *acpsdk.SessionModeState) error
}

// GlobalConfigApplier delivers only what ACP allows post-create today: the
// session mode. Model/provider/prompt are delivered out-of-band by the
// render pipeline + restart (spec §4).
type GlobalConfigApplier struct{}

func (GlobalConfigApplier) Apply(ctx context.Context, conn acp.Conn, sessionID string, p SessionProfile, modes *acpsdk.SessionModeState) error {
	if p.Mode == "" {
		return nil
	}
	if modes != nil && !modeAdvertised(modes, p.Mode) {
		return nil // logging is the caller's job at the call site, per existing logging conventions in this file
	}
	_, err := conn.SetSessionMode(ctx, acpsdk.SetSessionModeRequest{
		SessionId: acpsdk.SessionId(sessionID), ModeId: p.Mode,
	})
	return err
}

func modeAdvertised(modes *acpsdk.SessionModeState, mode acpsdk.SessionModeId) bool {
	for _, m := range modes.AvailableModes {
		if m.Id == mode {
			return true
		}
	}
	return false
}

// systemPromptSetParams mirrors Goose's SetSessionSystemPromptRequest
// (goose-sdk-types/src/custom_requests.rs) — no typed Go SDK support
// exists for this custom method, so the shape is hand-rolled and must be
// kept in sync with that Rust struct if Goose's wire format changes.
type systemPromptSetParams struct {
	SessionID    string `json:"sessionId"`
	SystemPrompt string `json:"systemPrompt"`
}

// PerSessionApplier delivers model/provider/instructions live, in addition
// to mode. Confirmed against Goose v1.43.0 source
// (spikes/goose-acp-config-surface/README.md items 1-3): provider and
// model are standard ACP session/set_config_option calls with configId
// "provider"/"model"; instructions go through Goose's custom
// _goose/unstable/session/system-prompt/set method via CallExtension,
// since no typed SDK support exists for it.
type PerSessionApplier struct{}

func (PerSessionApplier) Apply(ctx context.Context, conn acp.Conn, sessionID string, p SessionProfile, modes *acpsdk.SessionModeState) error {
	if err := (GlobalConfigApplier{}).Apply(ctx, conn, sessionID, p, modes); err != nil {
		return err
	}
	if p.SupportsLiveConfig {
		if p.Provider != "" {
			if _, err := conn.SetSessionConfigOption(ctx, acpsdk.SetSessionConfigOptionRequest{
				ValueId: &acpsdk.SetSessionConfigOptionValueId{
					SessionId: acpsdk.SessionId(sessionID),
					ConfigId:  "provider",
					Value:     acpsdk.SessionConfigValueId(p.Provider),
				},
			}); err != nil {
				return fmt.Errorf("apply provider: %w", err)
			}
		}
		if p.Model != "" {
			if _, err := conn.SetSessionConfigOption(ctx, acpsdk.SetSessionConfigOptionRequest{
				ValueId: &acpsdk.SetSessionConfigOptionValueId{
					SessionId: acpsdk.SessionId(sessionID),
					ConfigId:  "model",
					Value:     acpsdk.SessionConfigValueId(p.Model),
				},
			}); err != nil {
				return fmt.Errorf("apply model: %w", err)
			}
		}
	}
	if p.SupportsGooseExtensions && p.Instructions != "" {
		if _, err := conn.CallExtension(ctx, "_goose/unstable/session/system-prompt/set", systemPromptSetParams{
			SessionID:    sessionID,
			SystemPrompt: p.Instructions,
		}); err != nil {
			return fmt.Errorf("apply instructions: %w", err)
		}
	}
	return nil
}

// selectApplier always returns PerSessionApplier — the branching that used
// to matter (whether Goose advertised per-session config at all) now lives
// inside PerSessionApplier.Apply itself, gated on the resolved harness's
// own capability flags carried on profile, not on the ACP InitializeResponse
// (which cannot express a Goose-private capability like
// SupportsGooseExtensions in the first place).
func selectApplier(profile SessionProfile) ProfileApplier {
	return PerSessionApplier{}
}
