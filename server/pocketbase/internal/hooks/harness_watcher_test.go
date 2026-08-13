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
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/dockerapi"
)

// createTestHarnessInstance inserts a harness_instances row with sane
// defaults, overridden by whatever fields the caller supplies. If a row
// with the requested container_name already exists, it updates that row in
// place instead of violating the unique index on container_name.
func createTestHarnessInstance(t *testing.T, app core.App, overrides map[string]any) *core.Record {
	t.Helper()
	coll, err := app.FindCollectionByNameOrId("harness_instances")
	if err != nil {
		t.Fatal(err)
	}
	containerName := "test-instance-" + uuid.NewString()[:8]
	if v, ok := overrides["container_name"]; ok {
		containerName, _ = v.(string)
	}
	var rec *core.Record
	if existing, err := app.FindFirstRecordByFilter("harness_instances", "container_name = {:n}", map[string]any{"n": containerName}); err == nil && existing != nil {
		rec = existing
	} else {
		harness := createTestHarness(t, app, nil)
		rec = core.NewRecord(coll)
		rec.Set("harness", harness.Id)
		rec.Set("container_name", containerName)
		rec.Set("status", "running")
		rec.Set("managed", true)
	}
	for k, v := range overrides {
		rec.Set(k, v)
	}
	if err := app.Save(rec); err != nil {
		t.Fatal(err)
	}
	return rec
}

// waitForStatus polls until the given harness_instances row reaches the
// expected status, or fails the test after a short timeout.
func waitForStatus(t *testing.T, app core.App, id, want string) {
	t.Helper()
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		rec, err := app.FindRecordById("harness_instances", id)
		if err == nil && rec.GetString("status") == want {
			return
		}
		time.Sleep(10 * time.Millisecond)
	}
	rec, _ := app.FindRecordById("harness_instances", id)
	got := ""
	if rec != nil {
		got = rec.GetString("status")
	}
	t.Fatalf("status = %q, want %q (timed out waiting)", got, want)
}

// fakeEventClient is an eventSource test double: it lets tests emit
// synthetic docker events on demand and control what a reconciliation
// sweep's ListAll returns.
type fakeEventClient struct {
	ch            chan dockerapi.Event
	listAllResult []dockerapi.ContainerSummary
	listAllErr    error
}

func newFakeEventClient() *fakeEventClient {
	return &fakeEventClient{ch: make(chan dockerapi.Event, 16)}
}

func (f *fakeEventClient) Events(ctx context.Context) (<-chan dockerapi.Event, error) {
	return f.ch, nil
}

func (f *fakeEventClient) ListAll(ctx context.Context) ([]dockerapi.ContainerSummary, error) {
	return f.listAllResult, f.listAllErr
}

func (f *fakeEventClient) emit(ev dockerapi.Event) {
	f.ch <- ev
}

func TestWatcherUpdatesStatusOnDieAndStart(t *testing.T) {
	app := testApp(t)
	inst := createTestHarnessInstance(t, app, map[string]any{"container_name": "h1", "status": "running", "managed": true})
	fake := newFakeEventClient()
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go StartHarnessWatcher(ctx, app, fake)
	fake.emit(dockerapi.Event{Action: "die", ContainerName: "h1"})
	waitForStatus(t, app, inst.Id, "stopped")
	fake.emit(dockerapi.Event{Action: "start", ContainerName: "h1"})
	waitForStatus(t, app, inst.Id, "running")
	fake.emit(dockerapi.Event{Action: "destroy", ContainerName: "h1"})
	waitForStatus(t, app, inst.Id, "stopped")
}

func TestWatcherReconciliationMarksAbsentManagedRowsStopped(t *testing.T) {
	app := testApp(t)
	inst := createTestHarnessInstance(t, app, map[string]any{
		"container_name": "removed-during-update",
		"status":         "running",
		"managed":        true,
	})
	fake := newFakeEventClient()
	fake.listAllResult = nil
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go StartHarnessWatcher(ctx, app, fake)
	waitForStatus(t, app, inst.Id, "stopped")
}

func TestWatcherReconciliationSweepSkipsUnmanagedRows(t *testing.T) {
	app := testApp(t)
	unmanaged := createTestHarnessInstance(t, app, map[string]any{"container_name": "external-harness", "status": "running", "managed": false})
	fake := newFakeEventClient()
	fake.listAllResult = nil // absent unmanaged harnesses must remain untouched
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go StartHarnessWatcher(ctx, app, fake)
	time.Sleep(50 * time.Millisecond)
	rec, _ := app.FindRecordById("harness_instances", unmanaged.Id)
	if rec.GetString("status") != "running" {
		t.Error("the sweep must never touch a managed=false row, even if it's absent from ListAll")
	}
}
