package operationapi

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/agent/coordinator"
	_ "github.com/qtpi-bonding-org/pocketcoder/backend/pb_migrations"
)

// TestRegisterWiresAuthMiddlewareToTheGeneratedStrictServer is the one test
// in this whole codebase that drives a real request through Register()'s
// actual production wiring (the generated strict server + authMiddleware +
// operation.Registry), rather than operation.MountForTests -- which every
// other test (internal/api's contract/boundary suite, and this package's
// own authMiddleware unit tests above) uses instead, and which mounts each
// route's Action directly, calling authMiddleware for none of them.
//
// Live-confirmed 2026-08-27: oapi-codegen's generated strict-server wrapper
// invokes StrictMiddlewareFunc with the operation's exported Go method name
// ("GetReleaseCompatibility", PascalCase), while every registry.Add call
// site uses the raw OpenAPI operationId ("getReleaseCompatibility",
// camelCase) -- an exact-match registry lookup between the two conventions
// failed for every single strict-server operation, with no exceptions,
// silently breaking the entire migrated API surface end to end in
// production. Nothing in the Go test suite caught it, specifically because
// MountForTests bypasses the exact code path (authMiddleware's
// registry.Get(operationID) call) the bug lived in -- and the existing
// authMiddleware unit tests above use a same-case operation id ("public")
// on both the registration and lookup side, which can't exercise a
// cross-convention case mismatch either. This test exists so that gap can
// never reopen silently: it fails immediately (before the registry
// case-insensitivity fix) with "operation is not registered: ...", and
// passes only once a real HTTP request survives the real wiring end to end.
func TestRegisterWiresAuthMiddlewareToTheGeneratedStrictServer(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(app.Cleanup)

	router, err := apis.NewRouter(app)
	if err != nil {
		t.Fatal(err)
	}
	e := &core.ServeEvent{App: app, Router: router}

	if _, err := Register(app, e, func() coordinator.AgentRuntime { return nil }); err != nil {
		t.Fatalf("Register: %v", err)
	}

	mux, err := e.Router.BuildMux()
	if err != nil {
		t.Fatal(err)
	}

	// getReleaseCompatibility: security: [] in the OpenAPI spec, so this
	// needs no auth token -- a clean way to isolate the registry-lookup
	// bug from any separate authentication concern.
	req := httptest.NewRequest(http.MethodGet, "/api/pocketcoder/v1/compatibility", nil)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("GET /api/pocketcoder/v1/compatibility: status = %d, body = %s", rec.Code, rec.Body.String())
	}
	if strings.Contains(rec.Body.String(), "not registered") {
		t.Fatalf("response leaked the registry-lookup failure: %s", rec.Body.String())
	}
	if !strings.Contains(rec.Body.String(), `"schemaVersion"`) {
		t.Fatalf("response does not look like a real compatibility document: %s", rec.Body.String())
	}
}
