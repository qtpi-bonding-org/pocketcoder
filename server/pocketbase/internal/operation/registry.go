// Package operation defines the direct boundary between generated OpenAPI
// operations and PocketBase request handlers.
package operation

import (
	"fmt"
	"strings"

	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
)

type Action func(*core.RequestEvent) error

type Route struct {
	OperationID string
	Method      string
	Path        string
	Auth        bool
	Direct      bool
	Action      Action
}

type Registry struct {
	routes map[string]Route
}

func NewRegistry() *Registry {
	return &Registry{routes: map[string]Route{}}
}

// Registry keys are case-insensitive (normalized via strings.ToLower).
// Live-confirmed 2026-08-27: oapi-codegen's generated strict-server wrapper
// calls StrictMiddlewareFunc with the operation's exported Go method name
// (PascalCase, e.g. "GetReleaseCompatibility"), while every registry.Add
// call site here uses the raw OpenAPI operationId (camelCase, lowercase
// first letter, e.g. "getReleaseCompatibility") -- an exact-match lookup
// between the two conventions failed for every single strict-server
// operation, with no exceptions, silently breaking the entire migrated API
// surface. Case-insensitive keys make the two conventions interchangeable
// without touching either convention's ~30 call sites.
func (r *Registry) Add(route Route) {
	if route.OperationID == "" || route.Method == "" || route.Path == "" || route.Action == nil {
		panic("operation route is incomplete")
	}
	key := strings.ToLower(route.OperationID)
	if _, exists := r.routes[key]; exists {
		panic(fmt.Sprintf("operation %q registered twice", route.OperationID))
	}
	r.routes[key] = route
}

func (r *Registry) Get(operationID string) (Route, bool) {
	route, ok := r.routes[strings.ToLower(operationID)]
	return route, ok
}

func (r *Registry) Routes() []Route {
	routes := make([]Route, 0, len(r.routes))
	for _, route := range r.routes {
		routes = append(routes, route)
	}
	return routes
}

// MountForTests mounts operation actions directly so package tests can exercise
// a focused handler without constructing the complete generated API server.
// Production never calls this function.
func MountForTests(e *core.ServeEvent, routes []Route) {
	mount(e, routes, false)
}

// MountDirect installs only transports that cannot safely pass through a
// buffered strict response: SSE, NDJSON, opaque proxying, and binary files.
func MountDirect(e *core.ServeEvent, routes []Route) {
	mount(e, routes, true)
}

func mount(e *core.ServeEvent, routes []Route, directOnly bool) {
	for _, route := range routes {
		if directOnly && !route.Direct {
			continue
		}
		registered := e.Router.Route(route.Method, route.Path, route.Action)
		if route.Auth {
			registered.Bind(apis.RequireAuth())
		}
	}
}
