package dockerapi

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestInspectParsesMountsAndNetworks(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/containers/pocketcoder-pocketbase/json" {
			t.Fatalf("unexpected path %q", r.URL.Path)
		}
		json.NewEncoder(w).Encode(map[string]any{
			"Mounts": []map[string]any{
				{"Destination": "/workspace", "Name": "myproject_goose_workspace"},
				{"Destination": "/app/pb_data", "Name": "myproject_pb_data"},
			},
			"NetworkSettings": map[string]any{
				"Networks": map[string]any{
					"myproject_pocketcoder-agent": map[string]any{},
					"myproject_pocketcoder-dashboard": map[string]any{},
				},
			},
		})
	}))
	defer srv.Close()

	c := &Client{baseURL: srv.URL, http: srv.Client()}
	insp, err := c.Inspect(context.Background(), "pocketcoder-pocketbase")
	if err != nil {
		t.Fatal(err)
	}
	found := false
	for _, m := range insp.Mounts {
		if m.Destination == "/workspace" && m.Name == "myproject_goose_workspace" {
			found = true
		}
	}
	if !found {
		t.Error("expected to find the /workspace mount with its real volume name")
	}
	if _, ok := insp.NetworkSettings.Networks["myproject_pocketcoder-agent"]; !ok {
		t.Error("expected to find the pocketcoder-agent network by its real prefixed name")
	}
}
