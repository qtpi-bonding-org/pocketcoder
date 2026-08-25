package hooks

import (
	"context"
	"fmt"
	"io"
	"strings"
	"testing"

	"github.com/google/uuid"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/dockerapi"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/harnessaccount"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/harnessvolume"
	_ "github.com/qtpi-bonding-org/pocketcoder/backend/pb_migrations"
)

type fakeInspectClient struct {
	insp dockerapi.ContainerInspect
}

func (f *fakeInspectClient) Inspect(ctx context.Context, containerName string) (dockerapi.ContainerInspect, error) {
	return f.insp, nil
}

func TestResolveWorkspaceVolumeAndNetworkMatchesByDestinationAndSuffix(t *testing.T) {
	fake := &fakeInspectClient{
		insp: dockerapi.ContainerInspect{
			Mounts: []dockerapi.Mount{
				{Destination: "/app/pb_data", Name: "proj_pb_data"},
				{Destination: "/workspace", Name: "proj_workspace"},
			},
		},
	}
	fake.insp.NetworkSettings.Networks = map[string]dockerapi.NetworkEndpoint{
		"proj_pocketcoder-dashboard": {},
		"proj_pocketcoder-agent":     {},
	}
	vol, net, err := ResolveWorkspaceVolumeAndNetwork(context.Background(), fake)
	if err != nil {
		t.Fatal(err)
	}
	if vol != "proj_workspace" {
		t.Errorf("volume = %q, want proj_workspace", vol)
	}
	if net != "proj_pocketcoder-agent" {
		t.Errorf("network = %q, want proj_pocketcoder-agent", net)
	}
}

func TestResolveWorkspaceVolumeAndNetworkErrorsWhenNoMatch(t *testing.T) {
	fake := &fakeInspectClient{insp: dockerapi.ContainerInspect{}}
	_, _, err := ResolveWorkspaceVolumeAndNetwork(context.Background(), fake)
	if err == nil {
		t.Fatal("expected an error when no /workspace mount or pocketcoder-agent network is found")
	}
}

// --- shared test helpers -----------------------------------------------

// testApp spins up a fresh in-memory PocketBase test app with this repo's
// migrations applied, and registers cleanup.
func testApp(t *testing.T) core.App {
	t.Helper()
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(app.Cleanup)
	return app
}

// createTestHarness inserts a harnesses row with sane defaults, overridden
// by whatever fields the caller supplies.
func createTestHarness(t *testing.T, app core.App, overrides map[string]any) *core.Record {
	t.Helper()
	coll, err := app.FindCollectionByNameOrId("harnesses")
	if err != nil {
		t.Fatal(err)
	}
	rec := core.NewRecord(coll)
	rec.Set("name", "Test Harness")
	rec.Set("cli_id", "test-harness-"+uuid.NewString()[:8])
	rec.Set("acp_transport", "websocket")
	for k, v := range overrides {
		rec.Set(k, v)
	}
	if err := app.Save(rec); err != nil {
		t.Fatal(err)
	}
	return rec
}

// testUser creates a test user in the _pb_users_auth_ collection.
func testUser(t *testing.T, app core.App, email string) *core.Record {
	t.Helper()
	users, err := app.FindCollectionByNameOrId("_pb_users_auth_")
	if err != nil {
		t.Fatal(err)
	}
	user := core.NewRecord(users)
	user.SetEmail(email)
	user.SetPassword("password12345")
	if err := app.Save(user); err != nil {
		t.Fatal(err)
	}
	return user
}

// createTestProviderKey inserts a provider_keys row (with a fresh owning
// user, since `user` is required) with sane defaults, overridden by
// whatever fields the caller supplies.
func createTestProviderKey(t *testing.T, app core.App, overrides map[string]any, userID string) *core.Record {
	t.Helper()
	if userID == "" {
		userID = testUser(t, app, fmt.Sprintf("test-provider-key-%s@example.com", uuid.NewString()[:8])).Id
	}

	coll, err := app.FindCollectionByNameOrId("provider_keys")
	if err != nil {
		t.Fatal(err)
	}
	rec := core.NewRecord(coll)
	rec.Set("user", userID)
	rec.Set("provider", "anthropic")
	for k, v := range overrides {
		rec.Set(k, v)
	}
	if err := app.Save(rec); err != nil {
		t.Fatal(err)
	}
	return rec
}

// fakeDockerClient is a dockerProvisioner test double that records
// PullImage/Create/Start calls instead of talking to a real Docker socket.
type fakeDockerClient struct {
	imageExists bool
	inspectErr  error
	pullErr     error
	createErr   error
	startErr    error

	// ollamaMissing simulates the default (no local-models) deployment: no
	// "pocketcoder-ollama" container exists. Defaults to false (Ollama
	// "running") so every pre-existing test that doesn't care about this
	// keeps seeing ModelNetwork in its network list, unchanged.
	ollamaMissing bool

	pulledImages      []string
	createdContainers []string
	startedContainers []string
	createCallCount   int
	lastCreateSpec    dockerapi.CreateSpec
}

func newFakeDockerClient() *fakeDockerClient {
	return &fakeDockerClient{}
}

func (f *fakeDockerClient) Inspect(ctx context.Context, containerName string) (dockerapi.ContainerInspect, error) {
	if containerName == ollamaContainerName && f.ollamaMissing {
		return dockerapi.ContainerInspect{}, dockerapi.ErrContainerNotFound
	}
	insp := dockerapi.ContainerInspect{
		Mounts: []dockerapi.Mount{{Destination: "/workspace", Name: "test_workspace"}},
	}
	insp.NetworkSettings.Networks = map[string]dockerapi.NetworkEndpoint{
		"test_pocketcoder-agent": {},
	}
	return insp, nil
}

func (f *fakeDockerClient) ImageExists(ctx context.Context, image string) (bool, error) {
	return f.imageExists, f.inspectErr
}

func (f *fakeDockerClient) PullImage(ctx context.Context, image string) error {
	if f.pullErr != nil {
		return f.pullErr
	}
	f.pulledImages = append(f.pulledImages, image)
	return nil
}

func (f *fakeDockerClient) LoadImage(_ context.Context, archive io.Reader) error {
	_, err := io.Copy(io.Discard, archive)
	if err == nil {
		f.imageExists = true
	}
	return err
}

func (f *fakeDockerClient) Create(ctx context.Context, name string, spec dockerapi.CreateSpec) (string, error) {
	f.createCallCount++
	f.lastCreateSpec = spec
	if f.createErr != nil {
		return "", f.createErr
	}
	f.createdContainers = append(f.createdContainers, name)
	return "fake-id-" + name, nil
}

func (f *fakeDockerClient) Start(ctx context.Context, containerName string) error {
	if f.startErr != nil {
		return f.startErr
	}
	f.startedContainers = append(f.startedContainers, containerName)
	return nil
}

func (f *fakeDockerClient) pulledImage(image string) bool {
	for _, i := range f.pulledImages {
		if i == image {
			return true
		}
	}
	return false
}

func (f *fakeDockerClient) started(name string) bool {
	for _, n := range f.startedContainers {
		if n == name {
			return true
		}
	}
	return false
}

// --- ProvisionHarnessInstance --------------------------------------------

func TestProvisionHarnessInstanceCreatesAndStartsContainer(t *testing.T) {
	app := testApp(t)
	userID := testUser(t, app, "test-harness-user-"+uuid.NewString()[:8]+"@example.com").Id
	harness := createTestHarness(t, app, map[string]any{
		"container_image": "example.com/harness:1.0",
		"launch_template": map[string]any{"cmd": []string{"/adapter"}, "port": 3000},
	})
	fake := newFakeDockerClient() // records Create/Start/PullImage calls; add to a shared test-doubles file in this package
	rec, err := ProvisionHarnessInstance(context.Background(), app, fake, harness.Id, "", userID)
	if err != nil {
		t.Fatal(err)
	}
	if rec.GetString("status") != "running" {
		t.Errorf("status = %q, want running", rec.GetString("status"))
	}
	if !fake.pulledImage("example.com/harness:1.0") {
		t.Error("expected the harness's image to be pulled")
	}
	if !fake.started(rec.GetString("container_name")) {
		t.Error("expected the created container to be started")
	}
}

// TestProvisionHarnessInstanceJoinsModelNetworkOnlyWhenOllamaIsRunning is
// the regression test for a real incident: harness creation unconditionally
// requested ModelNetwork ("pocketcoder-model"), but Docker Compose only
// creates that network when the `ollama` service (profile-gated behind
// `local-models`, off by default) is actually started -- so every default
// deployment failed 100% of harness creations with "failed to set up
// container networking: network pocketcoder-model not found", leaving the
// container stuck at Created, never started. Confirmed live via SSH before
// this fix.
func TestProvisionHarnessInstanceJoinsModelNetworkOnlyWhenOllamaIsRunning(t *testing.T) {
	app := testApp(t)
	harness := createTestHarness(t, app, map[string]any{
		"container_image": "example.com/harness:1.0",
		"launch_template": map[string]any{"cmd": []string{"/adapter"}, "port": 3000},
	})

	t.Run("Ollama running: joins ModelNetwork", func(t *testing.T) {
		userID := testUser(t, app, "model-net-on-"+uuid.NewString()[:8]+"@example.com").Id
		fake := newFakeDockerClient()
		if _, err := ProvisionHarnessInstance(context.Background(), app, fake, harness.Id, "", userID); err != nil {
			t.Fatal(err)
		}
		if !containsString(fake.lastCreateSpec.NetworkNames, ModelNetwork) {
			t.Fatalf("networks = %v, want ModelNetwork included", fake.lastCreateSpec.NetworkNames)
		}
	})

	t.Run("Ollama not running (default deployment): omits ModelNetwork, still succeeds", func(t *testing.T) {
		userID := testUser(t, app, "model-net-off-"+uuid.NewString()[:8]+"@example.com").Id
		fake := newFakeDockerClient()
		fake.ollamaMissing = true
		rec, err := ProvisionHarnessInstance(context.Background(), app, fake, harness.Id, "", userID)
		if err != nil {
			t.Fatal(err)
		}
		if rec.GetString("status") != "running" {
			t.Fatalf("status = %q, want running", rec.GetString("status"))
		}
		if containsString(fake.lastCreateSpec.NetworkNames, ModelNetwork) {
			t.Fatalf("networks = %v, want ModelNetwork omitted when Ollama isn't running",
				fake.lastCreateSpec.NetworkNames)
		}
		if !containsString(fake.lastCreateSpec.NetworkNames, HarnessEgressNetwork) {
			t.Fatalf("networks = %v, want the other networks still present",
				fake.lastCreateSpec.NetworkNames)
		}
	})
}

func TestProvisionHarnessInstanceReusesLocalImageWithoutPulling(t *testing.T) {
	app := testApp(t)
	userID := testUser(t, app, "test-harness-user-"+uuid.NewString()[:8]+"@example.com").Id
	harness := createTestHarness(t, app, map[string]any{
		"container_image": "pocketcoder-harness-claude-code:0.64.2",
		"launch_template": map[string]any{"cmd": []string{"--cmd", "claude-agent-acp", "--port", "3000"}, "port": 3000},
	})
	fake := newFakeDockerClient()
	fake.imageExists = true
	rec, err := ProvisionHarnessInstance(context.Background(), app, fake, harness.Id, "", userID)
	if err != nil {
		t.Fatal(err)
	}
	if rec.GetString("status") != "running" {
		t.Fatalf("status = %q, want running", rec.GetString("status"))
	}
	if len(fake.pulledImages) != 0 {
		t.Errorf("pulledImages = %v, want no registry pull for a local first-party image", fake.pulledImages)
	}
}

func TestProvisionHarnessInstanceLoadsMissingManagedReleaseArtifact(t *testing.T) {
	const release = "0123456789abcdef0123456789abcdef01234567"
	t.Setenv("POCKETCODER_RELEASE", release)
	app := testApp(t)
	userID := testUser(t, app, "test-managed-image-"+uuid.NewString()[:8]+"@example.com").Id
	harness, err := app.FindFirstRecordByFilter("harnesses", "cli_id = 'codex'", nil)
	if err != nil {
		t.Fatal(err)
	}
	harness.Set("container_image", "pocketcoder-harness-codex:"+release)
	harness.Set("launch_template", map[string]any{"cmd": []string{"/adapter"}, "port": 3000})
	if err := app.Save(harness); err != nil {
		t.Fatal(err)
	}
	fake := newFakeDockerClient()
	called := false
	original := ensureReleaseHarnessImage
	ensureReleaseHarnessImage = func(_ context.Context, _ dockerProvisioner, harnessID, image string) error {
		called = true
		if harnessID != "codex" || image != "pocketcoder-harness-codex:"+release {
			t.Fatalf("artifact request = %s/%s", harnessID, image)
		}
		fake.imageExists = true
		return nil
	}
	t.Cleanup(func() { ensureReleaseHarnessImage = original })

	rec, err := ProvisionHarnessInstance(context.Background(), app, fake, harness.Id, "", userID)
	if err != nil {
		t.Fatal(err)
	}
	if !called || rec.GetString("status") != "running" {
		t.Fatalf("artifact called/status = %v/%q", called, rec.GetString("status"))
	}
	if len(fake.pulledImages) != 0 {
		t.Fatalf("managed release image used registry fallback: %v", fake.pulledImages)
	}
}

func TestProvisionGooseUsesTheCommonHarnessStorageAndNetworkShape(t *testing.T) {
	app := testApp(t)
	userID := testUser(t, app, "test-goose-user-"+uuid.NewString()[:8]+"@example.com").Id
	harness, err := app.FindFirstRecordByFilter("harnesses", "cli_id = 'goose'", nil)
	if err != nil {
		t.Fatal(err)
	}
	// Goose's seeded env_template unconditionally references
	// {{.OPENROUTER_API_KEY}}, and its provider_scope is "any" (renderEnv
	// pulls every provider_keys row the user owns, not just one scoped to
	// "goose") -- without a key on file the render fails and
	// ProvisionHarnessInstance's fail() closure swallows that into the
	// record's own status/last_error rather than returning a Go error,
	// leaving client.Create never called and every assertion below
	// comparing against a zero-value CreateSpec.
	createTestProviderKey(t, app, map[string]any{
		"provider": "any-provider-test",
		"env_vars": map[string]any{"OPENROUTER_API_KEY": "sk-test-openrouter"},
	}, userID)
	fake := newFakeDockerClient()
	rec, err := ProvisionHarnessInstance(context.Background(), app, fake, harness.Id, "", userID)
	if err != nil {
		t.Fatal(err)
	}
	if status := rec.GetString("status"); status == "error" {
		t.Fatalf("provisioning recorded status=error, last_error=%s", rec.GetString("last_error"))
	}
	foundAuthHome := false
	for _, bind := range fake.lastCreateSpec.VolumeBinds {
		if strings.HasSuffix(bind, ":"+harnessvolume.AuthHomeMount) {
			foundAuthHome = true
		}
		if strings.HasSuffix(bind, ":/goose") {
			t.Fatalf("Goose has a legacy-only /goose mount: %v", fake.lastCreateSpec.VolumeBinds)
		}
	}
	if !foundAuthHome {
		t.Fatalf("Goose volume binds = %v, want the common auth-home mount", fake.lastCreateSpec.VolumeBinds)
	}
	if !containsString(fake.lastCreateSpec.NetworkNames, HarnessEgressNetwork) {
		t.Fatalf("Goose networks = %v, want shared harness egress", fake.lastCreateSpec.NetworkNames)
	}
	for _, network := range fake.lastCreateSpec.NetworkNames {
		if strings.Contains(network, "goose-egress") {
			t.Fatalf("Goose has a legacy-only egress network: %v", fake.lastCreateSpec.NetworkNames)
		}
	}
}

func TestDefaultGooseAndPeerHarnessHaveEqualRuntimeTopology(t *testing.T) {
	app := testApp(t)
	userID := testUser(t, app, "topology-user-"+uuid.NewString()[:8]+"@example.com").Id
	goose, err := app.FindFirstRecordByFilter("harnesses", "cli_id = 'goose'", nil)
	if err != nil {
		t.Fatal(err)
	}
	peer := createTestHarness(t, app, map[string]any{
		"cli_id":          "peer-topology-" + uuid.NewString()[:8],
		"container_image": "peer-topology-image",
		"launch_template": map[string]any{"port": 3000},
	})

	// See TestProvisionGooseUsesTheCommonHarnessStorageAndNetworkShape's
	// comment: goose's seeded env_template needs an OPENROUTER_API_KEY
	// from some provider_keys row (provider_scope "any"), or renderEnv
	// fails and ProvisionHarnessInstance silently records status=error
	// without ever calling client.Create.
	createTestProviderKey(t, app, map[string]any{
		"provider": "any-provider-test",
		"env_vars": map[string]any{"OPENROUTER_API_KEY": "sk-test-openrouter"},
	}, userID)

	gooseDocker, peerDocker := newFakeDockerClient(), newFakeDockerClient()
	gooseRec, err := ProvisionHarnessInstance(context.Background(), app, gooseDocker, goose.Id, "", userID)
	if err != nil {
		t.Fatal(err)
	}
	if status := gooseRec.GetString("status"); status == "error" {
		t.Fatalf("goose provisioning recorded status=error, last_error=%s", gooseRec.GetString("last_error"))
	}
	peerRec, err := ProvisionHarnessInstance(context.Background(), app, peerDocker, peer.Id, "", userID)
	if err != nil {
		t.Fatal(err)
	}
	if status := peerRec.GetString("status"); status == "error" {
		t.Fatalf("peer provisioning recorded status=error, last_error=%s", peerRec.GetString("last_error"))
	}
	if fmt.Sprint(gooseDocker.lastCreateSpec.NetworkNames) != fmt.Sprint(peerDocker.lastCreateSpec.NetworkNames) {
		t.Fatalf("network topology differs: Goose=%v peer=%v", gooseDocker.lastCreateSpec.NetworkNames, peerDocker.lastCreateSpec.NetworkNames)
	}
	mountDestinations := func(binds []string) []string {
		result := make([]string, 0, len(binds))
		for _, bind := range binds {
			if split := strings.LastIndexByte(bind, ':'); split >= 0 {
				result = append(result, bind[split+1:])
			}
		}
		return result
	}
	gooseMounts := mountDestinations(gooseDocker.lastCreateSpec.VolumeBinds)
	peerMounts := mountDestinations(peerDocker.lastCreateSpec.VolumeBinds)
	if fmt.Sprint(gooseMounts) != fmt.Sprint(peerMounts) {
		t.Fatalf("storage topology differs: Goose=%v peer=%v", gooseMounts, peerMounts)
	}
}

func TestProvisionHarnessInstanceIsIdempotent(t *testing.T) {
	// Deliberately exercises launchKey = "" (the supports_live_config = true
	// case, i.e. Goose-shaped harnesses) — this is the exact case a naive
	// `"harness = {:h} && launch_key = {:k}"` filter fails to match on the
	// second call, per the finding above. A regression here means the fix
	// didn't take.
	app := testApp(t)
	userID := testUser(t, app, "test-harness-user-"+uuid.NewString()[:8]+"@example.com").Id
	harness := createTestHarness(t, app, map[string]any{"container_image": "x", "launch_template": map[string]any{"cmd": []string{"/adapter"}}})
	fake := newFakeDockerClient()
	rec1, err := ProvisionHarnessInstance(context.Background(), app, fake, harness.Id, "", userID)
	if err != nil {
		t.Fatal(err)
	}
	rec2, err := ProvisionHarnessInstance(context.Background(), app, fake, harness.Id, "", userID)
	if err != nil {
		t.Fatal(err)
	}
	if rec1.Id != rec2.Id {
		t.Error("expected the second call to return the same row, not create a duplicate")
	}
	if fake.createCallCount != 1 {
		t.Errorf("expected exactly one Create call across both invocations, got %d", fake.createCallCount)
	}
}

func TestProvisionHarnessInstanceRecreatesStoppedReleaseContainer(t *testing.T) {
	app := testApp(t)
	userID := testUser(t, app, "test-stopped-harness-"+uuid.NewString()[:8]+"@example.com").Id
	harness := createTestHarness(t, app, map[string]any{
		"container_image": "example.com/harness:2.0",
		"launch_template": map[string]any{"cmd": []string{"/adapter"}, "port": 3000},
	})
	account, err := harnessaccount.EnsureDefaultPersonal(app, userID, harness.Id)
	if err != nil {
		t.Fatal(err)
	}
	instances, err := app.FindCollectionByNameOrId("harness_instances")
	if err != nil {
		t.Fatal(err)
	}
	stale := core.NewRecord(instances)
	stale.Set("harness", harness.Id)
	stale.Set("user", userID)
	stale.Set("harness_account", account.Id)
	stale.Set("launch_key", "")
	stale.Set("container_name", "old-release-container")
	stale.Set("secret", "old-secret")
	stale.Set("status", "stopped")
	stale.Set("managed", true)
	if err := app.Save(stale); err != nil {
		t.Fatal(err)
	}

	fake := newFakeDockerClient()
	replacement, err := ProvisionHarnessInstance(context.Background(), app, fake, harness.Id, "", userID)
	if err != nil {
		t.Fatal(err)
	}
	if replacement.Id == stale.Id || replacement.GetString("container_name") == "old-release-container" {
		t.Fatal("stopped release container row was reused instead of recreated")
	}
	if replacement.GetString("status") != "running" || fake.createCallCount != 1 {
		t.Fatalf("replacement status/create calls = %q/%d", replacement.GetString("status"), fake.createCallCount)
	}
}

func TestProvisionHarnessInstanceSurfacesPullFailure(t *testing.T) {
	app := testApp(t)
	userID := testUser(t, app, "test-harness-user-"+uuid.NewString()[:8]+"@example.com").Id
	harness := createTestHarness(t, app, map[string]any{"container_image": "nonexistent:latest", "launch_template": map[string]any{"cmd": []string{"/adapter"}, "port": 3000}})
	fake := newFakeDockerClient()
	fake.pullErr = fmt.Errorf("No such image")
	rec, err := ProvisionHarnessInstance(context.Background(), app, fake, harness.Id, "", userID)
	if err != nil {
		t.Fatal("ProvisionHarnessInstance itself should not error — the failure surfaces on the row")
	}
	if rec.GetString("status") != "error" {
		t.Errorf("status = %q, want error", rec.GetString("status"))
	}
	if rec.GetString("last_error") == "" {
		t.Error("expected last_error to be populated with the pull failure")
	}
}

func TestProvisionHarnessInstanceErrorsOnMissingPort(t *testing.T) {
	app := testApp(t)
	userID := testUser(t, app, "test-harness-user-"+uuid.NewString()[:8]+"@example.com").Id
	harness := createTestHarness(t, app, map[string]any{"container_image": "x", "launch_template": map[string]any{"cmd": []string{"/adapter"}}}) // no "port"
	fake := newFakeDockerClient()
	rec, err := ProvisionHarnessInstance(context.Background(), app, fake, harness.Id, "", userID)
	if err != nil {
		t.Fatal(err)
	}
	if rec.GetString("status") != "error" {
		t.Errorf("status = %q, want error — a launch_template with no port must not silently produce ws://host:0/acp", rec.GetString("status"))
	}
}

func TestProvisionHarnessInstanceRendersProviderKeysAndMintsSecret(t *testing.T) {
	app := testApp(t)
	userID := testUser(t, app, "test-harness-user-"+uuid.NewString()[:8]+"@example.com").Id
	createTestProviderKey(t, app, map[string]any{"provider": harnessProviderForTest, "env_vars": map[string]any{"API_KEY": "sk-test-123"}}, userID)
	harness := createTestHarness(t, app, map[string]any{
		"cli_id":          harnessProviderForTest,
		"container_image": "example.com/harness:1.0",
		"launch_template": map[string]any{
			"cmd":  []string{"/adapter"},
			"port": 3000,
			"env_template": map[string]any{
				"ANTHROPIC_API_KEY": "{{.API_KEY}}",
				"ADAPTER_SECRET":    "{{.__adapter_secret}}",
			},
		},
	})
	fake := newFakeDockerClient()
	rec, err := ProvisionHarnessInstance(context.Background(), app, fake, harness.Id, "", userID)
	if err != nil {
		t.Fatal(err)
	}
	if rec.GetString("secret") == "" {
		t.Error("expected a minted, non-empty secret on the harness_instances row")
	}
	env := fake.lastCreateSpec.Env
	found := map[string]bool{}
	for _, kv := range env {
		if kv == "ANTHROPIC_API_KEY=sk-test-123" {
			found["key"] = true
		}
		if kv == "ADAPTER_SECRET="+rec.GetString("secret") {
			found["secret"] = true
		}
	}
	if !found["key"] {
		t.Errorf("env = %v, want ANTHROPIC_API_KEY=sk-test-123 rendered from provider_keys", env)
	}
	if !found["secret"] {
		t.Errorf("env = %v, want ADAPTER_SECRET matching the row's minted secret", env)
	}
}

func TestProvisionHarnessInstanceAccountLoginDoesNotRequireAPIKey(t *testing.T) {
	app := testApp(t)
	user := testUser(t, app, "account-login-"+uuid.NewString()[:8]+"@example.com")
	harness := createTestHarness(t, app, map[string]any{
		"cli_id":          "codex-account-login-test",
		"container_image": "local-codex",
		"launch_template": map[string]any{
			"cmd":          []string{"codex-acp"},
			"port":         3000,
			"env_template": map[string]any{"OPENAI_API_KEY": "{{.API_KEY}}"},
		},
	})
	account, err := harnessaccount.SelectOrCreate(app, user.Id, harness.Id, "", "Personal Codex", harnessaccount.VisibilityPersonal, harnessaccount.ModeAccount)
	if err != nil {
		t.Fatal(err)
	}
	account.Set("credential_mode", harnessaccount.ModeAccount)
	if err := app.Save(account); err != nil {
		t.Fatal(err)
	}
	fake := newFakeDockerClient()
	fake.imageExists = true
	rec, err := ProvisionHarnessInstance(context.Background(), app, fake, harness.Id, "", user.Id)
	if err != nil {
		t.Fatal(err)
	}
	if rec.GetString("status") != "running" {
		t.Fatalf("status = %q, want running", rec.GetString("status"))
	}
	if !containsString(fake.lastCreateSpec.Env, "OPENAI_API_KEY=") {
		t.Fatalf("env = %v, want empty API key for account-volume login", fake.lastCreateSpec.Env)
	}
}

func containsString(values []string, want string) bool {
	for _, value := range values {
		if value == want {
			return true
		}
	}
	return false
}

const harnessProviderForTest = "claude-code-test"

func TestProvisionHarnessInstanceScopesGenericAPIKeyToSelectedHarness(t *testing.T) {
	app := testApp(t)
	userID := testUser(t, app, "test-harness-user-"+uuid.NewString()[:8]+"@example.com").Id
	createTestProviderKey(t, app, map[string]any{"provider": "claude-code-scope-test", "env_vars": map[string]any{"API_KEY": "claude-key"}}, userID)
	createTestProviderKey(t, app, map[string]any{"provider": "codex-scope-test", "env_vars": map[string]any{"API_KEY": "codex-key"}}, userID)
	harness := createTestHarness(t, app, map[string]any{
		"cli_id":          "codex-scope-test",
		"container_image": "pocketcoder-harness-codex:1.1.9",
		"launch_template": map[string]any{
			"cmd":          []string{"--cmd", "codex-acp", "--port", "3000"},
			"port":         3000,
			"env_template": map[string]any{"OPENAI_API_KEY": "{{.API_KEY}}"},
		},
	})
	fake := newFakeDockerClient()
	_, err := ProvisionHarnessInstance(context.Background(), app, fake, harness.Id, "", userID)
	if err != nil {
		t.Fatal(err)
	}
	got := fake.lastCreateSpec.Env
	want := map[string]bool{
		"OPENAI_API_KEY=codex-key":                                false,
		"HOME=/workspace/.pocketcoder_auth":                       false,
		"XDG_CONFIG_HOME=/workspace/.pocketcoder_auth/.config":    false,
		"XDG_DATA_HOME=/workspace/.pocketcoder_auth/.local/share": false,
	}
	for _, entry := range got {
		if _, ok := want[entry]; ok {
			want[entry] = true
		}
	}
	for entry, found := range want {
		if !found {
			t.Errorf("Env = %v, missing %s", got, entry)
		}
	}
}

func TestProvisionHarnessInstanceUsesPerHarnessPersistentAuthVolume(t *testing.T) {
	app := testApp(t)
	harness := createTestHarness(t, app, map[string]any{
		"cli_id":          "codex-volume-test",
		"container_image": "local-codex",
		"launch_template": map[string]any{"cmd": []string{"codex-acp"}, "port": 3000},
	})

	firstUser := testUser(t, app, "first-auth-volume@example.com")
	secondUser := testUser(t, app, "second-auth-volume@example.com")
	firstDocker := newFakeDockerClient()
	secondDocker := newFakeDockerClient()
	firstDocker.imageExists = true
	secondDocker.imageExists = true
	if _, err := harnessaccount.SelectOrCreate(app, firstUser.Id, harness.Id, "", "Family Codex", harnessaccount.VisibilityDeployment, harnessaccount.ModeAccount); err != nil {
		t.Fatal(err)
	}
	if _, err := harnessaccount.SelectOrCreate(app, secondUser.Id, harness.Id, "", "", harnessaccount.VisibilityDeployment, harnessaccount.ModeAccount); err != nil {
		t.Fatal(err)
	}
	if _, err := ProvisionHarnessInstance(context.Background(), app, firstDocker, harness.Id, "", firstUser.Id); err != nil {
		t.Fatal(err)
	}
	if _, err := ProvisionHarnessInstance(context.Background(), app, secondDocker, harness.Id, "", secondUser.Id); err != nil {
		t.Fatal(err)
	}

	findMount := func(binds []string, destination string) string {
		for _, bind := range binds {
			if strings.HasSuffix(bind, ":"+destination) {
				return strings.TrimSuffix(bind, ":"+destination)
			}
		}
		return ""
	}
	firstAuth := findMount(firstDocker.lastCreateSpec.VolumeBinds, "/workspace/.pocketcoder_auth")
	secondAuth := findMount(secondDocker.lastCreateSpec.VolumeBinds, "/workspace/.pocketcoder_auth")
	if firstAuth == "" || firstAuth != secondAuth {
		t.Fatalf("auth mounts = %q and %q, want one persistent shared-account Codex volume", firstAuth, secondAuth)
	}
	firstWorkspace := findMount(firstDocker.lastCreateSpec.VolumeBinds, "/workspace")
	secondWorkspace := findMount(secondDocker.lastCreateSpec.VolumeBinds, "/workspace")
	if firstWorkspace == "" || firstWorkspace == secondWorkspace {
		t.Fatalf("workspace mounts = %q and %q, want separate per-user volumes", firstWorkspace, secondWorkspace)
	}
}

func TestProvisionHarnessInstanceFailsClearlyWhenSelectedHarnessHasNoAPIKey(t *testing.T) {
	app := testApp(t)
	userID := testUser(t, app, "test-harness-user-"+uuid.NewString()[:8]+"@example.com").Id
	harness := createTestHarness(t, app, map[string]any{
		"cli_id":          "codex-without-key",
		"container_image": "pocketcoder-harness-codex:1.1.9",
		"launch_template": map[string]any{
			"cmd":          []string{"--cmd", "codex-acp", "--port", "3000"},
			"port":         3000,
			"env_template": map[string]any{"OPENAI_API_KEY": "{{.API_KEY}}"},
		},
	})
	fake := newFakeDockerClient()
	rec, err := ProvisionHarnessInstance(context.Background(), app, fake, harness.Id, "", userID)
	if err != nil {
		t.Fatal(err)
	}
	if rec.GetString("status") != "error" {
		t.Fatalf("status = %q, want error", rec.GetString("status"))
	}
	if got := rec.GetString("last_error"); !strings.Contains(got, "API_KEY") {
		t.Errorf("last_error = %q, want a clear missing API_KEY error", got)
	}
	if fake.createCallCount != 0 {
		t.Error("must not create a container with a placeholder or missing credential")
	}
}

// TestProvisionHarnessInstanceReturnsWinnerRowOnConcurrentSaveRace exercises
// the race two concurrent ProvisionHarnessInstance callers can hit for the
// same (harness, launch_key): both pass the initial FindHarnessInstance
// check before either row exists, so the loser's own Save fails on the
// (user, harness, harness_account, launch_key) unique index
// (idx_harness_instances_pair). Real
// goroutine scheduling can't reliably land both calls in that exact window
// on demand, so this uses a test-only seam (raceHookForTests) to
// deterministically simulate a concurrent winner's row landing in the gap
// between this call's own lookup and its own Save — the same shape of race,
// without relying on timing. The assertion is the one that matters
// regardless of how the race is induced: the loser must return the
// winner's row with a nil error, not a raw save error, and must not
// provision a second container.
func TestProvisionHarnessInstanceReturnsWinnerRowOnConcurrentSaveRace(t *testing.T) {
	app := testApp(t)
	userID := testUser(t, app, "test-harness-user-"+uuid.NewString()[:8]+"@example.com").Id
	harness := createTestHarness(t, app, map[string]any{
		"container_image": "example.com/harness:1.0",
		"launch_template": map[string]any{"cmd": []string{"/adapter"}, "port": 3000},
	})
	fake := newFakeDockerClient()

	var winnerID string
	raceHookForTests = func() {
		// Clear immediately: this itself recurses into
		// ProvisionHarnessInstance to play the role of the concurrent
		// winner, and that inner call must run the real Save path, not
		// trigger this hook again.
		raceHookForTests = nil
		winnerRec, err := ProvisionHarnessInstance(context.Background(), app, fake, harness.Id, "", userID)
		if err != nil {
			t.Fatalf("simulated concurrent winner failed: %v", err)
		}
		winnerID = winnerRec.Id
	}
	t.Cleanup(func() { raceHookForTests = nil })

	rec, err := ProvisionHarnessInstance(context.Background(), app, fake, harness.Id, "", userID)
	if err != nil {
		t.Fatalf("expected the loser of the race to return the winner's row, not an error: %v", err)
	}
	if winnerID == "" {
		t.Fatal("simulated concurrent winner never ran")
	}
	if rec.Id != winnerID {
		t.Errorf("row id = %q, want the concurrent winner's row id %q", rec.Id, winnerID)
	}
	if fake.createCallCount != 1 {
		t.Errorf("expected exactly one Create call (only the winner should provision a container), got %d", fake.createCallCount)
	}
}
