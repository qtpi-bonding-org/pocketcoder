package api

import (
	"net/http"
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
)

func TestObservabilityProxyDoesNotAcceptPost(t *testing.T) {
	scenario := tests.ApiScenario{
		Name:            "observability proxy is read-only at the HTTP boundary",
		Method:          http.MethodPost,
		URL:             "/api/pocketcoder/proxy/observability/",
		ExpectedStatus:  http.StatusNotFound,
		ExpectedContent: []string{`"status":404`},
		BeforeTestFunc: func(_ testing.TB, app *tests.TestApp, e *core.ServeEvent) {
			RegisterProxyApi(app, e)
		},
	}
	scenario.Test(t)
}
