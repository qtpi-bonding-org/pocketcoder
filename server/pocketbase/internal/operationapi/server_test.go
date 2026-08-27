package operationapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/router"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/openapi"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/operation"
)

func dispatchEvent() (*core.RequestEvent, *httptest.ResponseRecorder) {
	rec := httptest.NewRecorder()
	re := &core.RequestEvent{Event: router.Event{
		Request:  httptest.NewRequest(http.MethodGet, "/items/", nil),
		Response: rec,
	}}
	return re, rec
}

func dispatchContext(re *core.RequestEvent) context.Context {
	return context.WithValue(context.Background(), requestEventContextKey{}, re)
}

func routeFor(id string, action operation.Action) operation.Route {
	return operation.Route{OperationID: id, Method: http.MethodGet, Path: "/items/{id}", Action: action}
}

func TestAuthMiddlewareRejectsUnauthenticatedRequestForAuthRequiredOperation(t *testing.T) {
	reg := operation.NewRegistry()
	route := routeFor("private", func(*core.RequestEvent) error { return nil })
	route.Auth = true
	reg.Add(route)
	called := false
	inner := func(ctx context.Context, w http.ResponseWriter, r *http.Request, request any) (any, error) {
		called = true
		return nil, nil
	}
	re, _ := dispatchEvent()
	_, err := authMiddleware(reg)(inner, "private")(dispatchContext(re), re.Response, re.Request, nil)
	if err == nil {
		t.Fatal("expected an error for an unauthenticated request to an Auth: true operation")
	}
	if called {
		t.Fatal("inner handler called without authentication")
	}
}

func TestAuthMiddlewareAllowsOperationsThatDoNotRequireAuth(t *testing.T) {
	reg := operation.NewRegistry()
	reg.Add(routeFor("public", func(*core.RequestEvent) error { return nil }))
	called := false
	inner := func(ctx context.Context, w http.ResponseWriter, r *http.Request, request any) (any, error) {
		called = true
		return "ok", nil
	}
	re, _ := dispatchEvent()
	result, err := authMiddleware(reg)(inner, "public")(dispatchContext(re), re.Response, re.Request, nil)
	if err != nil {
		t.Fatal(err)
	}
	if !called {
		t.Fatal("inner handler was not called for a public operation")
	}
	if result != "ok" {
		t.Fatalf("result=%v", result)
	}
}

func TestGetReleaseCompatibilityBuildsATypedResponseWithoutDispatch(t *testing.T) {
	s := &server{registry: operation.NewRegistry()}
	response, err := s.GetReleaseCompatibility(context.Background(), openapi.GetReleaseCompatibilityRequestObject{})
	if err != nil {
		t.Fatal(err)
	}
	typed, ok := response.(openapi.GetReleaseCompatibility200JSONResponse)
	if !ok {
		t.Fatalf("response type = %T, want GetReleaseCompatibility200JSONResponse", response)
	}
	if typed.SchemaVersion != 1 {
		t.Fatalf("schemaVersion = %d, want 1", typed.SchemaVersion)
	}
	if typed.Compatibility == nil {
		t.Fatal("compatibility is nil")
	}
}
