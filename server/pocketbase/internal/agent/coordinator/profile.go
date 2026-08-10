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
	"path"
	"strings"

	acpsdk "github.com/coder/acp-go-sdk"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/acp"
)

// Target identifies the harness_instances row a session should dial —
// Empty targets are invalid for production runs. They are retained as a
// zero-value for profile construction and test doubles only.
type Target struct {
	URL, Secret string
}

// SessionProfile is the per-session configuration resolved from a chat's
// agent definition (agent_profile). Not every field is deliverable over ACP
// today — see ProfileApplier.
type SessionProfile struct {
	Model, Provider, Instructions, Cwd string
	AdditionalDirectories              []string
	McpServers                         []acpsdk.McpServer
	Mode                               acpsdk.SessionModeId
	PermissionRules                    []ToolPermissionRule

	Target                        Target
	ResolvedInstanceID            string // the harness_instances id this chat resolves to right now
	PinnedInstanceID              string // the harness_instances id agent_sessions.harness_instance already points at (empty if none yet)
	SupportsLiveConfig            bool
	SingleConnectionOnly          bool
	SupportsSessionDelete         bool
	SupportsAdditionalDirectories bool
}

// ToolPermissionAction is the PocketBase policy decision for one ACP tool
// request. The coordinator is the enforcement point for every harness; no
// harness-specific permission API is authoritative.
type ToolPermissionAction string

const (
	ToolPermissionAllow ToolPermissionAction = "allow"
	ToolPermissionAsk   ToolPermissionAction = "ask"
	ToolPermissionDeny  ToolPermissionAction = "deny"
)

type ToolPermissionRule struct {
	Tool    string
	Pattern string
	Action  ToolPermissionAction
}

// PermissionDecision evaluates the most specific matching PocketBase rule.
// A rule with an exact tool/pattern wins over a wildcard rule. At equal
// specificity, deny wins over ask, and ask wins over allow.
func (p SessionProfile) PermissionDecision(tool string, values ...string) ToolPermissionAction {
	tool = strings.ToLower(strings.TrimSpace(tool))
	bestScore := -1
	decision := ToolPermissionAsk
	for _, rule := range p.PermissionRules {
		ruleTool := strings.ToLower(strings.TrimSpace(rule.Tool))
		if ruleTool != "*" && ruleTool != tool {
			continue
		}
		pattern := strings.TrimSpace(rule.Pattern)
		if pattern == "" {
			pattern = "*"
		}
		matched := pattern == "*"
		for _, value := range values {
			if matched || wildcardMatch(pattern, value) {
				matched = true
				break
			}
		}
		if !matched {
			continue
		}
		score := 0
		if ruleTool == tool {
			score += 2
		}
		if pattern != "*" {
			score++
		}
		if score < bestScore || (score == bestScore && actionRank(rule.Action) <= actionRank(decision)) {
			continue
		}
		bestScore, decision = score, rule.Action
	}
	if decision != ToolPermissionAllow && decision != ToolPermissionDeny {
		return ToolPermissionAsk
	}
	return decision
}

func actionRank(action ToolPermissionAction) int {
	switch action {
	case ToolPermissionDeny:
		return 3
	case ToolPermissionAsk:
		return 2
	case ToolPermissionAllow:
		return 1
	default:
		return 0
	}
}

func wildcardMatch(pattern, value string) bool {
	if value == "" {
		return false
	}
	ok, err := path.Match(pattern, value)
	return err == nil && ok
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
	if !p.SupportsAdditionalDirectories || p.AdditionalDirectories == nil {
		return []string{}
	}
	return p.AdditionalDirectories
}

// sessionMeta carries PocketCoder's optional prompt extension through the
// standard ACP extensibility slot. ACP agents must ignore unknown metadata,
// so this is an enhancement only; the provider-specific fallback remains a
// separate capability to verify per pinned harness version.
func (p SessionProfile) sessionMeta() map[string]any {
	if strings.TrimSpace(p.Instructions) == "" {
		return nil
	}
	return map[string]any{"pocketcoder": map[string]any{"systemPrompt": p.Instructions}}
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
// session mode. Permission enforcement remains in RequestPermission below.
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

// PerSessionApplier delivers model/provider live, in addition to mode.
// Provider and model use the standard ACP session/set_config_option method;
// prompts use the optional ACP _meta extension at session creation/load and
// are not sent through a harness-private RPC.
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
	return nil
}

// selectApplier always returns PerSessionApplier — the branching that used
// to matter (whether Goose advertised per-session config at all) now lives
// inside PerSessionApplier.Apply itself, gated on the resolved harness's
// own capability flags carried on profile.
func selectApplier(profile SessionProfile) ProfileApplier {
	return PerSessionApplier{}
}
