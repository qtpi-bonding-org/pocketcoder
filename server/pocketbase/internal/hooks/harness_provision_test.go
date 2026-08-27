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

// createProviderAPIKey inserts a provider_api_keys row for a user and provider.
func createProviderAPIKey(t *testing.T, app core.App, userID, providerRecordID, key string) *core.Record {
	t.Helper()
	coll, err := app.FindCollectionByNameOrId("provider_api_keys")
	if err != nil {
		t.Fatal(err)
	}
	rec := core.NewRecord(coll)
	rec.Set("owner", userID)
	rec.Set("provider", providerRecordID)
	rec.Set("api_key", key)
	if err := app.Save(rec); err != nil {
		t.Fatal(err)
	}
	return rec
}

// fakeDockerClient is a dockerProvisioner test double that records
// PullImage/Create/Start calls instead of talking to a real Docker socket.
func TestRenderEnvSelfScopedHarnessOnlyInjectsItsPinnedProvider(t *testing.T) {
	app := testApp(t)
	userID := testUser(t, app, "self-scoped-"+uuid.NewString()[:8]+"@example.com").Id

	openai, err := app.FindFirstRecordByFilter("providers", "provider_id = 'openai'", nil)
	if err != nil {
		t.Fatal(err)
	}
	anthropic, err := app.FindFirstRecordByFilter("providers", "provider_id = 'anthropic'", nil)
	if err != nil {
		t.Fatal(err)
	}
	createProviderAPIKey(t, app, userID, openai.Id, "sk-openai-key")
	createProviderAPIKey(t, app, userID, anthropic.Id, "sk-anthropic-key")

	codex, err := app.FindFirstRecordByFilter("harnesses", "cli_id = 'codex'", nil)
	if err != nil {
		t.Fatal(err)
	}
	if codex.GetBool("supports_live_config") {
		t.Fatal("test assumption broken: codex must be supports_live_config = false")
	}
	fake := newFakeDockerClient()
	rec, err := ProvisionHarnessInstance(context.Background(), app, fake, codex.Id, "", userID)
	if err != nil {
		t.Fatal(err)
	}
	if status := rec.GetString("status"); status == "error" {
		t.Fatalf("codex provisioning failed: %s", rec.GetString("last_error"))
	}
	if !containsString(fake.lastCreateSpec.Env, "OPENAI_API_KEY=sk-openai-key") {
		t.Errorf("codex env = %v, want OPENAI_API_KEY=sk-openai-key", fake.lastCreateSpec.Env)
	}
	if containsString(fake.lastCreateSpec.Env, "sk-anthropic-key") {
		t.Errorf("codex env = %v, anthropic key must not appear -- codex is pinned to openai only", fake.lastCreateSpec.Env)
	}
}

func TestRenderEnvLiveConfigHarnessInjectsEveryCredentialedProviderRegardlessOfProviderFanout(t *testing.T) {
	app := testApp(t)
	userID := testUser(t, app, "live-config-"+uuid.NewString()[:8]+"@example.com").Id

	openai, err := app.FindFirstRecordByFilter("providers", "provider_id = 'openai'", nil)
	if err != nil {
		t.Fatal(err)
	}
	anthropic, err := app.FindFirstRecordByFilter("providers", "provider_id = 'anthropic'", nil)
	if err != nil {
		t.Fatal(err)
	}
	createProviderAPIKey(t, app, userID, openai.Id, "sk-openai-key")
	createProviderAPIKey(t, app, userID, anthropic.Id, "sk-anthropic-key")

	goose, err := app.FindFirstRecordByFilter("harnesses", "cli_id = 'goose'", nil)
	if err != nil {
		t.Fatal(err)
	}
	if !goose.GetBool("supports_live_config") {
		t.Fatal("test assumption broken: goose must be supports_live_config = true")
	}
	// Deliberately DIVERGE provider_fanout from supports_live_config: seeded
	// Goose has both true, which would let an implementation that still
	// (incorrectly) branches on provider_fanout pass this test by accident.
	// Forcing provider_fanout=false here, while supports_live_config stays
	// true, means only a correct supports_live_config-based implementation
	// injects both keys.
	goose.Set("provider_fanout", false)
	if err := app.Save(goose); err != nil {
		t.Fatal(err)
	}
	// Seed harness_providers edges directly rather than running
	// modelcatalog.Sync -- Sync's own edge-creation branches on
	// provider_fanout too (Task 4), and this test just set it false to
	// isolate renderEnv's branching from modelcatalog's. This test only
	// needs the edges to exist, not real synced models.
	harnessProvidersColl, err := app.FindCollectionByNameOrId("harness_providers")
	if err != nil {
		t.Fatal(err)
	}
	for _, p := range []*core.Record{openai, anthropic} {
		edge := core.NewRecord(harnessProvidersColl)
		edge.Set("harness", goose.Id)
		edge.Set("provider", p.Id)
		if err := app.Save(edge); err != nil {
			t.Fatal(err)
		}
	}
	fake := newFakeDockerClient()
	rec, err := ProvisionHarnessInstance(context.Background(), app, fake, goose.Id, "", userID)
	if err != nil {
		t.Fatal(err)
	}
	if status := rec.GetString("status"); status == "error" {
		t.Fatalf("goose provisioning failed: %s", rec.GetString("last_error"))
	}
	if !containsString(fake.lastCreateSpec.Env, "OPENAI_API_KEY=sk-openai-key") {
		t.Errorf("goose env = %v, want OPENAI_API_KEY=sk-openai-key", fake.lastCreateSpec.Env)
	}
	if !containsString(fake.lastCreateSpec.Env, "ANTHROPIC_API_KEY=sk-anthropic-key") {
		t.Errorf("goose env = %v, want ANTHROPIC_API_KEY=sk-anthropic-key -- a live-config/fan-out harness must inject every credentialed provider, not just one", fake.lastCreateSpec.Env)
	}
}

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
	// Goose's env_template has no per-key entry at all (renderEnv derives
	// the right <PROVIDER>_API_KEY name at runtime instead -- see
	// TestProvisionGooseAcceptsTheGenericAPIKeyTheClientActuallyWrites), so
	// no provider_api_keys row is even required for provisioning to succeed;
	// this test only exercises volume/network shape, not credentials.
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

func containsString(values []string, want string) bool {
	for _, value := range values {
		if value == want {
			return true
		}
	}
	return false
}

// TestProvisionHarnessInstanceReturnsWinnerRowOnConcurrentSaveRace exercises
// the race two concurrent ProvisionHarnessInstance callers can hit for the
// same (harness, launch_key): both pass the initial FindHarnessInstance
// check before either row exists, so the loser's own Save fails on the
// (user, harness, oauth_account, launch_key) unique index
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
