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
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/harnessauth"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/mcpserver"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/operation"
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

// TestGetReleaseCompatibilityResponseMatchesOpenAPIContract covers the one
// public, unauthenticated operation.
func TestGetReleaseCompatibilityResponseMatchesOpenAPIContract(t *testing.T) {
	doc := loadOpenAPISpec(t)
	app := testApp(t)
	req, rec := mountedRequestRaw(t, app, http.MethodGet, "/api/pocketcoder/v1/compatibility", "", "")
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200: %s", rec.Code, rec.Body.String())
	}
	assertContractedResponse(t, doc, req, rec)
}

// assertContractedResponse is assertResponseMatchesContract plus the one
// sanity check every case below needs: that the operation actually produced
// a response (not a test-harness/setup failure) before bothering to
// validate its shape against the spec.
func assertContractedResponse(t *testing.T, doc *openapi3.T, req *http.Request, rec *httptest.ResponseRecorder) {
	t.Helper()
	if rec.Code == 0 {
		t.Fatalf("%s %s produced no response", req.Method, req.URL.Path)
	}
	assertResponseMatchesContract(t, doc, req, rec)
}

// TestChatOperationsResponsesMatchOpenAPIContract covers the five
// chats/{chatId}/session/* operations (promptChat has its own dedicated
// test above, since its interesting branch needs a provisioning harness
// instance). None of these need a live Goose run: hitting them against a
// chat with no active run exercises each operation's documented "no
// active run" / "not found" error branch, which is exactly the kind of
// hand-built response body that used to drift from its schema.
func TestChatOperationsResponsesMatchOpenAPIContract(t *testing.T) {
	doc := loadOpenAPISpec(t)
	app := testApp(t)
	owner := testUser(t, app, "contract-chat-"+randomSuffix()+"@example.com")
	chat := createTestChat(t, app, map[string]any{"user": owner.Id})
	token, err := owner.NewAuthToken()
	if err != nil {
		t.Fatal(err)
	}

	cases := []struct {
		name string
		path string
		body string
	}{
		{"cancelChatSession", "/api/pocketcoder/v1/chats/" + chat.Id + "/session/cancel", ""},
		{"setChatMode", "/api/pocketcoder/v1/chats/" + chat.Id + "/session/set-mode", `{"modeId":"approve"}`},
		{"setChatConfigOption", "/api/pocketcoder/v1/chats/" + chat.Id + "/session/set-config-option", `{"configId":"provider","value":"openrouter"}`},
		{"respondToPermission", "/api/pocketcoder/v1/chats/" + chat.Id + "/session/request-permission/missing-request", `{"outcome":{"outcome":"cancelled"}}`},
		{"respondToElicitation", "/api/pocketcoder/v1/chats/" + chat.Id + "/session/elicitation/missing-request", `{"action":"cancel"}`},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			req, rec := mountedRequestRaw(t, app, http.MethodPost, tc.path, tc.body, token)
			if rec.Code < 200 || rec.Code >= 500 {
				t.Fatalf("%s: unexpected status %d: %s", tc.name, rec.Code, rec.Body.String())
			}
			assertContractedResponse(t, doc, req, rec)
		})
	}
}

// TestSimpleGetOperationsResponsesMatchOpenAPIContract covers the plain
// authenticated GET operations that need no per-test fixture data.
func TestSimpleGetOperationsResponsesMatchOpenAPIContract(t *testing.T) {
	doc := loadOpenAPISpec(t)
	app := testApp(t)
	owner := testUser(t, app, "contract-get-"+randomSuffix()+"@example.com")
	token, err := owner.NewAuthToken()
	if err != nil {
		t.Fatal(err)
	}

	cases := []string{
		"getReleaseStatus",
		"listOllamaModels",
		"listWorkspaceFileTree",
	}
	paths := map[string]string{
		"getReleaseStatus":      "/api/pocketcoder/v1/release/status",
		"listOllamaModels":      "/api/pocketcoder/v1/ollama/models",
		"listWorkspaceFileTree": "/api/pocketcoder/v1/files-tree",
	}
	for _, name := range cases {
		t.Run(name, func(t *testing.T) {
			req, rec := mountedRequestRaw(t, app, http.MethodGet, paths[name], "", token)
			assertContractedResponse(t, doc, req, rec)
		})
	}
}

// TestRunScheduleNowResponseMatchesOpenAPIContract exercises the one
// success path that's cheap to set up (an owned, unstarted schedule).
func TestRunScheduleNowResponseMatchesOpenAPIContract(t *testing.T) {
	doc := loadOpenAPISpec(t)
	app := testApp(t)
	owner := testUser(t, app, "contract-schedule-"+randomSuffix()+"@example.com")
	token, err := owner.NewAuthToken()
	if err != nil {
		t.Fatal(err)
	}
	coll, err := app.FindCollectionByNameOrId("schedule_owners")
	if err != nil {
		t.Fatal(err)
	}
	schedule := core.NewRecord(coll)
	schedule.Set("user", owner.Id)
	schedule.Set("display_name", "Contract schedule")
	schedule.Set("prompt", "hello")
	schedule.Set("cron", "* * * * *")
	if err := app.Save(schedule); err != nil {
		t.Fatal(err)
	}

	req, rec := mountedRequestRaw(t, app, http.MethodPost, "/api/pocketcoder/v1/schedules/"+schedule.Id+"/run", "", token)
	if rec.Code != http.StatusAccepted {
		t.Fatalf("status = %d, want 202: %s", rec.Code, rec.Body.String())
	}
	assertContractedResponse(t, doc, req, rec)
}

// TestEndLiveActivityResponseMatchesOpenAPIContract covers the one
// success path (an owned, still-active live activity).
func TestEndLiveActivityResponseMatchesOpenAPIContract(t *testing.T) {
	doc := loadOpenAPISpec(t)
	app := testApp(t)
	owner := liveActivityRouteTestUser(t, app, "contract-live-activity-"+randomSuffix()+"@example.com")
	row := liveActivityRouteTestRow(t, app, owner.Id, "active")
	token, err := owner.NewAuthToken()
	if err != nil {
		t.Fatal(err)
	}

	req, rec := mountedRequestRaw(t, app, http.MethodPost, "/api/pocketcoder/v1/live-activities/"+row.Id+"/end", "", token)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200: %s", rec.Code, rec.Body.String())
	}
	assertContractedResponse(t, doc, req, rec)
}

// TestSendPushNotificationResponseMatchesOpenAPIContract covers the one
// success path (an "agent"-role caller with a valid body).
func TestSendPushNotificationResponseMatchesOpenAPIContract(t *testing.T) {
	doc := loadOpenAPISpec(t)
	app := testApp(t)
	col, err := app.FindCollectionByNameOrId("_pb_users_auth_")
	if err != nil {
		t.Fatal(err)
	}
	agent := core.NewRecord(col)
	agent.SetEmail("contract-push-" + randomSuffix() + "@example.com")
	agent.SetPassword("password123")
	agent.Set("role", "agent")
	if err := app.Save(agent); err != nil {
		t.Fatal(err)
	}
	token, err := agent.NewAuthToken()
	if err != nil {
		t.Fatal(err)
	}

	req, rec := mountedRequestRaw(t, app, http.MethodPost, "/api/pocketcoder/v1/push", `{"user_id":"test-user","type":"test"}`, token)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200: %s", rec.Code, rec.Body.String())
	}
	assertContractedResponse(t, doc, req, rec)
}

// TestExecuteMcpRequestResponseMatchesOpenAPIContract injects a fake image
// resolver so the success path doesn't make a real registry call.
func TestExecuteMcpRequestResponseMatchesOpenAPIContract(t *testing.T) {
	doc := loadOpenAPISpec(t)
	app := testApp(t)
	col, err := app.FindCollectionByNameOrId("_pb_users_auth_")
	if err != nil {
		t.Fatal(err)
	}
	agent := core.NewRecord(col)
	agent.SetEmail("contract-mcp-" + randomSuffix() + "@example.com")
	agent.SetPassword("password123")
	agent.Set("role", "agent")
	if err := app.Save(agent); err != nil {
		t.Fatal(err)
	}
	token, err := agent.NewAuthToken()
	if err != nil {
		t.Fatal(err)
	}

	fakeResolve := mcpserver.ImageResolver(func(context.Context, string, string) (string, error) {
		return "sha256:deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef", nil
	})
	router, err := apis.NewRouter(app)
	if err != nil {
		t.Fatal(err)
	}
	e := &core.ServeEvent{App: app, Router: router}
	registry := operation.NewRegistry()
	AddMcpOperations(app, registry, McpDeps{ResolveImage: fakeResolve})
	operation.MountForTests(e, registry.Routes())
	req := httptest.NewRequest(http.MethodPost, "/api/pocketcoder/v1/mcp/request", strings.NewReader(`{"server_name":"contract-test-server"}`))
	req.Header.Set("Authorization", token)
	req.Header.Set("Content-Type", "application/json")
	mux, err := e.Router.BuildMux()
	if err != nil {
		t.Fatal(err)
	}
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200: %s", rec.Code, rec.Body.String())
	}
	assertContractedResponse(t, doc, req, rec)
}

// TestStoreMcpOAuthTokenResponseMatchesOpenAPIContract covers the one
// success path (an existing mcp_servers row with its env var configured).
func TestStoreMcpOAuthTokenResponseMatchesOpenAPIContract(t *testing.T) {
	doc := loadOpenAPISpec(t)
	app := testApp(t)
	newMcpServer(t, app, "contract-oauth-server", "approved", map[string]any{
		"oauth_token_env_var": "CONTRACT_TEST_TOKEN",
	})
	owner := testUser(t, app, "contract-mcp-oauth-"+randomSuffix()+"@example.com")
	token, err := owner.NewAuthToken()
	if err != nil {
		t.Fatal(err)
	}

	body := `{"server_name":"contract-oauth-server","access_token":"tok123"}`
	req, rec := mountedRequestRaw(t, app, http.MethodPost, "/api/pocketcoder/v1/mcp/oauth/store", body, token)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200: %s", rec.Code, rec.Body.String())
	}
	assertContractedResponse(t, doc, req, rec)
}

// TestHarnessAuthOperationsResponsesMatchOpenAPIContract drives the full
// harness-auth lifecycle (start -> poll -> submit -> cancel -> disconnect)
// against a fake harnessAuthRuntime, plus the standalone status/none-mode
// paths, so every harness-auth operation's real success response gets
// checked against its OpenAPI contract at least once.
func TestHarnessAuthOperationsResponsesMatchOpenAPIContract(t *testing.T) {
	doc := loadOpenAPISpec(t)
	app := testApp(t)
	owner := testUser(t, app, "contract-harness-auth-"+randomSuffix()+"@example.com")

	codex, err := app.FindFirstRecordByFilter("harnesses", "cli_id = 'codex'")
	if err != nil {
		t.Fatal(err)
	}
	openai, err := app.FindFirstRecordByFilter("providers", "provider_id = 'openai'")
	if err != nil {
		t.Fatal(err)
	}
	awaiting := &harnessauth.AttemptState{Status: harnessauth.AttemptStatusAwaiting}
	fake := &fakeHarnessAuthRuntime{start: awaiting, poll: awaiting, submit: awaiting, cancel: awaiting, disconnect: awaiting}
	authBody := `{"harness":"` + codex.Id + `","provider":"` + openai.Id + `"}`

	t.Run("getHarnessAuthStatus", func(t *testing.T) {
		req, rec := harnessRequestRaw(t, app, fake, owner, "/api/pocketcoder/v1/harness-auth/status", authBody)
		if rec.Code != http.StatusOK {
			t.Fatalf("status = %d, want 200: %s", rec.Code, rec.Body.String())
		}
		assertContractedResponse(t, doc, req, rec)
	})

	t.Run("startHarnessAuth", func(t *testing.T) {
		req, rec := harnessRequestRaw(t, app, fake, owner, "/api/pocketcoder/v1/harness-auth/start", `{"harness":"`+codex.Id+`","provider":"`+openai.Id+`","mode":"oauth"}`)
		if rec.Code != http.StatusOK {
			t.Fatalf("status = %d, want 200: %s", rec.Code, rec.Body.String())
		}
		assertContractedResponse(t, doc, req, rec)
	})

	t.Run("pollHarnessAuth", func(t *testing.T) {
		req, rec := harnessRequestRaw(t, app, fake, owner, "/api/pocketcoder/v1/harness-auth/poll", authBody)
		if rec.Code != http.StatusOK {
			t.Fatalf("status = %d, want 200: %s", rec.Code, rec.Body.String())
		}
		assertContractedResponse(t, doc, req, rec)
	})

	t.Run("submitHarnessAuth", func(t *testing.T) {
		req, rec := harnessRequestRaw(t, app, fake, owner, "/api/pocketcoder/v1/harness-auth/submit", `{"harness":"`+codex.Id+`","provider":"`+openai.Id+`","code":"test-code"}`)
		if rec.Code != http.StatusOK {
			t.Fatalf("status = %d, want 200: %s", rec.Code, rec.Body.String())
		}
		assertContractedResponse(t, doc, req, rec)
	})

	t.Run("cancelHarnessAuth", func(t *testing.T) {
		req, rec := harnessRequestRaw(t, app, fake, owner, "/api/pocketcoder/v1/harness-auth/cancel", authBody)
		if rec.Code != http.StatusOK {
			t.Fatalf("status = %d, want 200: %s", rec.Code, rec.Body.String())
		}
		assertContractedResponse(t, doc, req, rec)
	})

	t.Run("disconnectHarnessAuth", func(t *testing.T) {
		req, rec := harnessRequestRaw(t, app, fake, owner, "/api/pocketcoder/v1/harness-auth/disconnect", authBody)
		if rec.Code != http.StatusOK {
			t.Fatalf("status = %d, want 200: %s", rec.Code, rec.Body.String())
		}
		assertContractedResponse(t, doc, req, rec)
	})
}
