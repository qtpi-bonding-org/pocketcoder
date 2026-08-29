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

	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/agent/acp"
)

// ProviderBootstrap prepares a harness connection so profile.Provider is
// ready to use before the coordinator creates, resumes, or loads a
// session on it. Implementations vary by how a harness discovers
// provider credentials; the contract is the same for all of them.
//
// Bootstrap MUST be idempotent and safe to call on every session
// establishment -- including a resume/load against a connection whose
// underlying container may have just restarted. It must run after the
// harness connection is initialized and before any of session/new,
// session/resume, or session/load. See
// docs/superpowers/specs/2026-08-28-harness-provider-bootstrap-design.md
// for why: a harness's own provider-switch operation (e.g. goose's
// SetSessionConfigOption) may require an already-live provider to switch
// from, which a session created before any credential existed never has.
type ProviderBootstrap interface {
	Bootstrap(ctx context.Context, conn acp.Conn, p SessionProfile) error
}

// StaticEnvBootstrap is a no-op: claude-code, codex, and opencode get
// their provider credential baked into the container's env at
// provisioning time (see hooks.renderEnv), so there is nothing left to
// do at session-establishment time.
type StaticEnvBootstrap struct{}

func (StaticEnvBootstrap) Bootstrap(context.Context, acp.Conn, SessionProfile) error {
	return nil
}

// LiveConfigBootstrap covers goose: it registers the resolved provider's
// credential into goose's own provider registry and sets it as the active
// default provider via custom ACP methods before any session exists on this
// connection. This ensures session/new resolves the intended provider and a
// later SetSessionConfigOption("provider", ...) switch call has a live
// current provider to switch from.
//
// Deliberately omits p.Model here: goose's defaults/save strictly validates
// the model against its own live provider inventory, but p.Model comes from
// PocketBase's own harness_models catalog, which can resolve to a model
// goose's inventory doesn't currently carry (e.g. a stale/fallback catalog
// pick with no explicit is_default row) -- rejecting Bootstrap entirely over
// that would block session establishment for a reason that has nothing to
// do with whether the provider itself is live. Letting defaults/save fall
// back to the provider's own known-valid default model here is enough to
// get session/new working; PerSessionApplier's existing, unconditional
// post-session model switch (profile.go, unrelated to this bootstrap) is
// what actually applies p.Model, exactly as it already did before this
// bootstrap existed.
type LiveConfigBootstrap struct{}

func (LiveConfigBootstrap) Bootstrap(ctx context.Context, conn acp.Conn, p SessionProfile) error {
	if p.Provider == "" || !p.SupportsLiveCredentialRegistration || p.CredentialFieldName == "" {
		return nil
	}
	if err := registerProviderCredential(ctx, conn, p.Provider, p.CredentialFieldName, p.CredentialFieldValue); err != nil {
		return err
	}
	return setGooseDefaultProvider(ctx, conn, p.Provider)
}

// selectProviderBootstrap picks the bootstrap strategy for a resolved
// profile, mirroring selectApplier's existing capability-flag dispatch
// pattern in this same package. Keyed on SupportsLiveCredentialRegistration
// specifically, not SupportsLiveConfig: the seed data sets
// supports_live_config=true for both goose and opencode, but only goose
// sets supports_live_credential_registration=true. Keying on
// SupportsLiveConfig would silently route opencode through
// LiveConfigBootstrap -- harmless today only because its registration
// flag happens to be false, but a live bug waiting for the day opencode
// gains that flag.
func selectProviderBootstrap(profile SessionProfile) ProviderBootstrap {
	if profile.SupportsLiveCredentialRegistration {
		return LiveConfigBootstrap{}
	}
	return StaticEnvBootstrap{}
}
