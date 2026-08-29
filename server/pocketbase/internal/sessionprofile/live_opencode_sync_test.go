//go:build live_opencode_sync

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

// Live acceptance test for the opencode CredentialSyncer path. Excluded from
// normal builds; run it explicitly (from inside the compose network, so
// DOCKER_HOST's default tcp://docker-socket-proxy-write:2375 resolves, and
// so the container this test provisions is reachable by name over ACP with
// no port-forward needed):
//
//	LIVE_OPENCODE_CREDENTIAL=<a real provider API key> \
//	go test -tags live_opencode_sync ./internal/sessionprofile/ -run TestLiveOpencodeCredentialSyncProducesRealReply -v
//
// This test provisions its own opencode container (rather than requiring one
// pre-existing) because the auth volume OpencodeAuthFileSyncer.Sync resolves
// to is derived from harnessvolume.Resolve(workspaceVolume, userID, "opencode", ""),
// and userID is only known once this test creates its own PocketBase test
// user -- an externally pre-existing container's volume name couldn't be
// known ahead of time.
package sessionprofile_test

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/ag-ui-protocol/ag-ui/sdks/community/go/pkg/core/events"
	acpsdk "github.com/coder/acp-go-sdk"
	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/agent/coordinator"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/dockerapi"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/harnessvolume"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/hooks"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/sessionprofile"
)

func TestLiveOpencodeCredentialSyncProducesRealReply(t *testing.T) {
	credential := os.Getenv("LIVE_OPENCODE_CREDENTIAL")
	if credential == "" {
		t.Skip("set LIVE_OPENCODE_CREDENTIAL (a real provider API key) to run this test")
	}

	app := testApp(t)
	user := testUser(t, app, "live-opencode-"+randomSuffix()+"@example.com")

	opencodeHarness, err := app.FindFirstRecordByFilter("harnesses", "cli_id = 'opencode'", nil)
	if err != nil {
		t.Fatalf("resolve seeded opencode harness: %v", err)
	}
	// openrouter isn't part of the default seed (only anthropic/openai are;
	// real deployments get it from the modelcatalog sync against models.dev,
	// which a bare in-memory test app never runs) -- create it and its
	// harness_providers edge here if missing, matching seed.go's own
	// ensureProvider/pinHarnessProvider shape.
	openrouter, err := app.FindFirstRecordByFilter("providers", "provider_id = 'openrouter'", nil)
	if err != nil {
		providersColl, cErr := app.FindCollectionByNameOrId("providers")
		if cErr != nil {
			t.Fatal(cErr)
		}
		openrouter = core.NewRecord(providersColl)
		openrouter.Set("provider_id", "openrouter")
		openrouter.Set("name", "OpenRouter")
		if err := app.Save(openrouter); err != nil {
			t.Fatalf("create openrouter provider: %v", err)
		}
	}
	if _, err := app.FindFirstRecordByFilter(
		"harness_providers", "harness = {:h} && provider = {:p}",
		map[string]any{"h": opencodeHarness.Id, "p": openrouter.Id},
	); err != nil {
		edgesColl, cErr := app.FindCollectionByNameOrId("harness_providers")
		if cErr != nil {
			t.Fatal(cErr)
		}
		edge := core.NewRecord(edgesColl)
		edge.Set("harness", opencodeHarness.Id)
		edge.Set("provider", openrouter.Id)
		if err := app.Save(edge); err != nil {
			t.Fatalf("create harness_providers edge for (opencode, openrouter): %v", err)
		}
	}

	client := dockerapi.New()
	ctx := context.Background()

	// Resolve the exact same auth volume OpencodeAuthFileSyncer.Sync will
	// resolve for this user, so the container we provision here shares it,
	// and the same network PocketBase itself is on, so this container is
	// reachable by name (Docker's embedded DNS only resolves container
	// names for containers sharing a user-defined network) from wherever
	// this test process itself runs.
	workspaceVolume, networkName, err := hooks.ResolveWorkspaceVolumeAndNetwork(ctx, client)
	if err != nil {
		t.Fatalf("resolve workspace volume: %v", err)
	}
	volumes, err := harnessvolume.Resolve(workspaceVolume, user.Id, "opencode", "")
	if err != nil {
		t.Fatalf("resolve harness volumes: %v", err)
	}

	image := opencodeHarness.GetString("container_image")
	if image == "" {
		t.Fatal("seeded opencode harness has no container_image")
	}
	secret := "live-opencode-sync-test-secret"
	containerName := "pc-live-opencode-sync-" + randomSuffix()
	if _, err := client.Create(ctx, containerName, dockerapi.CreateSpec{
		Image: image,
		Cmd:   []string{"--cmd", "opencode acp", "--port", "3000"},
		VolumeBinds: []string{
			volumes.Auth + ":" + harnessvolume.AuthHomeMount,
		},
		Env: []string{
			"POCKETCODER_HARNESS_CLI_ID=opencode",
			"HARNESS_ADAPTER_SECRET=" + secret,
			"HOME=" + harnessvolume.AuthHomeMount,
			"XDG_CONFIG_HOME=" + harnessvolume.AuthHomeMount + "/.config",
			"XDG_DATA_HOME=" + harnessvolume.AuthHomeMount + "/.local/share",
		},
		NetworkNames:  []string{networkName},
		RestartPolicy: "no",
	}); err != nil {
		t.Fatalf("create opencode test container: %v", err)
	}
	t.Cleanup(func() {
		_ = client.Remove(context.Background(), containerName)
	})
	if err := client.Start(ctx, containerName); err != nil {
		t.Fatalf("start opencode test container: %v", err)
	}
	acpEndpoint := fmt.Sprintf("ws://%s:3000/acp", containerName)

	instColl, err := app.FindCollectionByNameOrId("harness_instances")
	if err != nil {
		t.Fatal(err)
	}
	instance := core.NewRecord(instColl)
	instance.Set("harness", opencodeHarness.Id)
	instance.Set("launch_key", "")
	instance.Set("container_name", containerName)
	instance.Set("acp_endpoint", acpEndpoint)
	instance.Set("secret", secret)
	instance.Set("status", "running")
	instance.Set("managed", false)
	instance.Set("user", user.Id)
	instance.Set("oauth_account", "")
	if err := app.Save(instance); err != nil {
		t.Fatal(err)
	}

	keysColl, err := app.FindCollectionByNameOrId("provider_api_keys")
	if err != nil {
		t.Fatal(err)
	}
	key := core.NewRecord(keysColl)
	key.Set("owner", user.Id)
	key.Set("provider", openrouter.Id)
	key.Set("api_key", credential)
	if err := app.Save(key); err != nil {
		t.Fatal(err)
	}

	selColl, err := app.FindCollectionByNameOrId("credential_selections")
	if err != nil {
		t.Fatal(err)
	}
	sel := core.NewRecord(selColl)
	sel.Set("user", user.Id)
	sel.Set("harness", opencodeHarness.Id)
	sel.Set("provider", openrouter.Id)
	sel.Set("mode", "none")
	if err := app.Save(sel); err != nil {
		t.Fatal(err)
	}

	// Build resolves the live-config provider from the most recent
	// credential_selections row, then needs a matching harness_models row
	// to actually resolve a model for it (sessionprofile.go's
	// resolveDefaultHarnessModel call) -- without this, providerRec stays
	// nil and CredentialFieldValue never gets populated.
	model := testModel(t, app, openrouter.Id, "test-openrouter-model")
	testHarnessModel(t, app, opencodeHarness.Id, model.Id, "openrouter/auto")

	chat := testChat(t, app, user.Id, map[string]any{"harness": opencodeHarness.Id})

	// This is the real path under test: Build resolves the credential and
	// calls selectCredentialSyncer(opencodeHarness).Sync(...), which -- on
	// this first call, since synced_credentials starts empty -- writes into
	// the container's mounted auth.json via a helper container and restarts
	// this exact container.
	profile, err := sessionprofile.Build(app, chat.Id, context.Background(), "")
	if err != nil {
		t.Fatalf("Build (exercises the real CredentialSyncer path): %v", err)
	}
	if profile.CredentialFieldValue == "" {
		t.Fatal("expected CredentialFieldValue to be populated for a live-config harness with a saved key")
	}
	// Build defaults Mode to "approve", a session mode id this opencode
	// image doesn't advertise -- unrelated to what this test is verifying
	// (credential sync), so clear it: GlobalConfigApplier.Apply skips
	// SetSessionMode entirely when Mode is empty. Also clear Model: the
	// fixture's fake "openrouter/auto" isn't a real model id opencode's
	// catalog recognizes, and this test doesn't need to pin one -- letting
	// opencode use its own default model is enough to prove the credential
	// sync itself produces a real, authenticated reply.
	profile.Mode = ""
	profile.Model = ""
	t.Logf("profile resolved: provider=%s target=%s", profile.Provider, profile.Target.URL)

	// Re-run Build once more: the credential hash should already match
	// what Sync saved, so this exercises the cheap no-op path (no second
	// Docker round-trip / restart).
	if _, err := sessionprofile.Build(app, chat.Id, context.Background(), ""); err != nil {
		t.Fatalf("second Build call (should hit the cached-hash no-op path): %v", err)
	}

	c, err := coordinator.New(coordinator.Config{Workspace: "/workspace", PermissionTimeout: time.Minute})
	if err != nil {
		t.Fatal(err)
	}
	resolve := func(context.Context) (string, error) { return "", nil }
	profileFn := func(context.Context) (coordinator.SessionProfile, error) { return profile, nil }
	created := func(context.Context, string) error { return nil }
	finished := func(context.Context, acpsdk.StopReason) error { return nil }

	// OpencodeAuthFileSyncer.Sync just restarted this container (as part of
	// the first Build call above); the process inside needs a moment to
	// start listening again before a dial succeeds. Retry the whole
	// prompt+attach round a few times rather than sleeping a fixed,
	// possibly-too-short or too-long amount.
	var gotTypes []events.EventType
	var reply string
	const maxAttempts = 10
	for attempt := 1; attempt <= maxAttempts; attempt++ {
		chatID := fmt.Sprintf("live-opencode-sync-chat-%d", attempt)
		if _, err := c.StartPrompt(chatID, "Reply with exactly: opencode sync ok", resolve, profileFn, created, finished); err != nil {
			t.Fatalf("StartPrompt failed: %v", err)
		}
		att := c.Attach(chatID, 0)

		gotTypes = nil
		reply = ""
		for _, e := range att.Buffered {
			gotTypes = append(gotTypes, e.Ev.Type())
			if content, ok := e.Ev.(*events.TextMessageContentEvent); ok {
				reply += content.Delta
			}
		}
		terminal := func(t events.EventType) bool {
			return t == events.EventTypeRunFinished || t == events.EventTypeRunError
		}
		deadline := time.After(15 * time.Second)
	drainLoop:
		for {
			if len(gotTypes) > 0 && terminal(gotTypes[len(gotTypes)-1]) {
				break
			}
			select {
			case e, ok := <-att.Live:
				if !ok {
					break drainLoop
				}
				gotTypes = append(gotTypes, e.Ev.Type())
				if content, ok := e.Ev.(*events.TextMessageContentEvent); ok {
					reply += content.Delta
				}
			case <-deadline:
				break drainLoop
			}
		}
		att.Unsubscribe()

		if len(gotTypes) > 0 && gotTypes[len(gotTypes)-1] == events.EventTypeRunFinished {
			break // success
		}
		t.Logf("attempt %d/%d: container likely still restarting, retrying: events=%v", attempt, maxAttempts, gotTypes)
		time.Sleep(2 * time.Second)
	}
	if len(gotTypes) == 0 {
		t.Fatal("expected at least one event")
	}
	if last := gotTypes[len(gotTypes)-1]; last != events.EventTypeRunFinished {
		t.Fatalf("run did not finish successfully after %d attempts: %v", maxAttempts, gotTypes)
	}
	if reply == "" {
		t.Fatal("expected a non-empty assistant reply")
	}
	t.Logf("opencode credential sync + real model reply: %q (events=%v)", reply, gotTypes)
}
