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
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/dockerapi"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/operation"
)

type fakeContainerLister struct {
	summaries []dockerapi.ContainerSummary
	err       error
}

func (f fakeContainerLister) ListContainers(context.Context) ([]dockerapi.ContainerSummary, error) {
	return f.summaries, f.err
}

func TestListContainersAuthorizationBoundary(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()
	reg := operation.NewRegistry()
	AddLogOperations(reg, LogsDeps{Lister: fakeContainerLister{summaries: []dockerapi.ContainerSummary{{Names: []string{"/pocketcoder-sqlpage"}, State: "running", Status: "Up 1h"}}}})
	user := testUser(t, app, "list-containers-user-"+randomSuffix()+"@example.com")
	admin := newOllamaAdmin(t, app)
	for _, tc := range []struct {
		name string
		user *core.Record
		want int
	}{{"unauthenticated", nil, http.StatusUnauthorized}, {"authenticated non-admin", user, http.StatusForbidden}, {"authenticated admin", admin, http.StatusOK}} {
		t.Run(tc.name, func(t *testing.T) {
			rec := mountOllamaRequest(t, app, reg, http.MethodGet, "/api/pocketcoder/v1/containers", "", tc.user)
			if rec.Code != tc.want {
				t.Fatalf("status=%d body=%s, want %d", rec.Code, rec.Body, tc.want)
			}
		})
	}
}

func TestListContainersReturnsSummaries(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()
	reg := operation.NewRegistry()
	AddLogOperations(reg, LogsDeps{Lister: fakeContainerLister{summaries: []dockerapi.ContainerSummary{{Names: []string{"/pocketcoder-sqlpage"}, State: "running", Status: "Up 1h"}, {Names: []string{"/pocketcoder-ollama"}, State: "exited", Status: "Exited (0)"}}}})
	rec := mountOllamaRequest(t, app, reg, http.MethodGet, "/api/pocketcoder/v1/containers", "", newOllamaAdmin(t, app))
	if rec.Code != http.StatusOK {
		t.Fatalf("status=%d body=%s", rec.Code, rec.Body)
	}
	var body struct {
		Containers []struct {
			Name   string
			State  string
			Status string
		}
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	if len(body.Containers) != 2 || body.Containers[0].Name != "pocketcoder-sqlpage" {
		t.Fatalf("unexpected body: %+v", body.Containers)
	}
}

func TestListContainersSurfacesListerError(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()
	reg := operation.NewRegistry()
	AddLogOperations(reg, LogsDeps{Lister: fakeContainerLister{err: errors.New("proxy unreachable")}})
	rec := mountOllamaRequest(t, app, reg, http.MethodGet, "/api/pocketcoder/v1/containers", "", newOllamaAdmin(t, app))
	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status=%d, want 500", rec.Code)
	}
}

type fakeLogSource struct {
	body io.ReadCloser
	err  error
}

func (f fakeLogSource) StreamLogs(context.Context, string) (io.ReadCloser, error) {
	return f.body, f.err
}

func newLogsAdmin(t *testing.T, app *tests.TestApp) *core.Record {
	t.Helper()
	u := testUser(t, app, "logs-admin-"+randomSuffix()+"@example.com")
	u.Set("role", "admin")
	if err := app.Save(u); err != nil {
		t.Fatal(err)
	}
	return u
}

func mountLogsRequest(t *testing.T, app *tests.TestApp, source dockerLogSource, containerName string, user *core.Record) *httptest.ResponseRecorder {
	t.Helper()
	router, err := apis.NewRouter(app)
	if err != nil {
		t.Fatal(err)
	}
	e := &core.ServeEvent{App: app, Router: router}
	reg := operation.NewRegistry()
	AddLogOperations(reg, LogsDeps{Source: source})
	operation.MountForTests(e, reg.Routes())
	token, err := user.NewAuthToken()
	if err != nil {
		t.Fatal(err)
	}
	req := httptest.NewRequest(http.MethodGet, "/api/pocketcoder/v1/logs/"+containerName, nil)
	req.Header.Set("Authorization", token)
	mux, err := e.Router.BuildMux()
	if err != nil {
		t.Fatal(err)
	}
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)
	return rec
}

func TestStreamContainerLogsInvalidContainerName(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()
	rec := mountLogsRequest(t, app, fakeLogSource{}, "bad*name", newLogsAdmin(t, app))
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status=%d", rec.Code)
	}
}

func TestStreamContainerLogsSourceUnavailableReturnsNotFound(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()
	source := fakeLogSource{err: fmt.Errorf("%w: docker proxy returned 404", errLogsUnavailable)}
	rec := mountLogsRequest(t, app, source, "missing-container", newLogsAdmin(t, app))
	if rec.Code != http.StatusNotFound {
		t.Fatalf("status=%d", rec.Code)
	}
}

func TestStreamContainerLogsSourceErrorReturnsInternalError(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()
	source := fakeLogSource{err: errors.New("connection refused")}
	rec := mountLogsRequest(t, app, source, "good-container", newLogsAdmin(t, app))
	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status=%d", rec.Code)
	}
}

func TestStreamContainerLogsStreamsDecodedFrames(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	var raw []byte
	for _, line := range []string{"hello\n", "world\n"} {
		header := make([]byte, 8)
		header[0] = 1
		size := len(line)
		header[4] = byte(size >> 24)
		header[5] = byte(size >> 16)
		header[6] = byte(size >> 8)
		header[7] = byte(size)
		raw = append(raw, header...)
		raw = append(raw, line...)
	}
	source := fakeLogSource{body: io.NopCloser(strings.NewReader(string(raw)))}
	rec := mountLogsRequest(t, app, source, "good-container", newLogsAdmin(t, app))
	if rec.Code != http.StatusOK {
		t.Fatalf("status=%d body=%s", rec.Code, rec.Body)
	}
	body := rec.Body.String()
	if !strings.Contains(body, "data: hello") || !strings.Contains(body, "data: world") {
		t.Fatalf("body=%q", body)
	}
}
