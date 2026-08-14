package api

import (
	"context"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/harnessaccount"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/harnessauth"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/operation"
)

type fakeHarnessAuthRuntime struct {
	start, poll, submit, cancel, disconnect                *harnessauth.AttemptState
	startErr, pollErr, submitErr, cancelErr, disconnectErr error
	calls                                                  []string
	contexts                                               []context.Context
}

func (f *fakeHarnessAuthRuntime) call(name string, ctx context.Context) {
	f.calls = append(f.calls, name)
	f.contexts = append(f.contexts, ctx)
}
func (f *fakeHarnessAuthRuntime) Start(ctx context.Context, _ string, _ harnessauth.AttemptContext) (*harnessauth.AttemptState, error) {
	f.call("start", ctx)
	return f.start, f.startErr
}
func (f *fakeHarnessAuthRuntime) Poll(ctx context.Context, _ string, _ harnessauth.AttemptContext) (*harnessauth.AttemptState, error) {
	f.call("poll", ctx)
	return f.poll, f.pollErr
}
func (f *fakeHarnessAuthRuntime) Submit(ctx context.Context, _ string, _ harnessauth.AttemptContext, _ string) (*harnessauth.AttemptState, error) {
	f.call("submit", ctx)
	return f.submit, f.submitErr
}
func (f *fakeHarnessAuthRuntime) Cancel(ctx context.Context, _ string, _ harnessauth.AttemptContext) (*harnessauth.AttemptState, error) {
	f.call("cancel", ctx)
	return f.cancel, f.cancelErr
}
func (f *fakeHarnessAuthRuntime) Disconnect(ctx context.Context, _ string, _ harnessauth.AttemptContext) (*harnessauth.AttemptState, error) {
	f.call("disconnect", ctx)
	return f.disconnect, f.disconnectErr
}

// harnessRequestContextProbeKey is set on the outgoing request's context so
// tests can prove a handler threaded re.Request.Context() through to the
// runtime, rather than calling context.Background() directly. Comparing
// contexts by == is unreliable here: httptest.NewRequest's context is the
// context.Background() singleton, so an accidental context.Background()
// call in the handler would be indistinguishable from a correctly threaded
// but otherwise-untouched request context.
type harnessRequestContextProbeKey struct{}

func harnessRequest(t *testing.T, app core.App, runtime harnessAuthRuntime, user *core.Record, method, path, body string) (int, string) {
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
	req := httptest.NewRequest(method, path, strings.NewReader(body))
	req = req.WithContext(context.WithValue(req.Context(), harnessRequestContextProbeKey{}, true))
	req.Header.Set("Authorization", token)
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	mux, err := e.Router.BuildMux()
	if err != nil {
		t.Fatal(err)
	}
	mux.ServeHTTP(rec, req)
	b, _ := io.ReadAll(rec.Result().Body)
	return rec.Code, string(b)
}

func TestHarnessAuthInjectedModesAndLifecycle(t *testing.T) {
	app := testApp(t)
	user := testUser(t, app, "harness-auth-"+randomSuffix()+"@example.com")
	harness := createTestHarness(t, app, map[string]any{"container_image": "test/image", "cli_id": "claude"})
	fake := &fakeHarnessAuthRuntime{
		start:      &harnessauth.AttemptState{Status: harnessauth.AttemptStatusAwaiting},
		poll:       &harnessauth.AttemptState{Status: harnessauth.AttemptStatusAwaiting},
		submit:     &harnessauth.AttemptState{Status: harnessauth.AttemptStatusAwaiting},
		cancel:     &harnessauth.AttemptState{Status: harnessauth.AttemptStatusCancelled},
		disconnect: &harnessauth.AttemptState{Status: harnessauth.AttemptStatusCancelled},
	}
	code, _ := harnessRequest(t, app, fake, user, http.MethodPost, "/api/pocketcoder/v1/harness-auth/start", `{"harness":"`+harness.Id+`","credentialMode":"none"}`)
	if code != http.StatusOK || len(fake.calls) != 0 {
		t.Fatalf("none mode = %d, calls=%v", code, fake.calls)
	}
	code, _ = harnessRequest(t, app, fake, user, http.MethodPost, "/api/pocketcoder/v1/harness-auth/start", `{"harness":"`+harness.Id+`","credentialMode":"account","provider":"claude"}`)
	if code != http.StatusOK {
		t.Fatalf("account start = %d", code)
	}
	// API-key mode is entirely local: a missing key reports the required
	// credential, while a key owned by the user connects the account.
	code, _ = harnessRequest(t, app, fake, user, http.MethodPost, "/api/pocketcoder/v1/harness-auth/start", `{"harness":"`+harness.Id+`","credentialMode":"api_key"}`)
	if code != http.StatusOK {
		t.Fatalf("api-key mode without key = %d", code)
	}
	keys, err := app.FindCollectionByNameOrId("provider_keys")
	if err != nil {
		t.Fatal(err)
	}
	key := core.NewRecord(keys)
	key.Set("user", user.Id)
	key.Set("provider", "claude")
	key.Set("env_vars", map[string]string{"ANTHROPIC_API_KEY": "test"})
	if err := app.Save(key); err != nil {
		t.Fatal(err)
	}
	code, _ = harnessRequest(t, app, fake, user, http.MethodPost, "/api/pocketcoder/v1/harness-auth/start", `{"harness":"`+harness.Id+`","credentialMode":"api_key","providerKey":"`+key.Id+`"}`)
	if code != http.StatusOK {
		t.Fatalf("api-key mode with key = %d", code)
	}
	fake.submitErr = errors.New("submit failed")
	code, _ = harnessRequest(t, app, fake, user, http.MethodPost, "/api/pocketcoder/v1/harness-auth/submit", `{"harness":"`+harness.Id+`","code":"1234"}`)
	if code != http.StatusBadGateway {
		t.Fatalf("failed submit = %d", code)
	}
	fake.submitErr = nil
	for _, tc := range []struct {
		path, body string
		want       string
	}{
		{"poll", `{"harness":"` + harness.Id + `"}`, "poll"},
		{"submit", `{"harness":"` + harness.Id + `","code":"1234"}`, "submit"},
		{"cancel", `{"harness":"` + harness.Id + `"}`, "cancel"},
		{"disconnect", `{"harness":"` + harness.Id + `"}`, "disconnect"},
	} {
		code, _ = harnessRequest(t, app, fake, user, http.MethodPost, "/api/pocketcoder/v1/harness-auth/"+tc.path, tc.body)
		if code != http.StatusOK {
			t.Errorf("%s = %d", tc.path, code)
		}
	}
	if len(fake.contexts) == 0 || fake.contexts[0].Value(harnessRequestContextProbeKey{}) != true {
		t.Error("runtime was not given the request context (missing context probe value)")
	}
	// A disconnect with no prior attempt still clears the account locally and
	// must not invoke the external runtime.
	otherHarness := createTestHarness(t, app, map[string]any{"container_image": "test/image"})
	before := len(fake.calls)
	code, _ = harnessRequest(t, app, fake, user, http.MethodPost, "/api/pocketcoder/v1/harness-auth/start", `{"harness":"`+otherHarness.Id+`","credentialMode":"none"}`)
	if code != http.StatusOK {
		t.Fatalf("second account setup = %d", code)
	}
	code, _ = harnessRequest(t, app, fake, user, http.MethodPost, "/api/pocketcoder/v1/harness-auth/disconnect", `{"harness":"`+otherHarness.Id+`"}`)
	if code != http.StatusOK || len(fake.calls) != before {
		t.Fatalf("disconnect without attempt = %d, calls=%v", code, fake.calls)
	}
}

func TestHarnessAuthFailuresAndOwnership(t *testing.T) {
	app := testApp(t)
	owner := testUser(t, app, "harness-owner-"+randomSuffix()+"@example.com")
	other := testUser(t, app, "harness-other-"+randomSuffix()+"@example.com")
	harness := createTestHarness(t, app, map[string]any{"container_image": "test/image"})
	fake := &fakeHarnessAuthRuntime{startErr: errors.New("failed")}
	code, _ := harnessRequest(t, app, fake, owner, http.MethodPost, "/api/pocketcoder/v1/harness-auth/start", `{"harness":"`+harness.Id+`","credentialMode":"account","provider":"claude"}`)
	if code != http.StatusBadGateway {
		t.Fatalf("failed start = %d", code)
	}
	account, err := harnessaccount.Resolve(app, owner.Id, harness.Id, "")
	if err != nil || account == nil || account.GetString("status") != accountStatusError {
		t.Fatalf("failed start account = %v", account)
	}
	// Create a live attempt, then exercise expired and absent-attempt responses.
	fake.startErr = nil
	fake.start = &harnessauth.AttemptState{Status: harnessauth.AttemptStatusAwaiting}
	code, _ = harnessRequest(t, app, fake, owner, http.MethodPost, "/api/pocketcoder/v1/harness-auth/start", `{"harness":"`+harness.Id+`","credentialMode":"account","provider":"claude"}`)
	if code != http.StatusOK {
		t.Fatalf("setup attempt = %d", code)
	}
	fake.pollErr = harnessauth.ErrAttemptExpired
	code, _ = harnessRequest(t, app, fake, owner, http.MethodPost, "/api/pocketcoder/v1/harness-auth/poll", `{"harness":"`+harness.Id+`"}`)
	if code != http.StatusGone {
		t.Fatalf("expired poll = %d", code)
	}
	fake.pollErr = nil
	code, _ = harnessRequest(t, app, fake, owner, http.MethodPost, "/api/pocketcoder/v1/harness-auth/poll", `{"harness":"`+harness.Id+`"}`)
	if code != http.StatusNotFound {
		t.Fatalf("poll without active attempt = %d", code)
	}
	account, err = harnessaccount.Resolve(app, owner.Id, harness.Id, "")
	if err != nil || account == nil {
		t.Fatalf("resolve created account: %v", err)
	}
	// Deployment accounts are visible to another user, but mutation still
	// requires the account owner.
	account.Set("visibility", harnessaccount.VisibilityDeployment)
	if err := app.Save(account); err != nil {
		t.Fatal(err)
	}
	code, _ = harnessRequest(t, app, fake, other, http.MethodPost, "/api/pocketcoder/v1/harness-auth/start", `{"harness":"`+harness.Id+`","accountId":"`+account.Id+`","credentialMode":"none"}`)
	if code != http.StatusForbidden {
		t.Fatalf("foreign account = %d", code)
	}
}

func TestHarnessAuthAttemptStatusMapping(t *testing.T) {
	tests := map[string]string{
		harnessauth.AttemptStatusStarting:  accountStatusConnecting,
		harnessauth.AttemptStatusAwaiting:  accountStatusConnecting,
		harnessauth.AttemptStatusSucceeded: accountStatusConnected,
		harnessauth.AttemptStatusCancelled: accountStatusDisconnected,
		harnessauth.AttemptStatusFailed:    accountStatusError,
		harnessauth.AttemptStatusExpired:   accountStatusError,
	}
	for attempt, want := range tests {
		if got := statusForAttempt(attempt); got != want {
			t.Errorf("statusForAttempt(%q) = %q, want %q", attempt, got, want)
		}
	}
}
