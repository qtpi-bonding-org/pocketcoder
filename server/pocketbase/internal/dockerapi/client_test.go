package dockerapi

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestLoadImageStreamsArchiveAndAcceptsDockerStatus(t *testing.T) {
	payload := []byte("compressed-image-archive")
	var received []byte
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/images/load" || r.URL.Query().Get("quiet") != "1" {
			t.Fatalf("unexpected load URL %s", r.URL.String())
		}
		received, _ = io.ReadAll(r.Body)
		_, _ = w.Write([]byte("{\"stream\":\"Loaded image\"}\n"))
	}))
	defer srv.Close()
	c := &Client{baseURL: srv.URL, http: srv.Client()}
	if err := c.LoadImage(context.Background(), bytes.NewReader(payload)); err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(received, payload) {
		t.Fatalf("received payload %q, want %q", received, payload)
	}
}

func TestLoadImageSurfacesDockerStreamError(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"errorDetail":{"message":"invalid tar"},"error":"invalid tar"}`))
	}))
	defer srv.Close()
	c := &Client{baseURL: srv.URL, http: srv.Client()}
	err := c.LoadImage(context.Background(), bytes.NewReader([]byte("bad")))
	if err == nil || !strings.Contains(err.Error(), "invalid tar") {
		t.Fatalf("error = %v, want Docker stream error", err)
	}
}

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
					"myproject_pocketcoder-agent":     map[string]any{},
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

func TestPullImageCallsImagesCreateEndpoint(t *testing.T) {
	var gotPath, gotQuery string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotPath = r.URL.Path
		gotQuery = r.URL.RawQuery
		w.Write([]byte(`{"status":"Pull complete"}`))
	}))
	defer srv.Close()
	c := &Client{baseURL: srv.URL, http: srv.Client()}
	if err := c.PullImage(context.Background(), "example.com/harness:1.0"); err != nil {
		t.Fatal(err)
	}
	if gotPath != "/images/create" {
		t.Errorf("path = %q, want /images/create", gotPath)
	}
	if gotQuery != "fromImage=example.com%2Fharness%3A1.0" {
		t.Errorf("query = %q", gotQuery)
	}
}

func TestPullImageSurfacesNoSuchImage(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNotFound)
		w.Write([]byte(`{"message":"No such image"}`))
	}))
	defer srv.Close()
	c := &Client{baseURL: srv.URL, http: srv.Client()}
	err := c.PullImage(context.Background(), "nonexistent:latest")
	if err == nil {
		t.Fatal("expected an error for a nonexistent image")
	}
}

func TestImageExistsDistinguishesLocalImageFromMissingImage(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/images/pocketcoder-harness-codex:1.1.9/json" {
			w.Write([]byte(`{"Id":"sha256:abc"}`))
			return
		}
		w.WriteHeader(http.StatusNotFound)
	}))
	defer srv.Close()
	c := &Client{baseURL: srv.URL, http: srv.Client()}
	exists, err := c.ImageExists(context.Background(), "pocketcoder-harness-codex:1.1.9")
	if err != nil || !exists {
		t.Fatalf("ImageExists(local) = %v, %v; want true, nil", exists, err)
	}
	exists, err = c.ImageExists(context.Background(), "missing:latest")
	if err != nil || exists {
		t.Fatalf("ImageExists(missing) = %v, %v; want false, nil", exists, err)
	}
}

func TestCreateAttachesVolumeAndNetworksInOneCall(t *testing.T) {
	var body map[string]any
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		json.NewDecoder(r.Body).Decode(&body)
		json.NewEncoder(w).Encode(map[string]any{"Id": "abc123"})
	}))
	defer srv.Close()
	c := &Client{baseURL: srv.URL, http: srv.Client()}
	id, err := c.Create(context.Background(), "my-harness", CreateSpec{
		Image: "example.com/harness:1.0", Cmd: []string{"/adapter"},
		VolumeName: "myproject_goose_workspace", VolumeDest: "/workspace",
		NetworkNames:   []string{"myproject_pocketcoder-agent", "pocketcoder-model"},
		NetworkAliases: map[string][]string{"pocketcoder-model": {"ollama"}},
		Labels:         map[string]string{"pc_managed": "pocketcoder"},
	})
	if err != nil {
		t.Fatal(err)
	}
	if id != "abc123" {
		t.Errorf("id = %q, want abc123", id)
	}
	hostConfig := body["HostConfig"].(map[string]any)
	binds := hostConfig["Binds"].([]any)
	if len(binds) != 1 || binds[0] != "myproject_goose_workspace:/workspace" {
		t.Errorf("Binds = %v, want [myproject_goose_workspace:/workspace]", binds)
	}
	labels := body["Labels"].(map[string]any)
	if labels["pc_managed"] != "pocketcoder" {
		t.Errorf("Labels = %v, want top-level pc_managed label", labels)
	}
	netConfig := body["NetworkingConfig"].(map[string]any)
	endpoints := netConfig["EndpointsConfig"].(map[string]any)
	if _, ok := endpoints["myproject_pocketcoder-agent"]; !ok {
		t.Error("expected the network attached via NetworkingConfig in the same create call (NETWORKS=0 blocks a follow-up connect)")
	}
	if _, ok := endpoints["pocketcoder-model"]; !ok {
		t.Error("expected the local-model network attached in the same create call")
	}
	modelEndpoint := endpoints["pocketcoder-model"].(map[string]any)
	aliases := modelEndpoint["Aliases"].([]any)
	if len(aliases) != 1 || aliases[0] != "ollama" {
		t.Errorf("pocketcoder-model aliases = %v, want [ollama]", aliases)
	}
	restartPolicy := hostConfig["RestartPolicy"].(map[string]any)
	if restartPolicy["Name"] != "unless-stopped" {
		t.Errorf("RestartPolicy.Name = %v, want unless-stopped — every other service in docker-compose.yml restarts automatically; a provisioned harness must too, since nothing else brings it back after a host reboot", restartPolicy["Name"])
	}
}

func TestStartCallsContainersStartEndpoint(t *testing.T) {
	var gotPath string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotPath = r.URL.Path
		w.WriteHeader(http.StatusNoContent)
	}))
	defer srv.Close()
	c := &Client{baseURL: srv.URL, http: srv.Client()}
	if err := c.Start(context.Background(), "my-harness"); err != nil {
		t.Fatal(err)
	}
	if gotPath != "/containers/my-harness/start" {
		t.Errorf("path = %q, want /containers/my-harness/start", gotPath)
	}
}

func TestEventsStreamsDieAndStartActions(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/events" {
			t.Fatalf("unexpected path %q", r.URL.Path)
		}
		flusher := w.(http.Flusher)
		w.Write([]byte(`{"Type":"container","Action":"start","Actor":{"Attributes":{"name":"my-harness"}}}` + "\n"))
		flusher.Flush()
		w.Write([]byte(`{"Type":"container","Action":"die","Actor":{"Attributes":{"name":"my-harness"}}}` + "\n"))
		flusher.Flush()
	}))
	defer srv.Close()
	c := &Client{baseURL: srv.URL, http: srv.Client()}
	ch, err := c.Events(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	e1 := <-ch
	if e1.Action != "start" || e1.ContainerName != "my-harness" {
		t.Errorf("first event = %+v, want start/my-harness", e1)
	}
	e2 := <-ch
	if e2.Action != "die" || e2.ContainerName != "my-harness" {
		t.Errorf("second event = %+v, want die/my-harness", e2)
	}
}

func TestListAllReturnsNamesAndState(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode([]map[string]any{
			{"Names": []string{"/my-harness"}, "State": "running"},
		})
	}))
	defer srv.Close()
	c := &Client{baseURL: srv.URL, http: srv.Client()}
	all, err := c.ListAll(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if len(all) != 1 || all[0].State != "running" {
		t.Errorf("ListAll = %+v", all)
	}
}

func TestEventsStopsOnContextCancel(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/events" {
			t.Fatalf("unexpected path %q", r.URL.Path)
		}
		flusher := w.(http.Flusher)
		w.Write([]byte(`{"Type":"container","Action":"start","Actor":{"Attributes":{"name":"my-harness"}}}` + "\n"))
		flusher.Flush()
		// Keep the connection alive; the context cancellation should stop the reading
		<-r.Context().Done()
	}))
	defer srv.Close()
	ctx, cancel := context.WithCancel(context.Background())
	c := &Client{baseURL: srv.URL, http: srv.Client()}
	ch, err := c.Events(ctx)
	if err != nil {
		t.Fatal(err)
	}
	// Read the first event
	e1 := <-ch
	if e1.Action != "start" || e1.ContainerName != "my-harness" {
		t.Errorf("first event = %+v, want start/my-harness", e1)
	}
	// Cancel the context
	cancel()
	// The channel should close without hanging
	_, ok := <-ch
	if ok {
		t.Error("expected channel to close after context cancellation")
	}
}
