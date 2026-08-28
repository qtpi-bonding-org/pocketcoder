package api

import (
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/router"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/operation"
)

func liveActivityRouteTestUser(t *testing.T, app core.App, email string) *core.Record {
	t.Helper()
	coll, err := app.FindCollectionByNameOrId("_pb_users_auth_")
	if err != nil {
		t.Fatal(err)
	}
	u := core.NewRecord(coll)
	u.SetEmail(email)
	u.SetPassword("password123")
	if err := app.Save(u); err != nil {
		t.Fatal(err)
	}
	return u
}

func liveActivityRouteTestRow(t *testing.T, app core.App, userID, status string) *core.Record {
	t.Helper()
	deviceColl, err := app.FindCollectionByNameOrId("devices")
	if err != nil {
		t.Fatal(err)
	}
	device := core.NewRecord(deviceColl)
	device.Set("user", userID)
	device.Set("name", "test device")
	device.Set("push_token", "test-token")
	device.Set("push_service", "fcm")
	if err := app.Save(device); err != nil {
		t.Fatal(err)
	}

	chatColl, err := app.FindCollectionByNameOrId("chats")
	if err != nil {
		t.Fatal(err)
	}
	chat := core.NewRecord(chatColl)
	chat.Set("user", userID)
	chat.Set("title", "Test Chat")
	if err := app.Save(chat); err != nil {
		t.Fatal(err)
	}

	activityColl, err := app.FindCollectionByNameOrId("live_activities")
	if err != nil {
		t.Fatal(err)
	}
	row := core.NewRecord(activityColl)
	row.Set("user", userID)
	row.Set("device", device.Id)
	row.Set("chat", chat.Id)
	row.Set("platform", "ios")
	row.Set("status", status)
	row.Set("content_state_version", 1)
	if err := app.Save(row); err != nil {
		t.Fatal(err)
	}
	return row
}

func endLiveActivityAction(t *testing.T, app core.App) operation.Action {
	t.Helper()
	registry := operation.NewRegistry()
	AddLiveActivityOperations(app, registry)
	route, ok := registry.Get("endLiveActivity")
	if !ok {
		t.Fatal("endLiveActivity operation not registered")
	}
	return route.Action
}

func callEndLiveActivity(t *testing.T, action operation.Action, auth *core.Record, activityID string) *httptest.ResponseRecorder {
	t.Helper()
	recorder := httptest.NewRecorder()
	req := httptest.NewRequest("POST", "/api/pocketcoder/v1/live-activities/"+activityID+"/end", nil)
	req.SetPathValue("id", activityID)
	re := &core.RequestEvent{Event: router.Event{Response: recorder, Request: req}}
	re.Auth = auth
	// Some rejection paths (e.g. apis.NewApiError) write nothing themselves
	// and instead return a real error for the router to translate into a
	// response -- router.ErrorHandler is what actually does that
	// translation in production; a raw action(re) call here bypasses it, so
	// route any returned error through the same handler PocketBase itself
	// wires up (see internal/operationapi/server.go's dispatch for the
	// identical pattern).
	if err := action(re); err != nil {
		router.ErrorHandler(recorder, req, err)
	}
	return recorder
}

func TestEndLiveActivityRejectsNonOwner(t *testing.T) {
	app := testApp(t)
	owner := liveActivityRouteTestUser(t, app, "la-end-owner@example.com")
	other := liveActivityRouteTestUser(t, app, "la-end-other@example.com")
	row := liveActivityRouteTestRow(t, app, owner.Id, "active")

	action := endLiveActivityAction(t, app)
	recorder := callEndLiveActivity(t, action, other, row.Id)

	if recorder.Code != 404 {
		t.Fatalf("status = %d, want 404 (requireOwnedRecord keeps non-owned and missing indistinguishable)", recorder.Code)
	}
	reloaded, err := app.FindRecordById("live_activities", row.Id)
	if err != nil {
		t.Fatal(err)
	}
	if reloaded.GetString("status") != "active" {
		t.Fatalf("status = %q after rejected end attempt, want unchanged %q", reloaded.GetString("status"), "active")
	}
}

func TestEndLiveActivityRejectsAlreadyEnded(t *testing.T) {
	app := testApp(t)
	owner := liveActivityRouteTestUser(t, app, "la-end-already@example.com")
	row := liveActivityRouteTestRow(t, app, owner.Id, "ended")

	action := endLiveActivityAction(t, app)
	recorder := callEndLiveActivity(t, action, owner, row.Id)

	if recorder.Code != 409 {
		t.Fatalf("status = %d, want 409 for an already-ended activity", recorder.Code)
	}
}

func setLiveActivityTokenAction(t *testing.T, app core.App) operation.Action {
	t.Helper()
	registry := operation.NewRegistry()
	AddLiveActivityOperations(app, registry)
	route, ok := registry.Get("setLiveActivityToken")
	if !ok {
		t.Fatal("setLiveActivityToken operation not registered")
	}
	return route.Action
}

func callSetLiveActivityToken(t *testing.T, action operation.Action, auth *core.Record, activityID, token string) *httptest.ResponseRecorder {
	t.Helper()
	recorder := httptest.NewRecorder()
	body := strings.NewReader(`{"activity_push_token":"` + token + `"}`)
	req := httptest.NewRequest("POST", "/api/pocketcoder/v1/live-activities/"+activityID+"/token", body)
	req.Header.Set("Content-Type", "application/json")
	req.SetPathValue("id", activityID)
	re := &core.RequestEvent{Event: router.Event{Response: recorder, Request: req}}
	re.Auth = auth
	if err := action(re); err != nil {
		router.ErrorHandler(recorder, req, err)
	}
	return recorder
}

func TestSetLiveActivityTokenRejectsNonOwner(t *testing.T) {
	app := testApp(t)
	owner := liveActivityRouteTestUser(t, app, "la-token-owner@example.com")
	other := liveActivityRouteTestUser(t, app, "la-token-other@example.com")
	row := liveActivityRouteTestRow(t, app, owner.Id, "active")

	action := setLiveActivityTokenAction(t, app)
	recorder := callSetLiveActivityToken(t, action, other, row.Id, "new-token")

	if recorder.Code != 404 {
		t.Fatalf("status = %d, want 404", recorder.Code)
	}
	reloaded, err := app.FindRecordById("live_activities", row.Id)
	if err != nil {
		t.Fatal(err)
	}
	if reloaded.GetString("activity_push_token") == "new-token" {
		t.Fatal("token was set despite non-owner caller")
	}
}

func TestSetLiveActivityTokenRejectsInactiveRow(t *testing.T) {
	app := testApp(t)
	owner := liveActivityRouteTestUser(t, app, "la-token-ended@example.com")
	row := liveActivityRouteTestRow(t, app, owner.Id, "ended")

	action := setLiveActivityTokenAction(t, app)
	recorder := callSetLiveActivityToken(t, action, owner, row.Id, "new-token")

	if recorder.Code != 409 {
		t.Fatalf("status = %d, want 409 for a non-active activity", recorder.Code)
	}
}

func TestSetLiveActivityTokenSucceedsOnOwnedActiveRow(t *testing.T) {
	app := testApp(t)
	owner := liveActivityRouteTestUser(t, app, "la-token-success@example.com")
	row := liveActivityRouteTestRow(t, app, owner.Id, "active")

	action := setLiveActivityTokenAction(t, app)
	recorder := callSetLiveActivityToken(t, action, owner, row.Id, "new-token")

	if recorder.Code != 200 {
		t.Fatalf("status = %d, want 200; body: %s", recorder.Code, recorder.Body.String())
	}
	reloaded, err := app.FindRecordById("live_activities", row.Id)
	if err != nil {
		t.Fatal(err)
	}
	if reloaded.GetString("activity_push_token") != "new-token" {
		t.Fatalf("activity_push_token = %q, want %q", reloaded.GetString("activity_push_token"), "new-token")
	}
}

func TestEndLiveActivitySucceedsOnOwnedActiveRow(t *testing.T) {
	app := testApp(t)
	owner := liveActivityRouteTestUser(t, app, "la-end-success@example.com")
	row := liveActivityRouteTestRow(t, app, owner.Id, "active")

	action := endLiveActivityAction(t, app)
	recorder := callEndLiveActivity(t, action, owner, row.Id)

	if recorder.Code != 200 {
		t.Fatalf("status = %d, want 200; body: %s", recorder.Code, recorder.Body.String())
	}
	reloaded, err := app.FindRecordById("live_activities", row.Id)
	if err != nil {
		t.Fatal(err)
	}
	if reloaded.GetString("status") != "ended" {
		t.Fatalf("status = %q, want %q", reloaded.GetString("status"), "ended")
	}
	if reloaded.GetDateTime("ended_at").IsZero() {
		t.Fatal("ended_at was not set")
	}
}
