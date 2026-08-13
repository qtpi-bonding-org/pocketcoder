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
	"encoding/hex"
	"fmt"
	"io"
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
// dynamically provisioned peer joins it during the initial Docker create call
// so it can reach the always-on local Ollama service, while the socket proxy
// still forbids arbitrary post-create network attachment.
const ModelNetwork = "pocketcoder-model"

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

var ensureReleaseHarnessImage = func(ctx context.Context, client dockerProvisioner, harnessID, image string) error {
	return releaseartifact.EnsureHarnessImage(ctx, client, harnessID, image)
}

// FindHarnessInstance looks up the harness_instances row for (harness,
// account, launchKey) scoped to a user. See ProvisionHarnessInstance for why
// launch_key is matched in Go. Exported so api/profile.go's
// buildSessionProfile can share this exact lookup instead of maintaining its own
// copy of the same launch_key-in-Go workaround.
func FindHarnessInstance(app core.App, harnessID, launchKey, userID, accountID string) (*core.Record, error) {
	candidates, err := app.FindRecordsByFilter("harness_instances", "harness = {:h} && user = {:u} && harness_account = {:a}", "", 0, 0, map[string]any{"h": harnessID, "u": userID, "a": accountID})
	if err != nil {
		return nil, fmt.Errorf("query harness_instances for harness %s: %w", harnessID, err)
	}
	for _, rec := range candidates {
		if rec.GetString("launch_key") == launchKey {
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
// dialable container idempotent per (harnessID, harnessAccountID, launchKey,
// userID), minting a per-instance secret, rendering launch_template.env_template
// against provider_keys, ensuring the release image, and creating+starting the
// container.
func ProvisionHarnessInstance(ctx context.Context, app core.App, client dockerProvisioner, harnessID, launchKey, userID string) (*core.Record, error) {
	if userID == "" {
		return nil, fmt.Errorf("userID is required")
	}
	account, err := harnessaccount.EnsureDefaultPersonal(app, userID, harnessID)
	if err != nil {
		return nil, fmt.Errorf("resolve harness account: %w", err)
	}
	// Do not add `launch_key = {:k}` to FindHarnessInstance's PocketBase filter.
	// This is confirmed against the
	// already-landed api/profile.go (buildSessionProfile queries
	// harness_instances the same way, see its own in-code comment):
	// PocketBase's filter evaluator does not reliably match an empty-string
	// `launch_key` inside an `&&` expression, and launch_key = "" is the
	// COMMON case (every supports_live_config = true harness). A direct
	// `&&` filter here would fail to find the existing user/account instance on
	// every call after the first, and each failed lookup would attempt to
	// mint and Create a brand-new container colliding with the first on
	// the (harness, launch_key) unique index and erroring out. Query by
	// harness alone, then match launch_key in Go, exactly like
	// buildSessionProfile already does.
	existing, err := FindHarnessInstance(app, harnessID, launchKey, userID, account.Id)
	if err != nil {
		return nil, err
	}
	if existing != nil {
		// Updates deliberately remove release-managed harness containers while
		// preserving their named workspace/auth volumes. The Docker watcher marks
		// the corresponding row stopped (including when the container is absent
		// during startup reconciliation). Drop that stale row here so the next
		// chat recreates the harness against the active release immediately rather
		// than returning a dead ACP endpoint for the lifecycle grace period.
		if status := existing.GetString("status"); status == "stopped" {
			if err := app.Delete(existing); err != nil {
				return nil, fmt.Errorf("delete stale harness instance: %w", err)
			}
		} else {
			return existing, nil
		}
	}

	harness, err := app.FindRecordById("harnesses", harnessID)
	if err != nil {
		return nil, fmt.Errorf("look up harness %s: %w", harnessID, err)
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
	rec.Set("harness_account", account.Id)
	rec.Set("launch_key", launchKey)
	if launchKey != "" {
		// launch_key IS the harness_models id for a supports_live_config =
		// false harness — harness_model is otherwise only a
		// denormalized `expand` convenience, but it's free to set correctly
		// here and leaving it blank would silently diverge from what the
		// schema documents the field for.
		rec.Set("harness_model", launchKey)
	}
	rec.Set("container_name", containerName)
	rec.Set("secret", secret)
	rec.Set("status", "pending")
	rec.Set("managed", true)
	if raceHookForTests != nil {
		// Test-only seam: lets a test deterministically land a concurrent
		// "winner" row for the same (harness, launch_key) in the gap
		// between this call's own FindHarnessInstance lookup (above, which
		// found nothing) and its own Save below, the same shape of race,
		// without relying on timing. The assertion is the one that matters
		// regardless of how the race is induced: the loser must return the
		// winner's row with a nil error, and must not provision a second container.
		raceHookForTests()
	}
	if err := app.Save(rec); err != nil {
		// (user, harness, harness_account, launch_key) is unique-indexed
		// (idx_harness_instances_pair),
		// so a concurrent caller provisioning the same pair can win this race
		// and land its row first, this Save then fails on the unique-index
		// violation even though a perfectly usable instance now exists. Re-run
		// the same lookup FindHarnessInstance did up front: if the winner's
		// row is there now, hand it back instead of surfacing a spurious
		// error to a caller that just lost a benign race. Only propagate the
		// raw Save error if the row still isn't there, a genuinely different
		// failure (e.g. a validation error), not a race loss.
		if winner, lookupErr := FindHarnessInstance(app, harnessID, launchKey, userID, account.Id); lookupErr == nil && winner != nil {
			return winner, nil
		}
		return nil, fmt.Errorf("save pending harness_instances row: %w", err)
	}
	fail := func(err error) (*core.Record, error) {
		rec.Set("status", "error")
		rec.Set("last_error", err.Error())
		app.Save(rec)
		return rec, nil
	}

	volumeName, networkName, err := ResolveWorkspaceVolumeAndNetwork(ctx, client)
	if err != nil {
		return fail(err)
	}

	image := harness.GetString("container_image")
	var launch struct {
		Cmd         []string          `json:"cmd"`
		Port        int               `json:"port"`
		EnvTemplate map[string]string `json:"env_template"`
	}
	_ = harness.UnmarshalJSONField("launch_template", &launch)

	providerID, modelID := "", ""
	if launchKey != "" {
		if hm, hmErr := app.FindRecordById("harness_models", launchKey); hmErr == nil {
			modelID = hm.GetString("harness_model_id")
			if model, modelErr := app.FindRecordById("models", hm.GetString("model")); modelErr == nil {
				providerID = model.GetString("provider")
			}
		}
	}
	env, err := renderEnv(app, launch.EnvTemplate, secret, harness.GetString("cli_id"), userID, providerID, modelID, account)
	if err != nil {
		return fail(fmt.Errorf("render launch_template.env_template: %w", err))
	}

	local, err := client.ImageExists(ctx, image)
	if err != nil {
		return fail(err)
	}
	if !local {
		if releaseartifact.ManagedReleaseImage(image, os.Getenv("POCKETCODER_RELEASE")) {
			if err := ensureReleaseHarnessImage(ctx, client, harness.GetString("cli_id"), image); err != nil {
				return fail(err)
			}
		} else if err := client.PullImage(ctx, image); err != nil {
			return fail(err)
		}
	}

	volumes, err := harnessvolume.Resolve(volumeName, userID, harness.GetString("cli_id"), account.Id)
	if err != nil {
		return fail(fmt.Errorf("resolve harness volumes: %w", err))
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
	networkNames := []string{networkName, HarnessEgressNetwork, ModelNetwork, "pocketcoder-mcp-gateway", "pocketcoder-memory"}
	_, err = client.Create(ctx, containerName, dockerapi.CreateSpec{
		Image:        image,
		Cmd:          launch.Cmd,
		Env:          env,
		VolumeBinds:  volumeBinds,
		NetworkNames: networkNames,
		Labels: map[string]string{
			"pc_managed":            "pocketcoder",
			"pc_release":            os.Getenv("POCKETCODER_RELEASE"),
			"pc_scope":              "user",
			"pc_scope_id":           userID,
			"pc_harness_id":         harnessID,
			"pc_harness_account_id": account.Id,
		},
	})
	if err != nil {
		return fail(err)
	}
	if err := client.Start(ctx, containerName); err != nil {
		return fail(err)
	}

	// Checked here (after Create+Start, not before) rather than as an
	// up-front validation: port is only needed to build the ws:// endpoint
	// URL below, not by the Docker create/start calls themselves, and a
	// pending row with no port must still count as "one Create call" for
	// a subsequent ProvisionHarnessInstance call; FindHarnessInstance matches this error row and
	// returns it rather than attempting a second Create.
	if launch.Port == 0 {
		return fail(fmt.Errorf("harness %s's launch_template has no port", harnessID))
	}

	rec.Set("status", "running")
	rec.Set("acp_endpoint", fmt.Sprintf("ws://%s:%d/acp", containerName, launch.Port))
	if err := app.Save(rec); err != nil {
		return nil, fmt.Errorf("save running harness_instances row: %w", err)
	}
	if copier, ok := client.(archiveCopier); ok {
		if err := MaterializeUserHarnessFiles(ctx, app, copier, rec); err != nil {
			return fail(err)
		}
	}
	return rec, nil
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

// renderEnv merges provider_keys according to the catalog harness's
// provider_scope. ProviderKey.provider stores harnesses.cli_id in the Flutter
// UI; provider-locked harnesses receive only their own keys, while
// multi-provider harnesses receive the user's complete key set. It also adds
// a reserved "__adapter_secret" key
// for the minted per-instance secret, and renders each env_template value
// as a Go text/template against that map . For example an entry
// {"ANTHROPIC_API_KEY": "{{.ANTHROPIC_API_KEY}}"} becomes
// "ANTHROPIC_API_KEY=sk-..." in the returned KEY=VALUE slice Docker's
// container-create API expects.
func renderEnv(app core.App, envTemplate map[string]string, secret, provider, userID, providerID, modelID string, account *core.Record) ([]string, error) {
	filter := "provider = {:provider} && user = {:user}"
	params := map[string]any{"provider": provider, "user": userID}
	providerScopeAny := false
	if harness, err := app.FindFirstRecordByFilter("harnesses", "cli_id = {:provider}", map[string]any{"provider": provider}); err == nil && harness.GetString("provider_scope") == "any" {
		// Multi-provider harnesses need the user's complete provider set;
		// provider-locked harnesses receive only their own credentials.
		providerScopeAny = true
		filter = "user = {:user}"
		params = map[string]any{"user": userID}
	}
	var keyRecs []*core.Record
	if account.GetString("credential_mode") == harnessaccount.ModeAPIKey && account.GetString("provider_key") != "" {
		key, err := app.FindRecordById("provider_keys", account.GetString("provider_key"))
		if err != nil {
			return nil, fmt.Errorf("resolve harness account provider key: %w", err)
		}
		keyRecs = []*core.Record{key}
	} else {
		var err error
		keyRecs, err = app.FindRecordsByFilter("provider_keys", filter, "", 0, 0, params)
		if err != nil {
			return nil, fmt.Errorf("query provider_keys: %w", err)
		}
	}
	values := map[string]string{
		"__adapter_secret": secret,
		"__ollama_host":    "http://ollama:11434",
		"__provider":       providerID,
		"__model":          modelID,
	}
	if account.GetString("credential_mode") == harnessaccount.ModeAccount && provider != "goose" {
		// Claude Code and Codex read their account login from the account-owned
		// HOME volume; their adapter image still declares API_KEY in its launch
		// template, so render it empty instead of requiring an unrelated key.
		keyRecs = nil
		values["API_KEY"] = ""
	}
	if provider == "goose" {
		if values["__provider"] == "" {
			values["__provider"] = "anthropic"
		}
		if values["__model"] == "" {
			values["__model"] = "MiniMax-M2.5"
		}
	}
	// Only OpenCode can run with the local Ollama provider and no cloud key.
	// Keep missing keys fatal for the Claude/Codex harnesses so their existing
	// provisioning guardrail remains intact.
	if provider == "opencode" {
		values["API_KEY"] = ""
	}
	for _, r := range keyRecs {
		var vars map[string]string
		if err := r.UnmarshalJSONField("env_vars", &vars); err != nil {
			continue
		}
		for k, v := range vars {
			values[k] = v
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
	if providerScopeAny {
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
	}
	return env, nil
}
