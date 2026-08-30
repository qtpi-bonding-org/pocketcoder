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
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/router"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/operation"
)

func deleteProDataAction(t *testing.T, app core.App) operation.Action {
	t.Helper()
	registry := operation.NewRegistry()
	AddProDataOperations(app, registry)
	route, ok := registry.Get("deleteProData")
	if !ok {
		t.Fatal("deleteProData operation not registered")
	}
	return route.Action
}

func callDeleteProData(t *testing.T, action operation.Action, auth *core.Record) *httptest.ResponseRecorder {
	t.Helper()
	recorder := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodDelete, "/api/pocketcoder/v1/pro-data", nil)
	re := &core.RequestEvent{Event: router.Event{Response: recorder, Request: req}}
	re.Auth = auth
	if err := action(re); err != nil {
		router.ErrorHandler(recorder, req, err)
	}
	return recorder
}

func TestDeleteProDataSucceedsWhenNoRelayIsConfigured(t *testing.T) {
	t.Setenv("PN_URL", "")
	app := testApp(t)
	caller := testUser(t, app, "pro-data-no-relay@example.com")

	action := deleteProDataAction(t, app)
	recorder := callDeleteProData(t, action, caller)

	if recorder.Code != 204 {
		t.Fatalf("status = %d, want 204 when PN_URL is unset (nothing to purge); body=%s", recorder.Code, recorder.Body.String())
	}
}

func TestDeleteProDataFailsWhenRelayIsUnreachable(t *testing.T) {
	t.Setenv("PN_URL", "http://127.0.0.1:1") // nothing listens here -- connection refused
	app := testApp(t)
	caller := testUser(t, app, "pro-data-unreachable@example.com")

	action := deleteProDataAction(t, app)
	recorder := callDeleteProData(t, action, caller)

	if recorder.Code == 204 {
		t.Fatal("want a failure status when the relay is unreachable, not 204 -- this purge is not best-effort")
	}
}

func TestDeleteProDataFailsWhenRelayRejectsTheRequest(t *testing.T) {
	relay := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusForbidden)
	}))
	defer relay.Close()
	t.Setenv("PN_URL", relay.URL)
	app := testApp(t)
	caller := testUser(t, app, "pro-data-rejected@example.com")

	action := deleteProDataAction(t, app)
	recorder := callDeleteProData(t, action, caller)

	if recorder.Code == 204 {
		t.Fatal("want a failure status when push-relay rejects the purge, not 204")
	}
}

func TestDeleteProDataSendsTheCallersOwnUserIDAndTheRelaySecret(t *testing.T) {
	t.Setenv("PN_RELAY_SECRET", "test-relay-secret")
	var gotHeader, gotSecret, gotBody string
	relay := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotHeader = r.Header.Get("X-Relay-Delete-Pro-Data")
		gotSecret = r.Header.Get("X-Relay-Secret")
		buf := make([]byte, 1024)
		n, _ := r.Body.Read(buf)
		gotBody = string(buf[:n])
		w.WriteHeader(http.StatusOK)
	}))
	defer relay.Close()
	t.Setenv("PN_URL", relay.URL)
	app := testApp(t)
	caller := testUser(t, app, "pro-data-headers@example.com")

	action := deleteProDataAction(t, app)
	recorder := callDeleteProData(t, action, caller)

	if recorder.Code != 204 {
		t.Fatalf("status = %d, want 204; body=%s", recorder.Code, recorder.Body.String())
	}
	if gotHeader != "1" {
		t.Fatalf("X-Relay-Delete-Pro-Data = %q, want \"1\"", gotHeader)
	}
	if gotSecret != "test-relay-secret" {
		t.Fatalf("X-Relay-Secret = %q, want the configured PN_RELAY_SECRET", gotSecret)
	}
	if !strings.Contains(gotBody, caller.Id) {
		t.Fatalf("request body = %q, want it to contain the caller's own id %q", gotBody, caller.Id)
	}
}
