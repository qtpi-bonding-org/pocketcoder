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
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/router"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/operation"
)

// respondToElicitationAction mounts a real AgentDeps{} (a genuine
// *coordinator.Coordinator, no live Goose/Docker/Ollama behind it -- see
// endpoint_boundary_test.go's mountAllPocketCoderOperations for the same
// pattern) and returns just the "respondToElicitation" route's Action, the
// same way live_activities_test.go's endLiveActivityAction does for its op.
func respondToElicitationAction(t *testing.T, app core.App) operation.Action {
	t.Helper()
	registry := operation.NewRegistry()
	if _, err := AddAgentOperations(app, registry, AgentDeps{}); err != nil {
		t.Fatal(err)
	}
	route, ok := registry.Get("respondToElicitation")
	if !ok {
		t.Fatal("respondToElicitation operation not registered")
	}
	return route.Action
}

func callRespondToElicitation(t *testing.T, action operation.Action, auth *core.Record, chatID, elicitationID, body string) *httptest.ResponseRecorder {
	t.Helper()
	recorder := httptest.NewRecorder()
	url := "/api/pocketcoder/v1/chats/" + chatID + "/session/elicitation/" + elicitationID
	req := httptest.NewRequest("POST", url, strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.SetPathValue("chatId", chatID)
	req.SetPathValue("id", elicitationID)
	re := &core.RequestEvent{Event: router.Event{Response: recorder, Request: req}}
	re.Auth = auth
	// Mirrors endLiveActivity's test helper: a returned error still needs
	// router.ErrorHandler to become the actual HTTP response, exactly as
	// operationapi/server.go's dispatch does in production.
	if err := action(re); err != nil {
		router.ErrorHandler(recorder, req, err)
	}
	return recorder
}

func elicitationTestChat(t *testing.T, app core.App, email string) (*core.Record, *core.Record) {
	t.Helper()
	user := testUser(t, app, email)
	chatsColl, err := app.FindCollectionByNameOrId("chats")
	if err != nil {
		t.Fatal(err)
	}
	chat := core.NewRecord(chatsColl)
	chat.Set("user", user.Id)
	chat.Set("title", "Elicitation Test Chat")
	chat.Set("archived", false)
	if err := app.Save(chat); err != nil {
		t.Fatal(err)
	}
	return user, chat
}

func TestRespondToElicitationRejectsInvalidAction(t *testing.T) {
	app := testApp(t)
	owner, chat := elicitationTestChat(t, app, "elicit-bad-action@example.com")

	action := respondToElicitationAction(t, app)
	recorder := callRespondToElicitation(t, action, owner, chat.Id, "some-id", `{"action":"bogus"}`)

	if recorder.Code != 400 {
		t.Fatalf("status = %d, want 400 for an unrecognized action", recorder.Code)
	}
	if !strings.Contains(strings.ToLower(recorder.Body.String()), "action must be accept, decline, or cancel") {
		t.Fatalf("body = %q, want it to explain the allowed action values", recorder.Body.String())
	}
}

func TestRespondToElicitationReturnsNotFoundForUnknownID(t *testing.T) {
	app := testApp(t)
	owner, chat := elicitationTestChat(t, app, "elicit-unknown-id@example.com")

	action := respondToElicitationAction(t, app)
	// A well-formed, valid-action request for an id nothing registered as
	// pending -- exercises coordinator.ErrNoPendingElicitation's real
	// mapping to 404 without needing any live run/harness.
	recorder := callRespondToElicitation(t, action, owner, chat.Id, "never-registered", `{"action":"accept"}`)

	if recorder.Code != 404 {
		t.Fatalf("status = %d, want 404 for an elicitation id with nothing pending", recorder.Code)
	}
	if !strings.Contains(recorder.Body.String(), "Pending elicitation not found") {
		t.Fatalf("body = %q, want it to say the elicitation was not found", recorder.Body.String())
	}
}

func TestRespondToElicitationRejectsNonOwnedChat(t *testing.T) {
	app := testApp(t)
	_, chat := elicitationTestChat(t, app, "elicit-owner@example.com")
	other := testUser(t, app, "elicit-other@example.com")

	action := respondToElicitationAction(t, app)
	recorder := callRespondToElicitation(t, action, other, chat.Id, "some-id", `{"action":"accept"}`)

	if recorder.Code != 404 {
		t.Fatalf("status = %d, want 404 (requireOwnedRecord keeps non-owned and missing indistinguishable)", recorder.Code)
	}
}
