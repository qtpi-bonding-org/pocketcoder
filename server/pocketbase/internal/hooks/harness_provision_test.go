package hooks

import (
	"context"
	"fmt"
	"testing"

	"github.com/google/uuid"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/dockerapi"
	_ "github.com/qtpi-automaton/pocketcoder/backend/pb_migrations"
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
				{Destination: "/workspace", Name: "proj_goose_workspace"},
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
	if vol != "proj_goose_workspace" {
		t.Errorf("volume = %q, want proj_goose_workspace", vol)
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

// createTestProviderKey inserts a provider_keys row (with a fresh owning
// user, since `user` is required) with sane defaults, overridden by
// whatever fields the caller supplies.
func createTestProviderKey(t *testing.T, app core.App, overrides map[string]any) *core.Record {
	t.Helper()
	users, err := app.FindCollectionByNameOrId("_pb_users_auth_")
	if err != nil {
		t.Fatal(err)
	}
	user := core.NewRecord(users)
	user.SetEmail(fmt.Sprintf("test-provider-key-%s@example.com", uuid.NewString()[:8]))
	user.SetPassword("password12345")
	if err := app.Save(user); err != nil {
		t.Fatal(err)
	}

	coll, err := app.FindCollectionByNameOrId("provider_keys")
	if err != nil {
		t.Fatal(err)
	}
	rec := core.NewRecord(coll)
	rec.Set("user", user.Id)
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
	pullErr   error
	createErr error
	startErr  error

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
	insp := dockerapi.ContainerInspect{
		Mounts: []dockerapi.Mount{{Destination: "/workspace", Name: "test_goose_workspace"}},
	}
	insp.NetworkSettings.Networks = map[string]dockerapi.NetworkEndpoint{
		"test_pocketcoder-agent": {},
	}
	return insp, nil
}

func (f *fakeDockerClient) PullImage(ctx context.Context, image string) error {
	if f.pullErr != nil {
		return f.pullErr
	}
	f.pulledImages = append(f.pulledImages, image)
	return nil
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
	harness := createTestHarness(t, app, map[string]any{
		"container_image": "example.com/harness:1.0",
		"launch_template": map[string]any{"cmd": []string{"/adapter"}, "port": 3000},
	})
	fake := newFakeDockerClient() // records Create/Start/PullImage calls; add to a shared test-doubles file in this package
	rec, err := ProvisionHarnessInstance(context.Background(), app, fake, harness.Id, "")
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

func TestProvisionHarnessInstanceIsIdempotent(t *testing.T) {
	// Deliberately exercises launchKey = "" (the supports_live_config = true
	// case, i.e. Goose-shaped harnesses) — this is the exact case a naive
	// `"harness = {:h} && launch_key = {:k}"` filter fails to match on the
	// second call, per the finding above. A regression here means the fix
	// didn't take.
	app := testApp(t)
	harness := createTestHarness(t, app, map[string]any{"container_image": "x", "launch_template": map[string]any{"cmd": []string{"/adapter"}}})
	fake := newFakeDockerClient()
	rec1, err := ProvisionHarnessInstance(context.Background(), app, fake, harness.Id, "")
	if err != nil {
		t.Fatal(err)
	}
	rec2, err := ProvisionHarnessInstance(context.Background(), app, fake, harness.Id, "")
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
	harness := createTestHarness(t, app, map[string]any{"container_image": "nonexistent:latest", "launch_template": map[string]any{"cmd": []string{"/adapter"}, "port": 3000}})
	fake := newFakeDockerClient()
	fake.pullErr = fmt.Errorf("No such image")
	rec, err := ProvisionHarnessInstance(context.Background(), app, fake, harness.Id, "")
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
	harness := createTestHarness(t, app, map[string]any{"container_image": "x", "launch_template": map[string]any{"cmd": []string{"/adapter"}}}) // no "port"
	fake := newFakeDockerClient()
	rec, err := ProvisionHarnessInstance(context.Background(), app, fake, harness.Id, "")
	if err != nil {
		t.Fatal(err)
	}
	if rec.GetString("status") != "error" {
		t.Errorf("status = %q, want error — a launch_template with no port must not silently produce ws://host:0/acp", rec.GetString("status"))
	}
}

func TestProvisionHarnessInstanceRendersProviderKeysAndMintsSecret(t *testing.T) {
	app := testApp(t)
	createTestProviderKey(t, app, map[string]any{"provider": "anthropic", "env_vars": map[string]any{"ANTHROPIC_API_KEY": "sk-test-123"}})
	harness := createTestHarness(t, app, map[string]any{
		"container_image": "example.com/harness:1.0",
		"launch_template": map[string]any{
			"cmd":  []string{"/adapter"},
			"port": 3000,
			"env_template": map[string]any{
				"ANTHROPIC_API_KEY": "{{.ANTHROPIC_API_KEY}}",
				"ADAPTER_SECRET":    "{{.__adapter_secret}}",
			},
		},
	})
	fake := newFakeDockerClient()
	rec, err := ProvisionHarnessInstance(context.Background(), app, fake, harness.Id, "")
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

// TestProvisionHarnessInstanceReturnsWinnerRowOnConcurrentSaveRace exercises
// the race two concurrent ProvisionHarnessInstance callers can hit for the
// same (harness, launch_key): both pass the initial findHarnessInstance
// check before either row exists, so the loser's own Save fails on the
// (harness, launch_key) unique index (idx_harness_instances_pair). Real
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
		winnerRec, err := ProvisionHarnessInstance(context.Background(), app, fake, harness.Id, "")
		if err != nil {
			t.Fatalf("simulated concurrent winner failed: %v", err)
		}
		winnerID = winnerRec.Id
	}
	t.Cleanup(func() { raceHookForTests = nil })

	rec, err := ProvisionHarnessInstance(context.Background(), app, fake, harness.Id, "")
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
