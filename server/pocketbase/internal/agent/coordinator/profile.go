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
	"errors"
	"fmt"
	"log"
	"path"
	"strings"
	"time"

	acpsdk "github.com/coder/acp-go-sdk"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/agent/acp"
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
	AccountID                          string
	AgentProfileID                     string
	AgentName                          string

	// AccountLogin is true when the resolved (harness, provider) pair uses
	// an account/OAuth login (credential_selections.mode == "oauth") rather
	// than a bare API key. This is the real signal for whether an auth-shaped error
	// from the harness should map to the "reauthenticate" flow -- it comes
	// from the account row itself, not a hardcoded per-provider allowlist,
	// so a new harness that adds account-login support is covered
	// automatically instead of silently falling through to a generic
	// failure the way Codex did before this field existed.
	AccountLogin bool
	HarnessName  string // display name (harnesses.name, e.g. "Codex"), for user-facing reauth copy

	Target                             Target
	ResolvedInstanceID                 string // the harness_instances id this chat resolves to right now
	PinnedInstanceID                   string // the harness_instances id agent_sessions.harness_instance already points at (empty if none yet)
	SupportsLiveConfig                 bool
	SupportsLiveCredentialRegistration bool
	CredentialFieldName                string
	CredentialFieldValue               string
	SupportsSessionDelete              bool
	SupportsAdditionalDirectories      bool
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
	Apply(ctx context.Context, conn acp.Conn, sessionID string, p SessionProfile, modes *acpsdk.SessionModeState) ([]acpsdk.SessionConfigOption, error)
}

// GlobalConfigApplier delivers only what ACP allows post-create today: the
// session mode. Permission enforcement remains in RequestPermission below.
type GlobalConfigApplier struct{}

func (GlobalConfigApplier) Apply(ctx context.Context, conn acp.Conn, sessionID string, p SessionProfile, modes *acpsdk.SessionModeState) ([]acpsdk.SessionConfigOption, error) {
	if p.Mode == "" {
		return nil, nil
	}
	if modes != nil && !modeAdvertised(modes, p.Mode) {
		return nil, nil // logging is the caller's job at the call site, per existing logging conventions in this file
	}
	_, err := conn.SetSessionMode(ctx, acpsdk.SetSessionModeRequest{
		SessionId: acpsdk.SessionId(sessionID), ModeId: p.Mode,
	})
	// Mode is a preference, not a required session parameter -- an unknown
	// mode id must not fail the whole run.
	if isModeNotFoundError(err, p.Mode) {
		log.Printf("[coordinator] session %s: harness rejected mode %q as unknown, continuing without it", sessionID, p.Mode)
		return nil, nil
	}
	return nil, err
}

func requestErrorData(err error) (data map[string]any, code int, ok bool) {
	var reqErr *acpsdk.RequestError
	if !errors.As(err, &reqErr) {
		return nil, 0, false
	}
	m, _ := reqErr.Data.(map[string]any)
	return m, reqErr.Code, true
}

// Data.mode is checked before the message text, which can drift.
func isModeNotFoundError(err error, mode acpsdk.SessionModeId) bool {
	data, code, ok := requestErrorData(err)
	if !ok || code != -32602 {
		return false
	}
	if m, ok := data["mode"].(string); ok {
		return m == string(mode)
	}
	var reqErr *acpsdk.RequestError
	return errors.As(err, &reqErr) && strings.Contains(reqErr.Message, "mode not found")
}

// Data.modelId is checked before the message text, which can drift.
func isModelNotFoundError(err error, model string) bool {
	data, code, ok := requestErrorData(err)
	if !ok || code != -32602 {
		return false
	}
	if m, ok := data["modelId"].(string); ok {
		return m == model
	}
	var reqErr *acpsdk.RequestError
	return errors.As(err, &reqErr) && strings.Contains(reqErr.Message, "model not found")
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

// The returned []acpsdk.SessionConfigOption is the harness's own
// post-correction values, not an echo of the request.
func (PerSessionApplier) Apply(ctx context.Context, conn acp.Conn, sessionID string, p SessionProfile, modes *acpsdk.SessionModeState) ([]acpsdk.SessionConfigOption, error) {
	if _, err := (GlobalConfigApplier{}).Apply(ctx, conn, sessionID, p, modes); err != nil {
		return nil, err
	}
	// Provider-credential registration now happens in ProviderBootstrap,
	// before this session ever existed (see establishSession in run.go) --
	// SetSessionConfigOption below is always a genuine switch, never a
	// bootstrap.
	var latest []acpsdk.SessionConfigOption
	if p.SupportsLiveConfig {
		// A live-config harness's session/set_config_option support for
		// configId "provider" is NOT implied by SupportsLiveConfig alone --
		// opencode is also SupportsLiveConfig but its ACP server only
		// implements "model"/"effort"/"mode" (confirmed against opencode's
		// real source);
		// provider is implicitly fixed by whichever model is selected.
		// Sending configId "provider" to it fails every time with
		// {"code":-32602,"data":{"configId":"provider"},"message":"Invalid params: unknown config option: provider"}.
		// SupportsLiveCredentialRegistration happens to be exactly the flag
		// that's true only for goose today, so it doubles as this gate.
		if p.SupportsLiveCredentialRegistration && p.Provider != "" {
			resp, err := conn.SetSessionConfigOption(ctx, acpsdk.SetSessionConfigOptionRequest{
				ValueId: &acpsdk.SetSessionConfigOptionValueId{
					SessionId: acpsdk.SessionId(sessionID),
					ConfigId:  "provider",
					Value:     acpsdk.SessionConfigValueId(p.Provider),
				},
			})
			if err != nil {
				return nil, fmt.Errorf("apply provider: %w", err)
			}
			latest = resp.ConfigOptions
		}
		if p.Model != "" {
			opts, err := setModelWithRetry(ctx, conn, sessionID, p.Model)
			if err != nil {
				return nil, fmt.Errorf("apply model: %w", err)
			}
			if opts != nil {
				latest = opts
			}
		}
	}
	return latest, nil
}

// Overridable by tests so TestPerSessionApplierGivesUpOnGenuinelyUnknownModel
// doesn't have to wait out the real production timeout.
var (
	modelRetryTimeout      = 90 * time.Second
	modelRetryPollInterval = time.Second
)

// A "model not found" moments after connecting can mean a fresh stdio
// subprocess's own catalog sync hasn't finished yet, not a real bad model
// name. Retry for a bounded window before giving up.
func setModelWithRetry(ctx context.Context, conn acp.Conn, sessionID, model string) ([]acpsdk.SessionConfigOption, error) {
	deadline := time.Now().Add(modelRetryTimeout)
	for {
		resp, err := conn.SetSessionConfigOption(ctx, acpsdk.SetSessionConfigOptionRequest{
			ValueId: &acpsdk.SetSessionConfigOptionValueId{
				SessionId: acpsdk.SessionId(sessionID),
				ConfigId:  "model",
				Value:     acpsdk.SessionConfigValueId(model),
			},
		})
		if err == nil {
			return resp.ConfigOptions, nil
		}
		if !isModelNotFoundError(err, model) {
			return nil, err
		}
		if !time.Now().Before(deadline) {
			return nil, err
		}
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-time.After(modelRetryPollInterval):
		}
	}
}

// selectApplier always returns PerSessionApplier — the branching that used
// to matter (whether Goose advertised per-session config at all) now lives
// inside PerSessionApplier.Apply itself, gated on the resolved harness's
// own capability flags carried on profile.
func selectApplier(profile SessionProfile) ProfileApplier {
	return PerSessionApplier{}
}
