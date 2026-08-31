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

package hooks

import (
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/router"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/operation"
)

func sendPushNotificationAction(t *testing.T, app core.App) operation.Action {
	t.Helper()
	registry := operation.NewRegistry()
	AddPushOperations(app, registry)
	route, ok := registry.Get("sendPushNotification")
	if !ok {
		t.Fatal("sendPushNotification operation not registered")
	}
	return route.Action
}

func callSendPushNotification(t *testing.T, action operation.Action, auth *core.Record, body string) *httptest.ResponseRecorder {
	t.Helper()
	recorder := httptest.NewRecorder()
	req := httptest.NewRequest("POST", "/api/pocketcoder/v1/push", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	re := &core.RequestEvent{Event: router.Event{Response: recorder, Request: req}}
	re.Auth = auth
	if err := action(re); err != nil {
		router.ErrorHandler(recorder, req, err)
	}
	return recorder
}

func pushTestUserWithRole(t *testing.T, app core.App, email, role string) *core.Record {
	t.Helper()
	user := testUser(t, app, email)
	user.Set("role", role)
	if err := app.Save(user); err != nil {
		t.Fatal(err)
	}
	return user
}

func TestSendPushNotificationRejectsCallerWithoutAgentOrAdminRole(t *testing.T) {
	app := testApp(t)
	caller := pushTestUserWithRole(t, app, "push-plain-user@example.com", "user")

	action := sendPushNotificationAction(t, app)
	recorder := callSendPushNotification(t, action, caller, `{"user_id":"someone","type":"chat_reply"}`)

	if recorder.Code != 403 {
		t.Fatalf("status = %d, want 403 for a caller with role \"user\"", recorder.Code)
	}
}

func TestSendPushNotificationRejectsMissingRequiredFields(t *testing.T) {
	app := testApp(t)
	caller := pushTestUserWithRole(t, app, "push-agent-missing-fields@example.com", "agent")

	action := sendPushNotificationAction(t, app)
	// user_id is required and deliberately omitted here.
	recorder := callSendPushNotification(t, action, caller, `{"type":"chat_reply"}`)

	if recorder.Code != 400 {
		t.Fatalf("status = %d, want 400 when user_id is missing", recorder.Code)
	}
}

func TestSendPushNotificationSucceedsForAgentCaller(t *testing.T) {
	app := testApp(t)
	caller := pushTestUserWithRole(t, app, "push-agent-ok@example.com", "agent")
	// Any real user id is fine here: the actual device dispatch runs in a
	// detached goroutine and never affects this response, so this test
	// exercises only the route's own request-validation and role-gate
	// contract without needing a live push relay.
	recipient := testUser(t, app, "push-recipient@example.com")

	action := sendPushNotificationAction(t, app)
	recorder := callSendPushNotification(t, action, caller,
		`{"user_id":"`+recipient.Id+`","title":"Hi","message":"hello","type":"chat_reply"}`)

	if recorder.Code != 200 {
		t.Fatalf("status = %d, want 200; body=%s", recorder.Code, recorder.Body.String())
	}
	if !strings.Contains(recorder.Body.String(), `"ok":true`) {
		t.Fatalf("body = %q, want {\"ok\":true}", recorder.Body.String())
	}
}

func TestSendPushNotificationAllowsAdminCaller(t *testing.T) {
	app := testApp(t)
	caller := pushTestUserWithRole(t, app, "push-admin-ok@example.com", "admin")
	recipient := testUser(t, app, "push-admin-recipient@example.com")

	action := sendPushNotificationAction(t, app)
	recorder := callSendPushNotification(t, action, caller,
		`{"user_id":"`+recipient.Id+`","type":"chat_reply"}`)

	if recorder.Code != 200 {
		t.Fatalf("status = %d, want 200 for an admin caller; body=%s", recorder.Code, recorder.Body.String())
	}
}
