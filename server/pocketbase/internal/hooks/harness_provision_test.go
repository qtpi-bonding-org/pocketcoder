package hooks

import (
	"context"
	"fmt"
	"strings"
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

func TestProvisionGooseUsesPerUserStateVolume(t *testing.T) {
	app := testApp(t)
	userID := testUser(t, app, "test-goose-user-"+uuid.NewString()[:8]+"@example.com").Id
	harness, err := app.FindFirstRecordByFilter("harnesses", "cli_id = 'goose'", nil)
	if err != nil {
		t.Fatal(err)
	}
	fake := newFakeDockerClient()
	if _, err := ProvisionHarnessInstance(context.Background(), app, fake, harness.Id, "", userID); err != nil {
		t.Fatal(err)
	}
	foundGooseState := false
	for _, bind := range fake.lastCreateSpec.VolumeBinds {
		if strings.HasSuffix(bind, ":/goose") {
			foundGooseState = true
		}
	}
	if !foundGooseState {
		t.Fatalf("Goose volume binds = %v, want a per-user /goose state mount", fake.lastCreateSpec.VolumeBinds)
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
	if got := fake.lastCreateSpec.Env; len(got) != 1 || got[0] != "OPENAI_API_KEY=codex-key" {
		t.Errorf("Env = %v, want only the selected Codex harness's API key", got)
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
