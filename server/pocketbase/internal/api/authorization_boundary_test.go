package api

import (
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
)

// authorizationBoundaryCase is the authorization contract for an operation.
// Keeping this manifest separate from the unauthenticated route table makes a
// newly registered operation require an explicit authorization decision.
type authorizationBoundaryCase struct {
	operationID  string
	adminOnly    bool
	agentOrAdmin bool
	owned        bool
	public       bool
	// skipRoleGateCheck exempts an operation from the "an authenticated
	// caller must not be rejected at 401/403" assertion in
	// TestAuthorizationBoundaryTableEnforcesRoles. Only use this for
	// operations that have no role gate at all but can legitimately return
	// 403 for an unrelated reason under the test harness's fixed request
	// fixture (e.g. filesystem path-escape validation failing because the
	// test process has no real workspace root) -- never to paper over an
	// actual missing role check.
	skipRoleGateCheck bool
}

var authorizationBoundaryTable = []authorizationBoundaryCase{
	{operationID: "promptChat", owned: true},
	{operationID: "streamChatEvents", owned: true},
	{operationID: "cancelChatSession", owned: true},
	{operationID: "setChatMode", owned: true},
	{operationID: "setChatConfigOption", owned: true},
	{operationID: "respondToPermission", owned: true},
	{operationID: "respondToElicitation", owned: true},
	{operationID: "getHarnessAuthStatus"}, {operationID: "startHarnessAuth"},
	{operationID: "pollHarnessAuth"}, {operationID: "submitHarnessAuth"},
	{operationID: "cancelHarnessAuth"}, {operationID: "disconnectHarnessAuth"},
	{operationID: "runScheduleNow", owned: true},
	// getWorkspaceFile/listWorkspaceFiles have no role gate, but
	// filesystem.resolveWorkspacePath legitimately 403s here because the
	// test process has no real workspace root to resolve -- see
	// skipRoleGateCheck's doc comment.
	{operationID: "getWorkspaceFile", skipRoleGateCheck: true},
	{operationID: "listWorkspaceFiles", skipRoleGateCheck: true},
	{operationID: "listOllamaModels", adminOnly: true},
	{operationID: "pullOllamaModel", adminOnly: true},
	{operationID: "executeMcpRequest", agentOrAdmin: true},
	{operationID: "storeMcpOAuthToken"},
	{operationID: "getReleaseCompatibility", public: true},
	{operationID: "getReleaseStatus"},
	{operationID: "streamContainerLogs", adminOnly: true},
	{operationID: "listContainers", adminOnly: true},
	// proxyObservability has a narrow authenticated-user carve-out for
	// memory.sql; its exact-path boundary is covered separately.
	{operationID: "proxyObservability", skipRoleGateCheck: true},
	{operationID: "sendPushNotification", agentOrAdmin: true},
	{operationID: "endLiveActivity", owned: true},
}

func TestAuthorizationBoundaryTableIsExplicit(t *testing.T) {
	seen := make(map[string]bool, len(authorizationBoundaryTable))
	for _, tc := range authorizationBoundaryTable {
		if tc.operationID == "" || seen[tc.operationID] {
			t.Fatalf("authorization table contains an empty or duplicate operation ID: %q", tc.operationID)
		}
		seen[tc.operationID] = true
		if tc.public && (tc.adminOnly || tc.agentOrAdmin || tc.owned) {
			t.Fatalf("public operation %q also has a protected boundary", tc.operationID)
		}
		if tc.adminOnly && tc.agentOrAdmin {
			t.Fatalf("operation %q has conflicting role boundaries", tc.operationID)
		}
		if tc.skipRoleGateCheck && (tc.adminOnly || tc.agentOrAdmin || tc.owned || tc.public) {
			t.Fatalf("operation %q sets skipRoleGateCheck alongside a role boundary it should instead be tested against", tc.operationID)
		}
	}
}

func endpointForAuthorization(t *testing.T, id string) (string, string, string) {
	t.Helper()
	for _, endpoint := range testsByEndpoint {
		if endpoint.name == id {
			return endpoint.method, endpoint.url, endpoint.body
		}
	}
	t.Fatalf("authorization table operation %q has no testsByEndpoint row", id)
	return "", "", ""
}

// authorizationRequest deliberately does not use ApiScenario: its fixed
// ExpectedStatus field cannot express the contract that an authorized request
// may fail later with an infrastructure error, but must not fail at auth.
func authorizationRequest(t *testing.T, method, url, body, role string) int {
	t.Helper()
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()
	u := testUser(t, app, "auth-boundary-"+randomSuffix()+"@example.com")
	if role != "" {
		u.Set("role", role)
		if err := app.Save(u); err != nil {
			t.Fatal(err)
		}
	}
	token, err := u.NewAuthToken()
	if err != nil {
		t.Fatal(err)
	}
	router, err := apis.NewRouter(app)
	if err != nil {
		t.Fatal(err)
	}
	e := &core.ServeEvent{App: app, Router: router}
	mountAllPocketCoderOperations(t, app, e)
	req := httptest.NewRequest(method, url, strings.NewReader(body))
	req.Header.Set("content-type", "application/json")
	req.Header.Set("Authorization", token)
	mux, err := e.Router.BuildMux()
	if err != nil {
		t.Fatal(err)
	}
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)
	_, _ = io.Copy(io.Discard, rec.Result().Body)
	return rec.Code
}

func TestAuthorizationBoundaryTableEnforcesRoles(t *testing.T) {
	for _, tc := range authorizationBoundaryTable {
		if tc.owned || tc.public {
			continue
		}
		method, url, body := endpointForAuthorization(t, tc.operationID)
		t.Run(tc.operationID, func(t *testing.T) {
			if tc.adminOnly || tc.agentOrAdmin {
				if got := authorizationRequest(t, method, url, body, ""); got != http.StatusForbidden {
					t.Fatalf("plain user status = %d, want 403", got)
				}
				roles := []string{"admin"}
				if tc.agentOrAdmin {
					roles = append(roles, "agent")
				}
				for _, role := range roles {
					if got := authorizationRequest(t, method, url, body, role); got == http.StatusUnauthorized || got == http.StatusForbidden {
						t.Fatalf("%s status = %d, want a status after the role gate", role, got)
					}
				}
				return
			}
			if tc.skipRoleGateCheck {
				return
			}
			if got := authorizationRequest(t, method, url, body, ""); got == http.StatusUnauthorized || got == http.StatusForbidden {
				t.Fatalf("plain authenticated user status = %d, want a status after authentication", got)
			}
		})
	}
}

func TestAuthorizationOwnershipBoundaries(t *testing.T) {
	t.Run("promptChat", func(t *testing.T) {
		app := testApp(t)
		owner := testUser(t, app, "owner-"+randomSuffix()+"@example.com")
		other := testUser(t, app, "other-"+randomSuffix()+"@example.com")
		chat := createTestChat(t, app, map[string]any{"user": owner.Id})
		for _, user := range []*core.Record{other, owner} {
			token, err := user.NewAuthToken()
			if err != nil {
				t.Fatal(err)
			}
			status := mountedRequest(t, app, http.MethodPost, "/api/pocketcoder/v1/chats/"+chat.Id+"/session/prompt", `{"prompt":[{"type":"text","text":"test"}]}`, token)
			if user == other && status != http.StatusNotFound {
				t.Fatalf("non-owner status = %d, want 404", status)
			}
			if user == owner && status == http.StatusNotFound {
				t.Fatal("owner was rejected as not found")
			}
		}
	})

	t.Run("runScheduleNow", func(t *testing.T) {
		app := testApp(t)
		owner := testUser(t, app, "schedule-owner-"+randomSuffix()+"@example.com")
		other := testUser(t, app, "schedule-other-"+randomSuffix()+"@example.com")
		col, err := app.FindCollectionByNameOrId("schedule_owners")
		if err != nil {
			t.Fatal(err)
		}
		schedule := core.NewRecord(col)
		schedule.Set("user", owner.Id)
		schedule.Set("display_name", "Test")
		schedule.Set("prompt", "hello")
		schedule.Set("cron", "* * * * *")
		if err := app.Save(schedule); err != nil {
			t.Fatal(err)
		}
		for _, user := range []*core.Record{other, owner} {
			token, err := user.NewAuthToken()
			if err != nil {
				t.Fatal(err)
			}
			status := mountedRequest(t, app, http.MethodPost, "/api/pocketcoder/v1/schedules/"+schedule.Id+"/run", "", token)
			if user == other && status != http.StatusNotFound {
				t.Fatalf("non-owner status = %d, want 404", status)
			}
			if user == owner && status == http.StatusNotFound {
				t.Fatal("owner was rejected as not found")
			}
		}
	})
}

func TestSendPushNotificationValidatesRequiredFields(t *testing.T) {
	cases := []struct {
		name string
		body string
	}{
		{"missing user_id", `{"type":"test"}`},
		{"missing type", `{"user_id":"test-user"}`},
		{"empty body", `{}`},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := authorizationRequest(t, http.MethodPost, "/api/pocketcoder/v1/push", tc.body, "agent"); got != http.StatusBadRequest {
				t.Fatalf("status = %d, want 400", got)
			}
		})
	}
}

func mountedRequest(t *testing.T, app core.App, method, url, body, token string) int {
	t.Helper()
	router, err := apis.NewRouter(app)
	if err != nil {
		t.Fatal(err)
	}
	e := &core.ServeEvent{App: app, Router: router}
	mountAllPocketCoderOperations(t, app, e)
	req := httptest.NewRequest(method, url, strings.NewReader(body))
	req.Header.Set("Authorization", token)
	mux, err := e.Router.BuildMux()
	if err != nil {
		t.Fatal(err)
	}
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)
	return rec.Code
}
