package api

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/harnessauth"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/operation"
)

type fakeHarnessAuthRuntime struct {
	start, poll, submit, cancel, disconnect                                         *harnessauth.AttemptState
	startErr, pollErr, submitErr, cancelErr, disconnectErr                          error
	startProvider, pollProvider, submitProvider, cancelProvider, disconnectProvider string
}

func (f *fakeHarnessAuthRuntime) Start(ctx context.Context, provider string, _ harnessauth.AttemptContext) (*harnessauth.AttemptState, error) {
	f.startProvider = provider
	return f.start, f.startErr
}
func (f *fakeHarnessAuthRuntime) Poll(ctx context.Context, provider string, _ harnessauth.AttemptContext) (*harnessauth.AttemptState, error) {
	f.pollProvider = provider
	return f.poll, f.pollErr
}
func (f *fakeHarnessAuthRuntime) Submit(ctx context.Context, provider string, _ harnessauth.AttemptContext, _ string) (*harnessauth.AttemptState, error) {
	f.submitProvider = provider
	return f.submit, f.submitErr
}
func (f *fakeHarnessAuthRuntime) Cancel(ctx context.Context, provider string, _ harnessauth.AttemptContext) (*harnessauth.AttemptState, error) {
	f.cancelProvider = provider
	return f.cancel, f.cancelErr
}
func (f *fakeHarnessAuthRuntime) Disconnect(ctx context.Context, provider string, _ harnessauth.AttemptContext) (*harnessauth.AttemptState, error) {
	f.disconnectProvider = provider
	return f.disconnect, f.disconnectErr
}

func harnessRequest(t *testing.T, app core.App, runtime harnessAuthRuntime, user *core.Record, path, body string) (int, string) {
	t.Helper()
	_, rec := harnessRequestRaw(t, app, runtime, user, path, body)
	b, _ := io.ReadAll(rec.Result().Body)
	return rec.Code, string(b)
}

// harnessRequestRaw is harnessRequest's non-lossy sibling: it hands back the
// real request and recorder so callers (e.g. contract tests) can validate
// the full response, not just its status code and body string.
func harnessRequestRaw(t *testing.T, app core.App, runtime harnessAuthRuntime, user *core.Record, path, body string) (*http.Request, *httptest.ResponseRecorder) {
	t.Helper()
	router, err := apis.NewRouter(app)
	if err != nil {
		t.Fatal(err)
	}
	e := &core.ServeEvent{App: app, Router: router}
	r := operation.NewRegistry()
	AddHarnessAuthOperations(app, r, HarnessAuthDeps{Runtime: runtime})
	operation.MountForTests(e, r.Routes())
	token, err := user.NewAuthToken()
	if err != nil {
		t.Fatal(err)
	}
	req := httptest.NewRequest(http.MethodPost, path, strings.NewReader(body))
	req.Header.Set("Authorization", token)
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	mux, err := e.Router.BuildMux()
	if err != nil {
		t.Fatal(err)
	}
	mux.ServeHTTP(rec, req)
	return req, rec
}

func TestHarnessAuthOperationsRequireProvider(t *testing.T) {
	app := testApp(t)
	user := testUser(t, app, "harness-auth-provider-"+randomSuffix()+"@example.com")
	runtime := &fakeHarnessAuthRuntime{}
	for _, path := range []string{"status", "start", "poll", "submit", "cancel", "disconnect"} {
		code, body := harnessRequest(t, app, runtime, user, "/api/pocketcoder/v1/harness-auth/"+path, `{}`)
		if code != http.StatusBadRequest || !strings.Contains(strings.ToLower(body), "provider") {
			t.Errorf("%s: status=%d body=%q, want 400 mentioning provider", path, code, body)
		}
	}
}

func TestHarnessAuthNoneModeUsesNewContract(t *testing.T) {
	app := testApp(t)
	user := testUser(t, app, "harness-auth-none-"+randomSuffix()+"@example.com")
	harness := createTestHarness(t, app, map[string]any{"container_image": "test/image"})
	providers, err := app.FindCollectionByNameOrId("providers")
	if err != nil {
		t.Fatal(err)
	}
	provider := core.NewRecord(providers)
	provider.Set("provider_id", "test-provider")
	provider.Set("name", "Test Provider")
	if err := app.Save(provider); err != nil {
		t.Fatal(err)
	}
	runtime := &fakeHarnessAuthRuntime{}
	code, body := harnessRequest(t, app, runtime, user, "/api/pocketcoder/v1/harness-auth/start", `{"harness":"`+harness.Id+`","provider":"`+provider.Id+`","mode":"none"}`)
	if code != http.StatusOK {
		t.Fatalf("status=%d body=%s", code, body)
	}
	if strings.Contains(body, "credentialMode") {
		t.Fatalf("old response field in body: %s", body)
	}
}

func TestHarnessAuthOAuthUsesResolvedAuthenticatorAndRejectsUnsupportedPair(t *testing.T) {
	app := testApp(t)
	user := testUser(t, app, "harness-auth-oauth-"+randomSuffix()+"@example.com")
	codex, err := app.FindFirstRecordByFilter("harnesses", "cli_id = 'codex'")
	if err != nil {
		t.Fatal(err)
	}
	openai, err := app.FindFirstRecordByFilter("providers", "provider_id = 'openai'")
	if err != nil {
		t.Fatal(err)
	}
	fake := &fakeHarnessAuthRuntime{start: &harnessauth.AttemptState{Status: harnessauth.AttemptStatusAwaiting}, poll: &harnessauth.AttemptState{Status: harnessauth.AttemptStatusAwaiting}}
	code, body := harnessRequest(t, app, fake, user, "/api/pocketcoder/v1/harness-auth/start", `{"harness":"`+codex.Id+`","provider":"`+openai.Id+`","mode":"oauth"}`)
	if code != http.StatusOK {
		t.Fatalf("codex OAuth start = %d: %s", code, body)
	}
	if fake.startProvider != "codex" {
		t.Fatalf("start dispatch key = %q, want codex", fake.startProvider)
	}
	code, body = harnessRequest(t, app, fake, user, "/api/pocketcoder/v1/harness-auth/poll", `{"harness":"`+codex.Id+`","provider":"`+openai.Id+`"}`)
	if code != http.StatusOK {
		t.Fatalf("codex OAuth poll = %d: %s", code, body)
	}
	if fake.pollProvider != "codex" {
		t.Fatalf("poll dispatch key = %q, want codex", fake.pollProvider)
	}

	goose, err := app.FindFirstRecordByFilter("harnesses", "cli_id = 'goose'")
	if err != nil {
		t.Fatal(err)
	}
	anthropic, err := app.FindFirstRecordByFilter("providers", "provider_id = 'anthropic'")
	if err != nil {
		t.Fatal(err)
	}
	code, body = harnessRequest(t, app, fake, user, "/api/pocketcoder/v1/harness-auth/start", `{"harness":"`+goose.Id+`","provider":"`+anthropic.Id+`","mode":"oauth"}`)
	if code < 400 || code >= 500 || !strings.Contains(body, "does not support account login for this harness") {
		t.Fatalf("unsupported Goose OAuth = %d: %s", code, body)
	}
}

func TestHarnessAuthPublishesStructuredChallenge(t *testing.T) {
	app := testApp(t)
	user := testUser(t, app, "harness-auth-structured-"+randomSuffix()+"@example.com")
	harness, err := app.FindFirstRecordByFilter("harnesses", "cli_id = 'codex'")
	if err != nil {
		t.Fatal(err)
	}
	provider, err := app.FindFirstRecordByFilter("providers", "provider_id = 'openai'")
	if err != nil {
		t.Fatal(err)
	}
	fake := &fakeHarnessAuthRuntime{start: &harnessauth.AttemptState{Status: harnessauth.AttemptStatusAwaiting, Challenge: &harnessauth.Challenge{Type: "device-code", Text: "Enter this code: 9OCA-MITN8", Kind: "device_code", VerificationURI: "https://auth.openai.com/codex/device", UserCode: "9OCA-MITN8", CodeDestination: "browser", PollIntervalSeconds: 4}}}
	code, body := harnessRequest(t, app, fake, user, "/api/pocketcoder/v1/harness-auth/start", `{"harness":"`+harness.Id+`","provider":"`+provider.Id+`","mode":"oauth"}`)
	if code != http.StatusOK {
		t.Fatalf("status=%d body=%s", code, body)
	}
	var response map[string]any
	if err := json.Unmarshal([]byte(body), &response); err != nil {
		t.Fatal(err)
	}
	challenge := response["challenge"].(map[string]any)
	for key, want := range map[string]any{"kind": "device_code", "verificationUri": "https://auth.openai.com/codex/device", "userCode": "9OCA-MITN8", "codeDestination": "browser", "pollIntervalSeconds": float64(4)} {
		if challenge[key] != want {
			t.Errorf("challenge[%q]=%v, want %v", key, challenge[key], want)
		}
	}

	claudeHarness, err := app.FindFirstRecordByFilter("harnesses", "cli_id = 'claude-code'")
	if err != nil {
		t.Fatal(err)
	}
	claudeProvider, err := app.FindFirstRecordByFilter("providers", "provider_id = 'anthropic'")
	if err != nil {
		t.Fatal(err)
	}
	fake.start = &harnessauth.AttemptState{Status: harnessauth.AttemptStatusAwaiting, Challenge: &harnessauth.Challenge{
		Type: "browser-code", Text: "Open the authorization URL", Kind: "browser_code",
		VerificationURI: "https://example.test/authorize", CodeDestination: "app", PollIntervalSeconds: 4,
	}}
	code, body = harnessRequest(t, app, fake, user, "/api/pocketcoder/v1/harness-auth/start", `{"harness":"`+claudeHarness.Id+`","provider":"`+claudeProvider.Id+`","mode":"oauth"}`)
	if code != http.StatusOK {
		t.Fatalf("Claude status=%d body=%s", code, body)
	}
	if !strings.Contains(body, `"codeDestination":"app"`) {
		t.Fatalf("Claude challenge missing app destination: %s", body)
	}
}
