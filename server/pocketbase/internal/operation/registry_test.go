package operation

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
)

func testAction(*core.RequestEvent) error { return nil }

func mustPanic(t *testing.T, fn func()) {
	t.Helper()
	panicked := false
	func() {
		defer func() {
			if recover() != nil {
				panicked = true
			}
		}()
		fn()
	}()
	if !panicked {
		t.Fatal("expected panic")
	}
}

func TestRegistryAddGetRoutes(t *testing.T) {
	r := NewRegistry()
	route := Route{OperationID: "one", Method: http.MethodGet, Path: "/one", Action: testAction}
	r.Add(route)
	got, ok := r.Get("one")
	if !ok || got.OperationID != route.OperationID || got.Path != route.Path {
		t.Fatalf("Get() = %#v, %v", got, ok)
	}
	if got, ok := r.Get("missing"); ok || got.OperationID != "" || got.Action != nil {
		t.Fatalf("missing Get() = %#v, %v", got, ok)
	}
	routes := r.Routes()
	if len(routes) != 1 || routes[0].OperationID != "one" {
		t.Fatalf("Routes() = %#v", routes)
	}
}

func TestRegistryAddPanicsForIncompleteRoute(t *testing.T) {
	base := Route{OperationID: "id", Method: http.MethodGet, Path: "/path", Action: testAction}
	cases := []struct {
		name  string
		route Route
	}{
		{"operation ID", func() Route { x := base; x.OperationID = ""; return x }()},
		{"method", func() Route { x := base; x.Method = ""; return x }()},
		{"path", func() Route { x := base; x.Path = ""; return x }()},
		{"action", func() Route { x := base; x.Action = nil; return x }()},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) { mustPanic(t, func() { NewRegistry().Add(tc.route) }) })
	}
}

func TestRegistryAddPanicsForDuplicate(t *testing.T) {
	r := NewRegistry()
	route := Route{OperationID: "same", Method: http.MethodGet, Path: "/same", Action: testAction}
	r.Add(route)
	mustPanic(t, func() { r.Add(route) })
}

func newServeEvent(t *testing.T) (*tests.TestApp, *core.ServeEvent) {
	t.Helper()
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	router, err := apis.NewRouter(app)
	if err != nil {
		app.Cleanup()
		t.Fatal(err)
	}
	return app, &core.ServeEvent{App: app, Router: router}
}

func TestMountDirectAndMountForTests(t *testing.T) {
	for _, tc := range []struct {
		name  string
		mount func(*core.ServeEvent, []Route)
	}{
		{"direct", MountDirect}, {"tests", MountForTests},
	} {
		t.Run(tc.name, func(t *testing.T) {
			app, e := newServeEvent(t)
			defer app.Cleanup()
			called := false
			routes := []Route{
				{OperationID: "direct", Method: http.MethodGet, Path: "/direct", Direct: true, Action: func(*core.RequestEvent) error { called = true; return nil }},
				{OperationID: "buffered", Method: http.MethodGet, Path: "/buffered", Action: func(*core.RequestEvent) error { called = true; return nil }},
			}
			tc.mount(e, routes)
			mux, err := e.Router.BuildMux()
			if err != nil {
				t.Fatal(err)
			}
			for _, path := range []string{"/direct", "/buffered"} {
				called = false
				rec := httptest.NewRecorder()
				mux.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, path, nil))
				want := tc.name == "tests" || path == "/direct"
				if called != want {
					t.Errorf("%s called=%v, want %v (status %d)", path, called, want, rec.Code)
				}
			}
		})
	}
}

func TestMountAuthRequiresAuthentication(t *testing.T) {
	app, e := newServeEvent(t)
	defer app.Cleanup()
	called := false
	MountForTests(e, []Route{{OperationID: "private", Method: http.MethodGet, Path: "/private", Auth: true, Action: func(*core.RequestEvent) error { called = true; return nil }}})
	mux, err := e.Router.BuildMux()
	if err != nil {
		t.Fatal(err)
	}
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/private", nil))
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status=%d, body=%s", rec.Code, rec.Body.String())
	}
	if called {
		t.Fatal("authenticated action was invoked without credentials")
	}
}
