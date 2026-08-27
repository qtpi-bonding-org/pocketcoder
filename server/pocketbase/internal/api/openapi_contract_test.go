/*
PocketCoder: An accessible, secure, and user-friendly open-source coding assistant platform.
Copyright (C) 2026 Qtpi Bonding LLC

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

package api

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/getkin/kin-openapi/openapi3"
	"github.com/getkin/kin-openapi/openapi3filter"
	"github.com/getkin/kin-openapi/routers/gorillamux"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
)

// openAPIBundlePath is relative to this package's own directory
// (server/pocketbase/internal/api).
const openAPIBundlePath = "../../../../api/openapi/pocketcoder.bundle.yaml"

// loadOpenAPISpec loads the bundled OpenAPI document fresh for each test --
// a broken/unparseable bundle must fail loudly here rather than silently
// skip every contract check below.
func loadOpenAPISpec(t *testing.T) *openapi3.T {
	t.Helper()
	loader := openapi3.NewLoader()
	doc, err := loader.LoadFromFile(openAPIBundlePath)
	if err != nil {
		t.Fatalf("load OpenAPI bundle: %v", err)
	}
	if err := doc.Validate(loader.Context); err != nil {
		t.Fatalf("OpenAPI bundle is invalid: %v", err)
	}
	return doc
}

// assertResponseMatchesContract is a regression guard against handlers that
// build a response by hand (re.JSON(status, ...)) and silently drift from
// the schema their own OpenAPI operation declares for that status code.
// This is exactly what happened live: promptChat's branch for a
// still-provisioning harness returned 202 with {status, message} instead of
// the documented AcceptedResponse ({runId}, additionalProperties: false) --
// a generated client can't deserialize that and throws instead of surfacing
// a friendly retry state.
func assertResponseMatchesContract(t *testing.T, doc *openapi3.T, request *http.Request, rec *httptest.ResponseRecorder) {
	t.Helper()
	router, err := gorillamux.NewRouter(doc)
	if err != nil {
		t.Fatalf("build OpenAPI router: %v", err)
	}
	route, pathParams, err := router.FindRoute(request)
	if err != nil {
		t.Fatalf("find OpenAPI route for %s %s: %v", request.Method, request.URL.Path, err)
	}
	input := &openapi3filter.ResponseValidationInput{
		RequestValidationInput: &openapi3filter.RequestValidationInput{
			Request:    request,
			PathParams: pathParams,
			Route:      route,
		},
		Status: rec.Code,
		Header: rec.Header(),
	}
	input.SetBodyBytes(rec.Body.Bytes())
	if err := openapi3filter.ValidateResponse(context.Background(), input); err != nil {
		t.Fatalf("response for %s %s (status %d) does not match its OpenAPI contract: %v\nbody: %s",
			request.Method, request.URL.Path, rec.Code, err, rec.Body.String())
	}
}

func TestPromptChatStillProvisioningResponseMatchesOpenAPIContract(t *testing.T) {
	doc := loadOpenAPISpec(t)
	app := testApp(t)
	owner := testUser(t, app, "contract-owner-"+randomSuffix()+"@example.com")

	// A "pending" harness_instances row makes sessionprofile.Build return
	// ErrProvisioning synchronously (sessionprofile.go's switch case),
	// without needing to exercise the "no row yet" branch's background
	// hooks.ProvisionHarnessInstance goroutine.
	harness, instance := seedTestHarnessAndInstance(t, app, "goose", false, owner.Id)
	instance.Set("status", "pending")
	if err := app.Save(instance); err != nil {
		t.Fatal(err)
	}
	chat := createTestChat(t, app, map[string]any{"user": owner.Id, "harness": harness.Id})

	token, err := owner.NewAuthToken()
	if err != nil {
		t.Fatal(err)
	}
	body := `{"prompt":[{"type":"text","text":"hello"}]}`
	req := httptest.NewRequest(http.MethodPost, "/api/pocketcoder/v1/chats/"+chat.Id+"/session/prompt", strings.NewReader(body))
	req.Header.Set("content-type", "application/json")
	req.Header.Set("Authorization", token)

	router, err := apis.NewRouter(app)
	if err != nil {
		t.Fatal(err)
	}
	e := &core.ServeEvent{App: app, Router: router}
	mountAllPocketCoderOperations(t, app, e)
	mux, err := e.Router.BuildMux()
	if err != nil {
		t.Fatal(err)
	}
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)

	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("status = %d, want %d (harness instance is pending) -- body: %s",
			rec.Code, http.StatusServiceUnavailable, rec.Body.String())
	}
	assertResponseMatchesContract(t, doc, req, rec)
}
