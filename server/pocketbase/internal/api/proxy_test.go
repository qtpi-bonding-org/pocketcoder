package api

import (
	"errors"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"

	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/operation"
)

func TestObservabilityProxyForwardsPathHeadersAndQuery(t *testing.T) {
	var mu sync.Mutex
	var gotPath, gotQuery, gotHost, gotPrefix string
	backend := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		gotPath, gotQuery = r.URL.Path, r.URL.RawQuery
		gotHost, gotPrefix = r.Header.Get("X-Forwarded-Host"), r.Header.Get("X-Forwarded-Prefix")
		mu.Unlock()
		w.WriteHeader(http.StatusCreated)
		_, _ = w.Write([]byte("backend response"))
	}))
	defer backend.Close()

	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()
	user := testUser(t, app, "proxy-admin-"+randomSuffix()+"@example.com")
	user.Set("role", "admin")
	if err := app.Save(user); err != nil {
		t.Fatal(err)
	}
	reg := operation.NewRegistry()
	AddProxyOperations(reg, ProxyDeps{TargetURL: backend.URL})
	token, err := user.NewAuthToken()
	if err != nil {
		t.Fatal(err)
	}
	router, err := apis.NewRouter(app)
	if err != nil {
		t.Fatal(err)
	}
	e := &core.ServeEvent{App: app, Router: router}
	operation.MountForTests(e, reg.Routes())
	req := httptest.NewRequest(http.MethodGet, "/api/pocketcoder/v1/proxy/observability/some/path?x=1&y=two", nil)
	req.Host = "public.example"
	req.Header.Set("Authorization", token)
	mux, err := e.Router.BuildMux()
	if err != nil {
		t.Fatal(err)
	}
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)
	if rec.Code != http.StatusCreated || rec.Body.String() != "backend response" {
		t.Fatalf("status=%d body=%q", rec.Code, rec.Body.String())
	}
	mu.Lock()
	defer mu.Unlock()
	if gotPath != "/some/path" || gotQuery != "x=1&y=two" {
		t.Fatalf("backend path/query = %q?%s", gotPath, gotQuery)
	}
	if gotHost != "public.example" || gotPrefix != "/api/pocketcoder/v1/proxy/observability" {
		t.Fatalf("forwarded headers host=%q prefix=%q", gotHost, gotPrefix)
	}
}

func TestObservabilityProxyUsesInjectedTransport(t *testing.T) {
	called := false
	transport := roundTripFunc(func(*http.Request) (*http.Response, error) {
		called = true
		return nil, errors.New("injected transport failure")
	})
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()
	user := testUser(t, app, "proxy-transport-"+randomSuffix()+"@example.com")
	user.Set("role", "admin")
	if err := app.Save(user); err != nil {
		t.Fatal(err)
	}
	reg := operation.NewRegistry()
	AddProxyOperations(reg, ProxyDeps{TargetURL: "http://backend.invalid", Transport: transport})
	token, err := user.NewAuthToken()
	if err != nil {
		t.Fatal(err)
	}
	router, err := apis.NewRouter(app)
	if err != nil {
		t.Fatal(err)
	}
	e := &core.ServeEvent{App: app, Router: router}
	operation.MountForTests(e, reg.Routes())
	req := httptest.NewRequest(http.MethodGet, "/api/pocketcoder/v1/proxy/observability/test", nil)
	req.Header.Set("Authorization", token)
	mux, err := e.Router.BuildMux()
	if err != nil {
		t.Fatal(err)
	}
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)
	if !called {
		t.Fatal("injected transport was not called")
	}
	// httputil.ReverseProxy's default ErrorHandler logs a RoundTrip error
	// and responds 502 with an empty body -- it does not echo the error
	// text back to the client. Asserting "called" plus the resulting
	// status is the meaningful proof the injected transport was on the
	// request path; asserting on body content would test ReverseProxy's
	// internals, not this handler's behavior.
	if rec.Code != http.StatusBadGateway {
		t.Fatalf("status=%d body=%q", rec.Code, rec.Body.String())
	}
}

func TestMemoryDashboardIsAvailableToAuthenticatedUser(t *testing.T) {
	var gotPath string
	backend := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotPath = r.URL.Path
		w.WriteHeader(http.StatusOK)
	}))
	defer backend.Close()

	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()
	user := testUser(t, app, "proxy-memory-"+randomSuffix()+"@example.com")
	if err := app.Save(user); err != nil {
		t.Fatal(err)
	}
	reg := operation.NewRegistry()
	AddProxyOperations(reg, ProxyDeps{TargetURL: backend.URL})
	token, err := user.NewAuthToken()
	if err != nil {
		t.Fatal(err)
	}
	router, err := apis.NewRouter(app)
	if err != nil {
		t.Fatal(err)
	}
	e := &core.ServeEvent{App: app, Router: router}
	operation.MountForTests(e, reg.Routes())
	req := httptest.NewRequest(http.MethodGet, "/api/pocketcoder/v1/proxy/observability/memory.sql", nil)
	req.Header.Set("Authorization", token)
	mux, err := e.Router.BuildMux()
	if err != nil {
		t.Fatal(err)
	}
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK || gotPath != "/memory.sql" {
		t.Fatalf("status=%d path=%q", rec.Code, gotPath)
	}
}

type roundTripFunc func(*http.Request) (*http.Response, error)

func (f roundTripFunc) RoundTrip(r *http.Request) (*http.Response, error) { return f(r) }

func TestObservabilityProxyDoesNotAcceptPost(t *testing.T) {
	scenario := tests.ApiScenario{
		Name:            "observability proxy is read-only at the HTTP boundary",
		Method:          http.MethodPost,
		URL:             "/api/pocketcoder/v1/proxy/observability/",
		ExpectedStatus:  http.StatusNotFound,
		ExpectedContent: []string{`"status":404`},
		BeforeTestFunc: func(_ testing.TB, _ *tests.TestApp, e *core.ServeEvent) {
			registry := operation.NewRegistry()
			AddProxyOperations(registry, ProxyDeps{})
			operation.MountForTests(e, registry.Routes())
		},
	}
	scenario.Test(t)
}
