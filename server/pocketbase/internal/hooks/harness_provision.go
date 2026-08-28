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

// @pocketcoder-core: Harness Provisioning. Turns a harnesses catalog row
// into a running, dialable container on demand.
package hooks

import (
	"bytes"
	"context"
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"log"
	"os"
	"strings"
	"text/template"

	"github.com/google/uuid"
	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/dockerapi"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/harnessaccount"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/harnessvolume"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/releaseartifact"
)

// inspector is the minimal interface ResolveWorkspaceVolumeAndNetwork needs
//
//	satisfied by *dockerapi.Client, and by a small test double.
type inspector interface {
	Inspect(ctx context.Context, containerName string) (dockerapi.ContainerInspect, error)
}

// ModelNetwork is a compose-pinned name rather than a database value. Every
// dynamically provisioned peer joins it during the initial Docker create
// call so it can reach the local Ollama service -- but only when Ollama is
// actually running (see ollamaRunning): the compose file's own `ollama`
// service is gated behind the `local-models` profile, off by default, and
// Docker Compose never creates a network unless at least one active
// service references it. Unconditionally requesting this network on every
// harness create failed 100% of default (no-local-models) deployments --
// confirmed live: `failed to set up container networking: network
// pocketcoder-model not found`, leaving every harness container stuck at
// Created, never started.
const ModelNetwork = "pocketcoder-model"

// ollamaContainerName mirrors ollama.ollamaContainerName (unexported in
// that package) -- both are the same compose-pinned container_name, kept
// as a local constant here rather than an import to avoid a dependency
// this package otherwise has no reason to take on.
const ollamaContainerName = "pocketcoder-ollama"

// ollamaRunning reports whether the local Ollama service is actually up,
// used to decide whether a harness should request ModelNetwork at all.
// Deliberately checked via Inspect (CONTAINERS=1 on docker-socket-proxy-
// write) rather than a network-existence call: that proxy has NETWORKS=0
// set deliberately ("PocketBase's own proxy... only ever restarts/
// inspects containers it already trusts" -- see docker-compose.yml), so a
// direct network inspect would be rejected by the proxy itself.
func ollamaRunning(ctx context.Context, client inspector) (bool, error) {
	if _, err := client.Inspect(ctx, ollamaContainerName); err != nil {
		if errors.Is(err, dockerapi.ErrContainerNotFound) {
			return false, nil
		}
		return false, err
	}
	return true, nil
}

// HarnessEgressNetwork is shared by every harness. A harness being the catalog
// default must not grant it a different Docker network trust tier.
const HarnessEgressNetwork = "pocketcoder-harness-egress"

// ResolveWorkspaceVolumeAndNetwork finds the real, possibly compose-project-
// prefixed names of the shared workspace volume and agent network by
// inspecting PocketBase's own container by inspecting the mount destination and
// network-name suffix, not by guessing a prefix.
func ResolveWorkspaceVolumeAndNetwork(ctx context.Context, client inspector) (volumeName, networkName string, err error) {
	insp, err := client.Inspect(ctx, "pocketcoder-pocketbase")
	if err != nil {
		return "", "", fmt.Errorf("inspect pocketcoder-pocketbase: %w", err)
	}
	for _, m := range insp.Mounts {
		if m.Destination == "/workspace" {
			volumeName = m.Name
		}
	}
	for name := range insp.NetworkSettings.Networks {
		if strings.HasSuffix(name, "pocketcoder-agent") {
			networkName = name
		}
	}
	if volumeName == "" {
		return "", "", fmt.Errorf("no /workspace mount found on pocketcoder-pocketbase")
	}
	if networkName == "" {
		return "", "", fmt.Errorf("no pocketcoder-agent network found on pocketcoder-pocketbase")
	}
	return volumeName, networkName, nil
}

// dockerProvisioner is the subset of *dockerapi.Client ProvisionHarnessInstance
// needs  satisfied by the real client and by a test double.
type dockerProvisioner interface {
	inspector
	ImageExists(ctx context.Context, image string) (bool, error)
	PullImage(ctx context.Context, image string) error
	LoadImage(ctx context.Context, archive io.Reader) error
	Create(ctx context.Context, name string, spec dockerapi.CreateSpec) (string, error)
	Start(ctx context.Context, containerName string) error
}

type dockerRemover interface {
	Remove(context.Context, string) error
}

var ensureReleaseHarnessImage = func(ctx context.Context, client dockerProvisioner, harnessID, image string) error {
	return releaseartifact.EnsureHarnessImage(ctx, client, harnessID, image)
}

// FindHarnessInstance looks up the harness_instances row for (harness,
// oauth account, launchKey) scoped to a user. oauth_account and launch_key
// are both matched in Go, not in the PocketBase filter: an empty string for
// either is the common case (an API-key-only launch has no oauth_account;
// every supports_live_config harness has no launch_key), and PocketBase's
// filter evaluator does not reliably match an empty-string field value
// inside an `&&` expression. Exported so internal/sessionprofile's
// sessionprofile.Build can share this exact lookup instead of maintaining its own
// copy of the same workaround.
func FindHarnessInstance(app core.App, harnessID, launchKey, userID, oauthAccountID string) (*core.Record, error) {
	candidates, err := app.FindRecordsByFilter("harness_instances", "harness = {:h} && user = {:u}", "", 0, 0, map[string]any{"h": harnessID, "u": userID})
	if err != nil {
		return nil, fmt.Errorf("query harness_instances for harness %s: %w", harnessID, err)
	}
	for _, rec := range candidates {
		if rec.GetString("launch_key") == launchKey && rec.GetString("oauth_account") == oauthAccountID {
			// A retryable failed provisioning row is one-shot: return this
			// record so the current caller can still see
			// status="error"/last_error (sessionprofile.Build's switch
			// reports it as ErrHarnessFailed), then delete the persisted
			// row so it doesn't permanently block a later retry. Deleting
			// rec's DB row does not clear the already-loaded in-memory
			// fields the caller is about to read. A non-retryable failure
			// (structurally broken launch_template, discovered only after
			// Create+Start already succeeded -- see fail()'s doc comment)
			// stays as-is: retrying would just recreate the same broken
			// container, so the row is left for a person to investigate.
			if rec.GetString("status") == "error" && rec.GetBool("retryable") {
				if err := app.Delete(rec); err != nil {
					return nil, fmt.Errorf("delete failed harness instance %s: %w", rec.Id, err)
				}
			}
			return rec, nil
		}
	}
	return nil, nil
}

// raceHookForTests, when non-nil, is invoked by ProvisionHarnessInstance
// immediately before it saves its own pending harness_instances row
// solely so a test can deterministically simulate another caller's row
// landing first for the same (harness, launch_key) pair, reproducing the
// unique-index race the Save-error branch below handles. Always nil outside
// tests.
var raceHookForTests func()

// ProvisionHarnessInstance turns a harnesses catalog row into a running,
// dialable container idempotent per (harnessID, oauthAccountID, launchKey,
// userID), minting a per-instance secret, rendering launch_template.env_template
// against the user's resolved provider credentials, ensuring the release
// image, and creating+starting the container.
func ProvisionHarnessInstance(ctx context.Context, app core.App, client dockerProvisioner, harnessID, launchKey, userID string) (*core.Record, error) {
	if userID == "" {
		return nil, fmt.Errorf("userID is required")
	}
	harness, err := app.FindRecordById("harnesses", harnessID)
	if err != nil {
		return nil, fmt.Errorf("look up harness %s: %w", harnessID, err)
	}

	// Provider/model must be resolved BEFORE any OAuth-account resolution:
	// credential_selections is keyed by (user, harness, provider), and a
	// live-config/fan-out harness's launch has no single provider at all
	// (providerID/modelID both stay empty; renderEnv then injects every
	// credentialed provider per spec §6, matched by supports_live_config).
	providerID, modelID := "", ""
	if launchKey != "" && !harness.GetBool("supports_live_config") {
		hm, hmErr := app.FindRecordById("harness_models", launchKey)
		if hmErr != nil {
			return nil, fmt.Errorf("resolve pinned launch %s: harness_models row not found: %w", launchKey, hmErr)
		}
		modelID = hm.GetString("harness_model_id")
		model, modelErr := app.FindRecordById("models", hm.GetString("model"))
		if modelErr != nil {
			return nil, fmt.Errorf("resolve pinned launch %s: model row not found: %w", launchKey, modelErr)
		}
		providerID = model.GetString("provider")
		if providerID == "" {
			return nil, fmt.Errorf("resolve pinned launch %s: model has no provider", launchKey)
		}
		if _, providerErr := app.FindRecordById("providers", providerID); providerErr != nil {
			return nil, fmt.Errorf("resolve pinned launch %s: provider row not found: %w", launchKey, providerErr)
		}
		edges, edgeErr := app.FindRecordsByFilter("harness_providers", "harness = {:h} && provider = {:p}", "", 0, 0, map[string]any{"h": harnessID, "p": providerID})
		if edgeErr != nil || len(edges) == 0 {
			return nil, fmt.Errorf("resolve pinned launch %s: harness/provider edge not found: %v", launchKey, edgeErr)
		}
	}
	if harness.GetBool("supports_live_config") {
		if edges, edgeErr := app.FindRecordsByFilter("harness_providers", "harness = {:h}", "", 0, 0, map[string]any{"h": harnessID}); edgeErr != nil {
			return nil, fmt.Errorf("check live-config provider edges: %w", edgeErr)
		} else {
			for _, edge := range edges {
				if edge.GetBool("supports_oauth") {
					return nil, fmt.Errorf("live-config harness %s with OAuth-capable provider edges is not supported yet", harnessID)
				}
			}
		}
	}

	// oauth_account is only ever resolved for a known single provider
	// (self-scoped launches) -- OAuth is not offered for multi-provider
	// harnesses in v1 (spec §10), and a live-config harness never has a
	// single provider to resolve an account against at container-launch
	// time regardless.
	oauthAccountID := ""
	if providerID != "" {
		account, err := ResolveOAuthAccountForLaunch(app, userID, harnessID, providerID)
		if err != nil {
			return nil, err
		}
		if account != nil {
			oauthAccountID = account.Id
		}
	}

	// Do not add `launch_key = {:k}` to FindHarnessInstance's PocketBase filter.
	// This is confirmed against the already-landed internal/sessionprofile
	// (sessionprofile.Build queries harness_instances the same way, see its
	// own in-code comment): PocketBase's filter evaluator does not reliably
	// match an empty-string `launch_key` inside an `&&` expression, and
	// launch_key = "" is the COMMON case (every supports_live_config = true
	// harness). Query by harness alone, then match launch_key in Go.
	existing, err := FindHarnessInstance(app, harnessID, launchKey, userID, oauthAccountID)
	if err != nil {
		return nil, err
	}
	if existing != nil {
		switch status := existing.GetString("status"); status {
		case "stopped":
			if err := app.Delete(existing); err != nil {
				return nil, fmt.Errorf("delete stale harness instance: %w", err)
			}
		case "error":
			// A retryable row: FindHarnessInstance already deleted the
			// persisted row for this one-shot failure report, so provision
			// a fresh instance below instead of re-returning the stale
			// failure. A non-retryable row is returned as-is -- retrying
			// would just recreate the same structurally-broken container.
			if !existing.GetBool("retryable") {
				return existing, nil
			}
		default:
			return existing, nil
		}
	}

	secret, err := mintSecret()
	if err != nil {
		return nil, fmt.Errorf("mint harness instance secret: %w", err)
	}

	coll, err := app.FindCollectionByNameOrId("harness_instances")
	if err != nil {
		return nil, err
	}
	rec := core.NewRecord(coll)
	userSuffix := userID
	if len(userSuffix) > 8 {
		userSuffix = userSuffix[:8]
	}
	containerName := "pocketcoder-harness-" + userSuffix + "-" + uuid.NewString()[:8]
	rec.Set("harness", harnessID)
	rec.Set("user", userID)
	rec.Set("oauth_account", oauthAccountID)
	rec.Set("launch_key", launchKey)
	if launchKey != "" {
		rec.Set("harness_model", launchKey)
	}
	rec.Set("container_name", containerName)
	rec.Set("secret", secret)
	rec.Set("status", "pending")
	rec.Set("managed", true)
	if raceHookForTests != nil {
		raceHookForTests()
	}
	if err := app.Save(rec); err != nil {
		if winner, lookupErr := FindHarnessInstance(app, harnessID, launchKey, userID, oauthAccountID); lookupErr == nil && winner != nil {
			return winner, nil
		}
		return nil, fmt.Errorf("save pending harness_instances row: %w", err)
	}
	// fail persists a failed provisioning attempt. retryable distinguishes
	// two genuinely different situations: a Docker/config resolution step
	// itself failing (retryable -- the container likely never started, or
	// started into a broken state worth tearing down; FindHarnessInstance
	// clears the row after reporting it once so a later request retries
	// cleanly) versus a launch_template that is structurally missing
	// required data, discovered only after Create+Start already succeeded
	// (not retryable -- the same container would be recreated with the
	// exact same broken config every time; the row must stay in "error"
	// so a person fixes the harness definition instead of the client
	// silently hammering Docker with identical doomed attempts).
	fail := func(err error, retryable bool) (*core.Record, error) {
		log.Printf("[HarnessProvision] harness=%s container=%s failed: %v", harnessID, containerName, err)
		rec.Set("status", "error")
		rec.Set("last_error", err.Error())
		rec.Set("retryable", retryable)
		if retryable {
			if remover, ok := client.(dockerRemover); ok {
				if removeErr := remover.Remove(ctx, containerName); removeErr != nil && !errors.Is(removeErr, dockerapi.ErrContainerNotFound) {
					log.Printf("[HarnessProvision] cleanup container %s: %v", containerName, removeErr)
				}
			}
		}
		// Persist the error status (not delete): the caller of this
		// synchronous call is almost always a fire-and-forget background
		// goroutine (see sessionprofile.Build) whose return value is only
		// logged, never surfaced to the request that triggered it. The row
		// must survive so the client's *next* poll (FindHarnessInstance)
		// can report the actual failure via ErrHarnessFailed instead of
		// silently retrying forever. FindHarnessInstance clears a retryable
		// row after that one report, so a later request retries cleanly.
		if saveErr := app.Save(rec); saveErr != nil {
			log.Printf("[HarnessProvision] persist error status for instance %s: %v", rec.Id, saveErr)
		}
		return rec, nil
	}

	volumeName, networkName, err := ResolveWorkspaceVolumeAndNetwork(ctx, client)
	if err != nil {
		return fail(err, true)
	}

	image := harness.GetString("container_image")
	var launch struct {
		Cmd         []string          `json:"cmd"`
		Port        int               `json:"port"`
		EnvTemplate map[string]string `json:"env_template"`
	}
	if err := harness.UnmarshalJSONField("launch_template", &launch); err != nil {
		log.Printf("[HarnessProvision] harness=%s: failed to parse launch_template: %v", harnessID, err)
	}

	env, err := renderEnv(app, launch.EnvTemplate, secret, harness, userID, providerID, modelID)
	if err != nil {
		return fail(fmt.Errorf("render launch_template.env_template: %w", err), true)
	}
	local, err := client.ImageExists(ctx, image)
	if err != nil {
		return fail(err, true)
	}
	if !local {
		if releaseartifact.ManagedReleaseImage(image, os.Getenv("POCKETCODER_RELEASE")) {
			if err := ensureReleaseHarnessImage(ctx, client, harness.GetString("cli_id"), image); err != nil {
				return fail(err, true)
			}
		} else if err := client.PullImage(ctx, image); err != nil {
			return fail(err, true)
		}
	}

	volumes, err := harnessvolume.Resolve(volumeName, userID, harness.GetString("cli_id"), oauthAccountID)
	if err != nil {
		return fail(fmt.Errorf("resolve harness volumes: %w", err), true)
	}
	volumeBinds := []string{
		volumes.Workspace + ":/workspace",
		volumes.Auth + ":" + harnessvolume.AuthHomeMount,
		volumes.GitSSH + ":" + harnessvolume.GitSSHMount + ":ro",
	}
	// Account-login helpers and all ACP subprocesses share one conventional
	// auth home. Goose points GOOSE_PATH_ROOT here in its catalog launch
	// template; peers use HOME/XDG directly. No harness gets extra storage.
	env = append(env,
		"HOME="+harnessvolume.AuthHomeMount,
		"XDG_CONFIG_HOME="+harnessvolume.AuthHomeMount+"/.config",
		"XDG_DATA_HOME="+harnessvolume.AuthHomeMount+"/.local/share",
	)
	env = append(env, "GIT_SSH_COMMAND=ssh -F "+harnessvolume.GitSSHMount+"/current/ssh_config")
	networkNames := []string{networkName, HarnessEgressNetwork, "pocketcoder-mcp-gateway", "pocketcoder-memory"}
	if running, err := ollamaRunning(ctx, client); err != nil {
		return fail(fmt.Errorf("check local-models availability: %w", err), true)
	} else if running {
		networkNames = append(networkNames, ModelNetwork)
	}
	_, err = client.Create(ctx, containerName, dockerapi.CreateSpec{
		Image:        image,
		Cmd:          launch.Cmd,
		Env:          env,
		VolumeBinds:  volumeBinds,
		NetworkNames: networkNames,
		Labels: map[string]string{
			"pc_managed":          "pocketcoder",
			"pc_release":          os.Getenv("POCKETCODER_RELEASE"),
			"pc_scope":            "user",
			"pc_scope_id":         userID,
			"pc_harness_id":       harnessID,
			"pc_oauth_account_id": oauthAccountID,
		},
	})
	if err != nil {
		return fail(err, true)
	}
	if err := client.Start(ctx, containerName); err != nil {
		return fail(err, true)
	}

	// Checked here (after Create+Start, not before) rather than as an
	// up-front validation: port is only needed to build the ws:// endpoint
	// URL below, not by the Docker create/start calls themselves, and a
	// pending row with no port must still count as "one Create call" for
	// a subsequent ProvisionHarnessInstance call; FindHarnessInstance matches this error row and
	// returns it rather than attempting a second Create. Not retryable: the
	// container is already running fine, and the launch_template is
	// structurally missing data that a retry would not fix -- retrying
	// would only spawn another identically-broken container.
	if launch.Port == 0 {
		return fail(fmt.Errorf("harness %s's launch_template has no port", harnessID), false)
	}

	rec.Set("status", "running")
	rec.Set("acp_endpoint", fmt.Sprintf("ws://%s:%d/acp", containerName, launch.Port))
	if err := app.Save(rec); err != nil {
		return nil, fmt.Errorf("save running harness_instances row: %w", err)
	}
	if copier, ok := client.(archiveCopier); ok {
		if err := MaterializeUserHarnessFiles(ctx, app, copier, rec); err != nil {
			return fail(err, true)
		}
	}
	return rec, nil
}

func ResolveOAuthAccountForLaunch(app core.App, userID, harnessID, providerID string) (*core.Record, error) {
	sel, selErr := app.FindFirstRecordByFilter(
		"credential_selections",
		"user = {:u} && harness = {:h} && provider = {:p}",
		map[string]any{"u": userID, "h": harnessID, "p": providerID},
	)
	mode := ""
	if selErr == nil {
		mode = sel.GetString("mode")
	} else if !isRecordNotFound(selErr) {
		return nil, fmt.Errorf("resolve credential selection for provider %s: %w", providerID, selErr)
	}
	switch mode {
	case "api_key", "none":
		return nil, nil
	case "oauth":
		account, err := app.FindRecordById("harness_oauth_accounts", sel.GetString("oauth_account"))
		if err != nil {
			return nil, fmt.Errorf("selected oauth account %s not found", sel.GetString("oauth_account"))
		}
		if account.GetString("harness") != harnessID || account.GetString("provider") != providerID {
			return nil, fmt.Errorf("selected oauth account does not belong to this harness/provider")
		}
		if account.GetString("status") != "connected" {
			return nil, fmt.Errorf("selected oauth account is not connected (status=%s) -- reconnect it before launching", account.GetString("status"))
		}
		if !harnessaccount.CanAccess(account, userID) {
			return nil, fmt.Errorf("selected oauth account is not accessible to this user")
		}
		return account, nil
	default:
		accounts, err := app.FindRecordsByFilter(
			"harness_oauth_accounts",
			"harness = {:h} && provider = {:p} && status = 'connected' && (owner = {:u} || visibility = 'deployment')",
			"", 1, 0,
			map[string]any{"h": harnessID, "p": providerID, "u": userID},
		)
		if err != nil && !isRecordNotFound(err) {
			return nil, fmt.Errorf("resolve default OAuth account for provider %s: %w", providerID, err)
		}
		if len(accounts) == 0 {
			return nil, nil
		}
		return accounts[0], nil
	}
}

// isRecordNotFound reports whether err is PocketBase's "record not found"
// signal (FindRecordById/FindFirstRecordByFilter both return sql.ErrNoRows
// verbatim -- see dbx.SelectQuery.One and core.FindFirstRecordByFilter), as
// opposed to any other DB/lookup failure, which callers must treat as a
// hard error rather than "nothing selected".
func isRecordNotFound(err error) bool {
	return errors.Is(err, sql.ErrNoRows)
}

// mintSecret generates the per-instance credential the bundled adapter
// enforces on its WS upgrade (.4.1)  this, not an empty string, is what
// populates Target.Secret once this row is resolved.
func mintSecret() (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}

// renderEnv builds a harness container's env, following the single
// resolution path spec §6 describes: for every provider this launch may
// use (its harness_providers edges, filtered to the one pinned edge
// matching providerID when the harness is NOT supports_live_config),
// resolve the user's credential for that provider -- defaulting to a
// connected OAuth account before an API key when there is no explicit
// credential_selections row (spec §6's stated default-preference order)
// -- and merge. An OAuth-mode provider contributes no env vars (the
// credential lives on the mounted auth-home volume, resolved separately
// by ProvisionHarnessInstance before this function is even called). There
// is no branch on harness identity, and no branch on provider_fanout,
// anywhere in this function -- provider_fanout is a sync-time-only
// concept internal_modelcatalog owns; the field this function actually
// branches on is supports_live_config.
func renderEnv(app core.App, envTemplate map[string]string, secret string, harness *core.Record, userID string, providerID string, modelID string) ([]string, error) {
	values := map[string]string{
		"__adapter_secret": secret,
		"__ollama_host":    "http://ollama:11434",
	}

	edges, err := providersForLaunch(app, harness, providerID)
	if err != nil {
		return nil, err
	}
	if harness.GetBool("supports_live_config") {
		for _, edge := range edges {
			if edge.GetBool("supports_oauth") {
				return nil, fmt.Errorf("live-config harness %s with OAuth-capable provider edges is not supported yet", harness.Id)
			}
		}
		// __provider/__model seed a live-config harness's INITIAL
		// provider/model before the chat's first ACP session/new call --
		// coordinator.PerSessionApplier then overrides both live via
		// SetSessionConfigOption per spec §6/§4.3. providerID here is
		// still a pc_providers RECORD id (this function's own contract,
		// consistent with providersForLaunch below) so it must be resolved
		// back to its provider_id STRING before use -- Goose reads
		// GOOSE_PROVIDER as e.g. "anthropic", never a PocketBase id.
		values["__provider"] = ""
		if providerID != "" {
			if providerRec, err := app.FindRecordById("providers", providerID); err == nil {
				values["__provider"] = providerRec.GetString("provider_id")
			}
		}
		values["__model"] = modelID
		if values["__provider"] == "" {
			values["__provider"] = "anthropic"
		}
		if values["__model"] == "" {
			values["__model"] = "MiniMax-M2.5"
		}
		if testProvider := os.Getenv("POCKETCODER_AGENT_TEST_PROVIDER"); testProvider != "" {
			values["__provider"] = testProvider
			if testModel := os.Getenv("POCKETCODER_AGENT_TEST_MODEL"); testModel != "" {
				values["__model"] = testModel
			}
			values["OPENROUTER_API_KEY"] = os.Getenv("POCKETCODER_AGENT_TEST_API_KEY")
		}
	}

	for _, edge := range edges {
		providerRec, err := app.FindRecordById("providers", edge.GetString("provider"))
		if err != nil {
			if isRecordNotFound(err) {
				return nil, fmt.Errorf("provider %s referenced by harness edge was not found", edge.GetString("provider"))
			}
			return nil, fmt.Errorf("resolve provider %s: %w", edge.GetString("provider"), err)
		}
		sel, selErr := app.FindFirstRecordByFilter(
			"credential_selections",
			"user = {:u} && harness = {:h} && provider = {:p}",
			map[string]any{"u": userID, "h": harness.Id, "p": providerRec.Id},
		)
		if selErr != nil && !isRecordNotFound(selErr) {
			return nil, fmt.Errorf("resolve credential selection for provider %s: %w", providerRec.Id, selErr)
		}
		mode := ""
		if sel != nil {
			mode = sel.GetString("mode")
		}
		if mode == "" {
			// No explicit selection: delegate to ResolveOAuthAccountForLaunch
			// (Step 4 below) for the default-preference decision -- this is
			// the SAME function ProvisionHarnessInstance calls to decide
			// oauthAccountID/volume mounting, so the two can never disagree
			// about which credential a (harness, provider) pair is actually
			// using. An earlier draft of this task re-implemented the
			// "connected OAuth account" lookup inline here, separately from
			// ProvisionHarnessInstance's own resolution -- that duplication
			// is exactly what let the two silently diverge (renderEnv could
			// decide "oauth" while ProvisionHarnessInstance's oauthAccountID
			// stayed empty, launching a container with no credentials at
			// all). There must be exactly one place that decides this.
			if account, err := ResolveOAuthAccountForLaunch(app, userID, harness.Id, providerRec.Id); err != nil {
				return nil, err
			} else if account != nil {
				mode = "oauth"
			} else if key, keyErr := app.FindFirstRecordByFilter("provider_api_keys", "owner = {:u} && provider = {:p}", map[string]any{"u": userID, "p": providerRec.Id}); keyErr != nil && !isRecordNotFound(keyErr) {
				return nil, fmt.Errorf("resolve API key for provider %s: %w", providerRec.Id, keyErr)
			} else if key != nil {
				mode = "api_key"
			}
		}
		switch mode {
		case "api_key", "none":
			// "none" means "no OAuth account for this (harness, provider)"
			// -- the same meaning ResolveOAuthAccountForLaunch already gives
			// it (case "api_key", "none": return nil, nil). It does NOT mean
			// "no credential at all": it's exactly the mode
			// HarnessAuthCubit.startWithNone records for a plain
			// provider_api_keys credential (Goose/OpenCode's API-key
			// onboarding path). Before this, an explicit "none" selection
			// skipped the mode=="" auto-detect branch above (which does
			// find and use the key) and had no matching case here, so the
			// container launched with the credential silently never
			// injected -- invisible until a real "none" selection actually
			// existed, which onboarding didn't produce until Goose/OpenCode
			// API-key auth was wired up.
			key, err := app.FindFirstRecordByFilter("provider_api_keys", "owner = {:u} && provider = {:p}", map[string]any{"u": userID, "p": providerRec.Id})
			if err != nil {
				if isRecordNotFound(err) {
					return nil, fmt.Errorf("selected API key for provider %s was not found", providerRec.Id)
				}
				return nil, fmt.Errorf("resolve selected API key for provider %s: %w", providerRec.Id, err)
			}
			if key == nil {
				return nil, fmt.Errorf("selected API key for provider %s was not found", providerRec.Id)
			}
			names := envVarNamesFor(edge, providerRec)
			for _, name := range names {
				values[name] = key.GetString("api_key")
			}
			if baseURLEnv := providerRec.GetString("base_url_env"); baseURLEnv != "" {
				if baseURL := key.GetString("base_url"); baseURL != "" {
					values[baseURLEnv] = baseURL
				}
			}
			var extra map[string]string
			if err := key.UnmarshalJSONField("extra_env", &extra); err == nil {
				for k, v := range extra {
					values[k] = v
				}
			}
		case "oauth":
			if _, err := ResolveOAuthAccountForLaunch(app, userID, harness.Id, providerRec.Id); err != nil {
				return nil, err
			}
			// No env vars: the credential lives on the mounted auth-home
			// volume. ProvisionHarnessInstance (Step 5) resolves and
			// validates the actual oauth_account BEFORE calling renderEnv
			// and fails provisioning outright if an explicit oauth
			// selection points at a disconnected/inaccessible account --
			// by the time renderEnv runs, an "oauth" mode here is known-good.
		}
	}

	env := make([]string, 0, len(envTemplate))
	for name, tmplStr := range envTemplate {
		tmpl, err := template.New(name).Option("missingkey=error").Parse(tmplStr)
		if err != nil {
			return nil, fmt.Errorf("parse env_template[%s]: %w", name, err)
		}
		var buf bytes.Buffer
		if err := tmpl.Execute(&buf, values); err != nil {
			return nil, fmt.Errorf("render env_template[%s]: %w", name, err)
		}
		env = append(env, name+"="+buf.String())
	}
	seen := make(map[string]bool, len(env))
	for _, item := range env {
		if i := strings.IndexByte(item, '='); i > 0 {
			seen[item[:i]] = true
		}
	}
	for name, value := range values {
		if strings.HasPrefix(name, "__") || seen[name] {
			continue
		}
		env = append(env, name+"="+value)
	}
	return env, nil
}

// providersForLaunch returns the harness_providers edges relevant to this
// launch: every edge when the harness is supports_live_config (its model
// can change mid-chat, so every credentialed provider must be available),
// or just the one pinned edge matching providerID otherwise (falling back
// to every edge if providerID is empty, e.g. no model selected yet).
// providerID, when non-empty, is a pc_providers RECORD id -- models.provider
// is a relation (Task 1), so no provider_id-string lookup is needed here.
func providersForLaunch(app core.App, harness *core.Record, providerID string) ([]*core.Record, error) {
	filter := "harness = {:h}"
	params := map[string]any{"h": harness.Id}
	if !harness.GetBool("supports_live_config") && providerID != "" {
		filter = "harness = {:h} && provider = {:p}"
		params["p"] = providerID
	}
	return app.FindRecordsByFilter("harness_providers", filter, "", 0, 0, params)
}

// envVarNamesFor returns every env var name a provider_api_keys value
// should be delivered under: harness_providers.api_key_env_override if
// set (an escape hatch for a harness reading a nonstandard name), else
// every name providers.api_key_envs lists.
func envVarNamesFor(edge, provider *core.Record) []string {
	if override := edge.GetString("api_key_env_override"); override != "" {
		return []string{override}
	}
	var envs []string
	if err := provider.UnmarshalJSONField("api_key_envs", &envs); err == nil && len(envs) > 0 {
		return envs
	}
	if env := provider.GetString("api_key_env"); env != "" {
		return []string{env}
	}
	return []string{strings.ToUpper(provider.GetString("provider_id")) + "_API_KEY"}
}
