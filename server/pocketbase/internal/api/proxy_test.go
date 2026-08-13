package api

import (
	"net/http"
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/operation"
)

func TestObservabilityProxyDoesNotAcceptPost(t *testing.T) {
	scenario := tests.ApiScenario{
		Name:            "observability proxy is read-only at the HTTP boundary",
		Method:          http.MethodPost,
		URL:             "/api/pocketcoder/v1/proxy/observability/",
		ExpectedStatus:  http.StatusNotFound,
		ExpectedContent: []string{`"status":404`},
		BeforeTestFunc: func(_ testing.TB, _ *tests.TestApp, e *core.ServeEvent) {
			registry := operation.NewRegistry()
			AddProxyOperations(registry)
			operation.MountForTests(e, registry.Routes())
		},
	}
	scenario.Test(t)
}
