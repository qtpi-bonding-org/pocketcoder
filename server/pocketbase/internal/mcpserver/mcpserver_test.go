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

package mcpserver

import (
	"context"
	"errors"
	"testing"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	_ "github.com/qtpi-bonding-org/pocketcoder/backend/pb_migrations"
)

type mcpTestStore struct {
	collection *core.Collection
	records    []*core.Record
	saveErr    error
	saves      int
}

func (s *mcpTestStore) FindCollectionByNameOrId(string) (*core.Collection, error) {
	return s.collection, nil
}
func (s *mcpTestStore) FindRecordsByFilter(any, string, string, int, int, ...dbx.Params) ([]*core.Record, error) {
	return s.records, nil
}
func (s *mcpTestStore) Save(model core.Model) error {
	record, ok := model.(*core.Record)
	if !ok {
		return errors.New("mcpTestStore.Save: unsupported model type")
	}
	s.saves++
	if s.saveErr != nil {
		return s.saveErr
	}
	if len(s.records) == 0 {
		s.records = append(s.records, record)
	}
	return nil
}

func newMcpTestStore(t *testing.T, records ...*core.Record) *mcpTestStore {
	t.Helper()
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(app.Cleanup)
	collection, err := app.FindCollectionByNameOrId("mcp_servers")
	if err != nil {
		t.Fatal(err)
	}
	return &mcpTestStore{collection: collection, records: records}
}

func testResolver(gotName, gotImage *string, result string, err error) ImageResolver {
	return func(_ context.Context, name, image string) (string, error) {
		*gotName, *gotImage = name, image
		return result, err
	}
}

func TestRequestServer_ResolvesGivenImageAndCreatesPending(t *testing.T) {
	store := newMcpTestStore(t)
	var gotName, gotImage string
	result, err := RequestServer(context.Background(), store, testResolver(&gotName, &gotImage, "mcp/time@sha256:abc", nil), Request{ServerName: "time", Image: "custom:tag"})
	if err != nil {
		t.Fatal(err)
	}
	if result.Status != "pending" || result.Synced || gotName != "time" || gotImage != "custom:tag" {
		t.Fatalf("result=%+v resolver=(%q,%q)", result, gotName, gotImage)
	}
	if store.saves != 1 {
		t.Fatalf("Save calls = %d, want 1", store.saves)
	}
}

func TestRequestServer_ImageResolutionFailureDoesNotSave(t *testing.T) {
	store := newMcpTestStore(t)
	wantErr := errors.New("registry unavailable")
	_, err := RequestServer(context.Background(), store, testResolver(new(string), new(string), "", wantErr), Request{ServerName: "time"})
	if err == nil {
		t.Fatal("RequestServer returned nil error")
	}
	if store.saves != 0 {
		t.Fatalf("Save calls = %d, want 0", store.saves)
	}
}

func TestRequestServer_RejectsMissingName(t *testing.T) {
	store := newMcpTestStore(t)
	_, err := RequestServer(context.Background(), store, func(context.Context, string, string) (string, error) { return "unused", nil }, Request{})
	if err == nil {
		t.Fatal("RequestServer accepted an empty server name")
	}
	if store.saves != 0 {
		t.Fatalf("Save calls = %d, want 0", store.saves)
	}
}

func TestRequestServer_DuplicateSynchronizesExistingRecord(t *testing.T) {
	store := newMcpTestStore(t)
	resolver := func(context.Context, string, string) (string, error) { return "mcp/time@sha256:abc", nil }
	first, err := RequestServer(context.Background(), store, resolver, Request{ServerName: "time", Reason: "first"})
	if err != nil {
		t.Fatal(err)
	}
	second, err := RequestServer(context.Background(), store, resolver, Request{ServerName: "time", Reason: "updated", SessionID: "session-2", ConfigSchema: map[string]any{"key": "value"}})
	if err != nil {
		t.Fatal(err)
	}
	if second.ID != first.ID || !second.Synced || second.Status != "pending" {
		t.Fatalf("second result = %+v", second)
	}
	if len(store.records) != 1 {
		t.Fatalf("records = %d, want one", len(store.records))
	}
	record := store.records[0]
	if record.GetString("reason") != "updated" || record.GetString("requested_by") != "session-2" {
		t.Fatalf("record was not synchronized")
	}
}

func TestRequestServer_SyncSaveFailureIsReturned(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()
	collection, err := app.FindCollectionByNameOrId("mcp_servers")
	if err != nil {
		t.Fatal(err)
	}
	existing := core.NewRecord(collection)
	existing.Set("name", "time")
	existing.Set("status", "pending")
	store := &mcpTestStore{collection: collection, records: []*core.Record{existing}, saveErr: errors.New("write failed")}
	_, err = RequestServer(context.Background(), store, func(context.Context, string, string) (string, error) { return "mcp/time@sha256:abc", nil }, Request{ServerName: "time"})
	if err == nil {
		t.Fatal("RequestServer swallowed sync Save error")
	}
	if store.saves != 1 {
		t.Fatalf("Save calls = %d, want 1", store.saves)
	}
}
