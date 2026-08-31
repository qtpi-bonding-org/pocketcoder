package api

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/dockerapi"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/ollama"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/operation"
)

type fakeOllamaDocker struct {
	inspect    dockerapi.ContainerInspect
	inspectErr error
	running    bool
	created    dockerapi.CreateSpec
	started    []string
	removed    []string
}

func (f *fakeOllamaDocker) Inspect(context.Context, string) (dockerapi.ContainerInspect, error) {
	f.inspect.State.Running = f.running
	return f.inspect, f.inspectErr
}

func (f *fakeOllamaDocker) ImageExists(context.Context, string) (bool, error) { return false, nil }

func (f *fakeOllamaDocker) PullImage(context.Context, string) error { return nil }

func (f *fakeOllamaDocker) LoadImage(_ context.Context, archive io.Reader) error {
	_, err := io.Copy(io.Discard, archive)
	return err
}

func (f *fakeOllamaDocker) Create(_ context.Context, _ string, spec dockerapi.CreateSpec) (string, error) {
	f.created = spec
	return "ollama-id", nil
}

func (f *fakeOllamaDocker) Start(_ context.Context, name string) error {
	f.started = append(f.started, name)
	return nil
}

func (f *fakeOllamaDocker) Remove(_ context.Context, name string) error {
	f.removed = append(f.removed, name)
	return nil
}

func mountOllamaRequest(t *testing.T, app *tests.TestApp, reg *operation.Registry, method, path, body string, user *core.Record) *httptest.ResponseRecorder {
	t.Helper()
	router, err := apis.NewRouter(app)
	if err != nil {
		t.Fatal(err)
	}
	e := &core.ServeEvent{App: app, Router: router}
	operation.MountForTests(e, reg.Routes())
	req := httptest.NewRequest(method, path, strings.NewReader(body))
	if user != nil {
		token, err := user.NewAuthToken()
		if err != nil {
			t.Fatal(err)
		}
		req.Header.Set("Authorization", token)
	}
	req.Header.Set("Content-Type", "application/json")
	mux, err := e.Router.BuildMux()
	if err != nil {
		t.Fatal(err)
	}
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)
	return rec
}

func TestListOllamaModelsAuthorizationBoundary(t *testing.T) {
	backend := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"models":[]}`))
	}))
	defer backend.Close()

	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()
	reg := operation.NewRegistry()
	AddOllamaOperations(reg, OllamaDeps{HTTP: backend.Client(), Config: ollama.Config{BaseURL: backend.URL}})

	user := testUser(t, app, "ollama-user-"+randomSuffix()+"@example.com")
	admin := newOllamaAdmin(t, app)
	cases := []struct {
		name string
		user *core.Record
		want int
	}{
		{name: "unauthenticated", want: http.StatusUnauthorized},
		{name: "authenticated non-admin", user: user, want: http.StatusForbidden},
		{name: "authenticated admin", user: admin, want: http.StatusOK},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			rec := mountOllamaRequest(t, app, reg, http.MethodGet, "/api/pocketcoder/v1/ollama/models", "", tc.user)
			if rec.Code != tc.want {
				t.Fatalf("status=%d body=%s, want %d", rec.Code, rec.Body, tc.want)
			}
		})
	}
}

func newOllamaAdmin(t *testing.T, app *tests.TestApp) *core.Record {
	u := testUser(t, app, "ollama-admin-"+randomSuffix()+"@example.com")
	u.Set("role", "admin")
	if err := app.Save(u); err != nil {
		t.Fatal(err)
	}
	return u
}
func TestListOllamaModelsHTTPAvailable(t *testing.T) {
	backend := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/tags" {
			t.Errorf("path=%q", r.URL.Path)
		}
		_, _ = w.Write([]byte(`{"models":[{"name":"qwen3:0.6b","size":42}]}`))
	}))
	defer backend.Close()
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()
	reg := operation.NewRegistry()
	AddOllamaOperations(reg, OllamaDeps{HTTP: backend.Client(), Config: ollama.Config{BaseURL: backend.URL}})
	rec := mountOllamaRequest(t, app, reg, http.MethodGet, "/api/pocketcoder/v1/ollama/models", "", newOllamaAdmin(t, app))
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), `"enabled":true`) || !strings.Contains(rec.Body.String(), "qwen3:0.6b") {
		t.Fatalf("status=%d body=%s", rec.Code, rec.Body)
	}
}
func TestListOllamaModelsHTTPUnavailableDegradesGracefully(t *testing.T) {
	backend := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { http.Error(w, "down", http.StatusBadGateway) }))
	url := backend.URL
	backend.Close()
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()
	reg := operation.NewRegistry()
	AddOllamaOperations(reg, OllamaDeps{HTTP: &http.Client{}, Config: ollama.Config{BaseURL: url}})
	rec := mountOllamaRequest(t, app, reg, http.MethodGet, "/api/pocketcoder/v1/ollama/models", "", newOllamaAdmin(t, app))
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), `"enabled":false`) || !strings.Contains(rec.Body.String(), `"models":[]`) {
		t.Fatalf("status=%d body=%s", rec.Code, rec.Body)
	}
}
func TestPullOllamaModelHTTPInvalidName(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()
	reg := operation.NewRegistry()
	AddOllamaOperations(reg, OllamaDeps{Docker: &fakeOllamaDocker{}, Config: ollama.Config{BaseURL: "http://unused"}})
	rec := mountOllamaRequest(t, app, reg, http.MethodPost, "/api/pocketcoder/v1/ollama/pull", `{"model":"bad model"}`, newOllamaAdmin(t, app))
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status=%d", rec.Code)
	}
}
func TestPullOllamaModelHTTPStreamsNDJSON(t *testing.T) {
	backend := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/api/tags" {
			_, _ = w.Write([]byte(`{"models":[]}`))
			return
		}
		_, _ = w.Write([]byte("{\"status\":\"pulling\"}\n{\"status\":\"success\"}\n"))
	}))
	defer backend.Close()
	docker := &fakeOllamaDocker{running: true}
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()
	reg := operation.NewRegistry()
	AddOllamaOperations(reg, OllamaDeps{Docker: docker, HTTP: backend.Client(), StreamHTTP: backend.Client(), Config: ollama.Config{BaseURL: backend.URL, Release: "development"}})
	rec := mountOllamaRequest(t, app, reg, http.MethodPost, "/api/pocketcoder/v1/ollama/pull", `{"model":"qwen3:0.6b"}`, newOllamaAdmin(t, app))
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), "pulling") || !strings.Contains(rec.Body.String(), "success") {
		t.Fatalf("status=%d body=%s", rec.Code, rec.Body)
	}
}
func TestPullOllamaModelHTTPRuntimeUnavailable(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()
	reg := operation.NewRegistry()
	AddOllamaOperations(reg, OllamaDeps{Docker: &fakeOllamaDocker{inspectErr: dockerapi.ErrContainerNotFound}, Config: ollama.Config{BaseURL: "http://unused"}})
	rec := mountOllamaRequest(t, app, reg, http.MethodPost, "/api/pocketcoder/v1/ollama/pull", `{"model":"qwen3:0.6b"}`, newOllamaAdmin(t, app))
	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("status=%d", rec.Code)
	}
}
func TestPullOllamaModelHTTPReleaseRuntimeUsesAcquirePath(t *testing.T) {
	docker := &fakeOllamaDocker{inspectErr: dockerapi.ErrContainerNotFound}
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()
	reg := operation.NewRegistry()
	AddOllamaOperations(reg, OllamaDeps{Docker: docker, Config: ollama.Config{BaseURL: "http://unused", Release: "0123456789abcdef0123456789abcdef01234567"}})
	rec := mountOllamaRequest(t, app, reg, http.MethodPost, "/api/pocketcoder/v1/ollama/pull", `{"model":"qwen3:0.6b"}`, newOllamaAdmin(t, app))
	if rec.Code != http.StatusServiceUnavailable || docker.created.Image != "" {
		t.Fatalf("status=%d created=%q", rec.Code, docker.created.Image)
	}
}
