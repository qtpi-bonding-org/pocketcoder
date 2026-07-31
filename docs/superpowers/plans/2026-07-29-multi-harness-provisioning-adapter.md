# Multi-Harness Provisioning + stdio-ws Adapter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make a `harnesses` catalog row with `container_image`/`launch_template` actually turn into a running, dialable container — provisioned on demand, tracked reactively, and reachable uniformly over websocket even when the underlying binary only speaks stdio. This is Plan 2 of the multi-harness selection design; it assumes Plan 1 (`docs/superpowers/plans/2026-07-29-multi-harness-schema-coordinator.md`) has already landed the schema (`harness_instances`, the capability flags) and the coordinator's `establishSession`/`Target`/`buildSessionProfile` resolution — this plan fills in the one gap Plan 1 explicitly left open: what happens when `buildSessionProfile` resolves a harness with no matching `harness_instances` row yet.

**Architecture:** A small, dependency-free Docker Engine API client (`internal/dockerapi`) talking to the existing `docker-socket-proxy-write` sidecar, following the same fixed-dial HTTP pattern `hooks/docker.go`'s `restartContainer` already uses — not a full SDK, just the handful of calls this design needs (inspect, pull, create, start, events). Provisioning is asynchronous: `buildSessionProfile` finding no instance creates a `pending` row and kicks off a background provision, returning a distinct "harness starting" state rather than blocking an HTTP request on an image pull. A separate small Go binary (`harness-adapter`) is the bundled stdio↔websocket bridge for stdio-native harnesses, standardized against `internal/agent/acp/websocket.go`'s existing wire shape so the coordinator's dial path needs no changes to talk to it.

**Tech Stack:** Go (PocketBase backend + a small standalone adapter binary), the Docker Engine HTTP API (via `docker-socket-proxy-write`), `coder/websocket` (already a dependency, used identically to the existing coordinator-side ACP websocket client).

## Global Constraints

- No migrations, no backward compatibility — same as Plan 1; there are no existing deployments.
- Every new Docker API call goes through `docker-socket-proxy-write`, never a direct socket — follow `hooks/docker.go`'s existing `DOCKER_HOST`/fixed-dial pattern exactly.
- Design spec: `docs/superpowers/specs/2026-07-29-multi-harness-selection-design.md` — this plan implements §5.1 (both subsections), §5.3, §5.4, §5.4.1, and documents §5.5 (no code change there). Read all of these before starting.
- The adapter must never parse or filter ACP JSON-RPC content — reframe only (§5.4.1). Any code that inspects a message's `method`/`params` beyond byte-copying is a design violation, not an optimization.
- Two independent size limits must be raised, not one: the WS frame limit (`coder/websocket`, 32 KiB default) and the stdio line-read limit (Go's `bufio.Scanner`, 64 KiB default) — both to the same generous ceiling (64 MiB, matching `internal/agent/acp/websocket.go:131`'s existing precedent).

---

## File Structure

| File | Responsibility |
|---|---|
| `server/pocketbase/internal/dockerapi/client.go` | Minimal Docker Engine API client over the socket proxy: `Inspect`, `PullImage`, `Create`, `Start`, `ListAll`, `Events`. |
| `server/pocketbase/internal/dockerapi/client_test.go` | Tests against a fake HTTP server standing in for the proxy. |
| `server/pocketbase/internal/hooks/harness_provision.go` | Resolves the real `goose_workspace` volume / `pocketcoder-agent` network names once at startup (§5.1.2); `ProvisionHarnessInstance` — creates a `harness_instances` row, pulls the image, creates+starts the container from `launch_template`, updates `status`/`last_error`. |
| `server/pocketbase/internal/hooks/harness_provision_test.go` | Tests for provisioning, including the image-pull-failure → `last_error` path. |
| `server/pocketbase/internal/hooks/harness_watcher.go` | Docker event-stream subscriber updating `harness_instances.status`; startup reconciliation sweep (§5.3). |
| `server/pocketbase/internal/hooks/harness_watcher_test.go` | Tests against a fake event stream. |
| `server/pocketbase/internal/api/profile.go` | Modify (from Plan 1's version): when `buildSessionProfile` resolves a harness with no matching `harness_instances` row, create one (`pending`) and trigger `ProvisionHarnessInstance` in the background instead of leaving `Target` silently empty. |
| `docker-compose.yml` | Modify: `docker-socket-proxy-write` gains `IMAGES=1`; `goose_workspace` volume and `pocketcoder-agent` network gain explicit `name:` values (§5.1.2's "simpler fix"). |
| `server/harness-adapter/main.go` | New standalone binary: bundled stdio↔websocket adapter, one instance built into every stdio-native harness's own container image. |
| `server/harness-adapter/adapter.go` | The actual bridge: per incoming WS connection, spawn the configured binary as a stdio subprocess, relay frames both directions with the two raised size limits. |
| `server/harness-adapter/adapter_test.go` | Framing round-trip tests, including the large-message regression tests. |
| `server/harness-adapter/Dockerfile` | Example Dockerfile showing how a stdio-native harness's image bundles the adapter (referenced by a `harnesses.launch_template`, not built into the base image itself). |

---

## Task 1: `dockerapi` — `Inspect`, following `hooks/docker.go`'s existing proxy-dial pattern

**Files:**
- Create: `server/pocketbase/internal/dockerapi/client.go`
- Test: `server/pocketbase/internal/dockerapi/client_test.go`

**Interfaces:**
- Produces: `type Client struct{...}`; `func New() *Client` (reads `DOCKER_HOST` env, same default as `hooks/docker.go`); `func (c *Client) Inspect(ctx context.Context, containerName string) (ContainerInspect, error)`; `type ContainerInspect struct { Mounts []Mount; NetworkSettings struct{ Networks map[string]NetworkEndpoint } }`, `type Mount struct{ Destination, Name string }`, `type NetworkEndpoint struct{}`. Consumed by Task 2 (volume/network name resolution).

- [ ] **Step 1: Write the failing test**

```go
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd server/pocketbase/internal/dockerapi && go test -run TestInspectParsesMountsAndNetworks -v`
Expected: FAIL — package/`Client` doesn't exist

- [ ] **Step 3: Implement `Client`/`Inspect`**

```go
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

// @pocketcoder-core: Docker Engine API client for harness provisioning,
// talking only to docker-socket-proxy-write — never the raw socket. Follows
// the same fixed-dial-to-proxy pattern as hooks/docker.go's
// restartContainer, extended to the handful of extra calls provisioning
// needs (inspect, pull, create, start, events).
package dockerapi

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"os"
	"strings"
	"time"
)

const defaultDockerHost = "tcp://docker-socket-proxy-write:2375"

type Client struct {
	baseURL string
	http    *http.Client
}

func New() *Client {
	host := os.Getenv("DOCKER_HOST")
	if host == "" {
		host = defaultDockerHost
	}
	proxyAddr := strings.TrimPrefix(host, "tcp://")
	return &Client{
		baseURL: "http://" + proxyAddr,
		http: &http.Client{
			Transport: &http.Transport{
				DialContext: func(ctx context.Context, network, addr string) (net.Conn, error) {
					return net.Dial("tcp", proxyAddr)
				},
			},
			Timeout: 30 * time.Second,
		},
	}
}

type Mount struct {
	Destination, Name string
}

type NetworkEndpoint struct{}

type ContainerInspect struct {
	Mounts          []Mount
	NetworkSettings struct {
		Networks map[string]NetworkEndpoint
	}
}

func (c *Client) Inspect(ctx context.Context, containerName string) (ContainerInspect, error) {
	var insp ContainerInspect
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.baseURL+"/containers/"+containerName+"/json", nil)
	if err != nil {
		return insp, err
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return insp, fmt.Errorf("inspect %s: %w", containerName, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 400 {
		return insp, fmt.Errorf("inspect %s: docker API returned %s", containerName, resp.Status)
	}
	if err := json.NewDecoder(resp.Body).Decode(&insp); err != nil {
		return insp, fmt.Errorf("decode inspect response: %w", err)
	}
	return insp, nil
}
```

(The test constructs `&Client{baseURL: srv.URL}` directly rather than via `New()`, bypassing the proxy-dial transport, so it can point at an `httptest.Server` — add an unexported field-only constructor path if Go's zero-value struct literal isn't accessible from the test file due to package visibility; it is here, since the test lives in the same package.)

- [ ] **Step 4: Run test to verify it passes**

Run: `cd server/pocketbase/internal/dockerapi && go test -run TestInspectParsesMountsAndNetworks -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add server/pocketbase/internal/dockerapi/client.go server/pocketbase/internal/dockerapi/client_test.go
git commit -m "feat(dockerapi): add minimal Docker Engine API client with Inspect"
```

---

## Task 2: `dockerapi` — `PullImage`, `Create`, `Start`

**Files:**
- Modify: `server/pocketbase/internal/dockerapi/client.go`
- Test: `server/pocketbase/internal/dockerapi/client_test.go`

**Interfaces:**
- Consumes: `Client` (Task 1).
- Produces: `func (c *Client) PullImage(ctx context.Context, image string) error`; `type CreateSpec struct{ Image string; Cmd []string; Env []string; VolumeName, VolumeDest, NetworkName string; ExposedPort string }`; `func (c *Client) Create(ctx context.Context, name string, spec CreateSpec) (containerID string, err error)`; `func (c *Client) Start(ctx context.Context, containerName string) error`. Consumed by Task 4 (`ProvisionHarnessInstance`).

- [ ] **Step 1: Write the failing tests**

```go
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

func TestCreateAttachesVolumeAndNetworkInOneCall(t *testing.T) {
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
		NetworkName: "myproject_pocketcoder-agent",
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
	netConfig := body["NetworkingConfig"].(map[string]any)
	endpoints := netConfig["EndpointsConfig"].(map[string]any)
	if _, ok := endpoints["myproject_pocketcoder-agent"]; !ok {
		t.Error("expected the network attached via NetworkingConfig in the same create call (NETWORKS=0 blocks a follow-up connect)")
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd server/pocketbase/internal/dockerapi && go test -run 'TestPullImage|TestCreate|TestStart' -v`
Expected: FAIL — methods undefined

- [ ] **Step 3: Implement `PullImage`, `Create`, `Start`**

```go
import (
	"bytes"
	"io"
	"net/url"
)

func (c *Client) PullImage(ctx context.Context, image string) error {
	q := url.Values{"fromImage": {image}}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/images/create?"+q.Encode(), nil)
	if err != nil {
		return err
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return fmt.Errorf("pull image %s: %w", image, err)
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 400 {
		return fmt.Errorf("pull image %s: docker API returned %s: %s", image, resp.Status, string(body))
	}
	return nil
}

type CreateSpec struct {
	Image                                     string
	Cmd                                        []string
	Env                                        []string
	VolumeName, VolumeDest, NetworkName        string
	ExposedPort                                string
}

func (c *Client) Create(ctx context.Context, name string, spec CreateSpec) (string, error) {
	payload := map[string]any{
		"Image": spec.Image,
		"Cmd":   spec.Cmd,
		"Env":   spec.Env,
		"HostConfig": map[string]any{
			"Binds": []string{spec.VolumeName + ":" + spec.VolumeDest},
		},
		"NetworkingConfig": map[string]any{
			"EndpointsConfig": map[string]any{
				spec.NetworkName: map[string]any{},
			},
		},
	}
	buf, err := json.Marshal(payload)
	if err != nil {
		return "", err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/containers/create?name="+url.QueryEscape(name), bytes.NewReader(buf))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := c.http.Do(req)
	if err != nil {
		return "", fmt.Errorf("create container %s: %w", name, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 400 {
		body, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("create container %s: docker API returned %s: %s", name, resp.Status, string(body))
	}
	var out struct{ Id string }
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return "", fmt.Errorf("decode create response: %w", err)
	}
	return out.Id, nil
}

func (c *Client) Start(ctx context.Context, containerName string) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/containers/"+containerName+"/start", nil)
	if err != nil {
		return err
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return fmt.Errorf("start container %s: %w", containerName, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 400 {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("start container %s: docker API returned %s: %s", containerName, resp.Status, string(body))
	}
	return nil
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd server/pocketbase/internal/dockerapi && go test ./... -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add server/pocketbase/internal/dockerapi/client.go server/pocketbase/internal/dockerapi/client_test.go
git commit -m "feat(dockerapi): add PullImage, Create, and Start"
```

---

## Task 3: `dockerapi` — `Events` stream and `ListAll`

**Files:**
- Modify: `server/pocketbase/internal/dockerapi/client.go`
- Test: `server/pocketbase/internal/dockerapi/client_test.go`

**Interfaces:**
- Consumes: `Client` (Task 1).
- Produces: `type Event struct{ Type, Action, ContainerName string }`; `func (c *Client) Events(ctx context.Context) (<-chan Event, error)`; `type ContainerSummary struct{ Names []string; State string }`; `func (c *Client) ListAll(ctx context.Context) ([]ContainerSummary, error)`. Consumed by Task 6 (the watcher).

- [ ] **Step 1: Write the failing tests**

```go
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd server/pocketbase/internal/dockerapi && go test -run 'TestEvents|TestListAll' -v`
Expected: FAIL — methods undefined

- [ ] **Step 3: Implement `Events`/`ListAll`**

```go
import "bufio"

type Event struct {
	Type, Action, ContainerName string
}

func (c *Client) Events(ctx context.Context) (<-chan Event, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.baseURL+"/events", nil)
	if err != nil {
		return nil, err
	}
	// Long-lived streaming GET — no client-side timeout for this one call.
	streamClient := &http.Client{Transport: c.http.Transport}
	resp, err := streamClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("subscribe to docker events: %w", err)
	}
	ch := make(chan Event)
	go func() {
		defer resp.Body.Close()
		defer close(ch)
		scanner := bufio.NewScanner(resp.Body)
		for scanner.Scan() {
			var raw struct {
				Type   string
				Action string
				Actor  struct {
					Attributes map[string]string
				}
			}
			if err := json.Unmarshal(scanner.Bytes(), &raw); err != nil {
				continue
			}
			select {
			case ch <- Event{Type: raw.Type, Action: raw.Action, ContainerName: raw.Actor.Attributes["name"]}:
			case <-ctx.Done():
				return
			}
		}
	}()
	return ch, nil
}

type ContainerSummary struct {
	Names []string
	State string
}

func (c *Client) ListAll(ctx context.Context) ([]ContainerSummary, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.baseURL+"/containers/json?all=1", nil)
	if err != nil {
		return nil, err
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("list containers: %w", err)
	}
	defer resp.Body.Close()
	var out []ContainerSummary
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return nil, fmt.Errorf("decode list response: %w", err)
	}
	return out, nil
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd server/pocketbase/internal/dockerapi && go test ./... -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add server/pocketbase/internal/dockerapi/client.go server/pocketbase/internal/dockerapi/client_test.go
git commit -m "feat(dockerapi): add Events stream and ListAll"
```

---

## Task 4: docker-compose — `IMAGES=1` and pinned volume/network names

**Files:**
- Modify: `docker-compose.yml`

**Interfaces:**
- Produces: `docker-socket-proxy-write` can pull images; `goose_workspace`/`pocketcoder-agent` have stable, predictable real Docker object names, matching what Task 5's resolver expects as a fallback-free default.

- [ ] **Step 1: Edit `docker-compose.yml`**

Change the `docker-socket-proxy-write` service's `IMAGES=0` to `IMAGES=1` (§5.1.1 — defensible since `harnesses.container_image` is superuser-only, and `POST=1`/`CONTAINERS=1` already permit deleting any container, so this doesn't cross a new trust boundary).

Add explicit `name:` to the top-level `volumes:`/`networks:` entries for `goose_workspace` and `pocketcoder-agent`:

```yaml
volumes:
  goose_workspace:
    name: pocketcoder_goose_workspace
  # ...

networks:
  pocketcoder-agent:
    name: pocketcoder-agent
  # ...
```

- [ ] **Step 2: Verify the compose file is still valid**

Run: `docker compose config --quiet` (or `docker-compose config --quiet` depending on the installed CLI) from the repo root.
Expected: no output, exit code 0 — confirms the YAML parses and no service references break.

- [ ] **Step 3: Commit**

```bash
git add docker-compose.yml
git commit -m "feat(compose): allow image pulls for harness provisioning, pin volume/network names"
```

---

## Task 5: Resolve the real volume/network names at startup

**Files:**
- Create: `server/pocketbase/internal/hooks/harness_provision.go`
- Test: `server/pocketbase/internal/hooks/harness_provision_test.go`

**Interfaces:**
- Consumes: `dockerapi.Client.Inspect` (Task 1); Task 4's pinned names (as the expected, common-case result — this resolver is a belt-and-suspenders fallback per §5.1.2, not dead code, since a box that hasn't picked up the compose change yet still needs it).
- Produces: `func ResolveWorkspaceVolumeAndNetwork(ctx context.Context, client *dockerapi.Client) (volumeName, networkName string, err error)`. Consumed by Task 6 (`ProvisionHarnessInstance`).

- [ ] **Step 1: Write the failing tests**

```go
package hooks

func TestResolveWorkspaceVolumeAndNetworkMatchesByDestinationAndSuffix(t *testing.T) {
	fake := &fakeInspectClient{ // small test double implementing just Inspect, following whatever fake-interface style dockerapi_test already established
		insp: dockerapi.ContainerInspect{
			Mounts: []dockerapi.Mount{
				{Destination: "/app/pb_data", Name: "proj_pb_data"},
				{Destination: "/workspace", Name: "proj_goose_workspace"},
			},
		},
	}
	fake.insp.NetworkSettings.Networks = map[string]dockerapi.NetworkEndpoint{
		"proj_pocketcoder-dashboard": {},
		"proj_pocketcoder-agent":     {},
	}
	vol, net, err := ResolveWorkspaceVolumeAndNetwork(context.Background(), fake)
	if err != nil {
		t.Fatal(err)
	}
	if vol != "proj_goose_workspace" {
		t.Errorf("volume = %q, want proj_goose_workspace", vol)
	}
	if net != "proj_pocketcoder-agent" {
		t.Errorf("network = %q, want proj_pocketcoder-agent", net)
	}
}

func TestResolveWorkspaceVolumeAndNetworkErrorsWhenNoMatch(t *testing.T) {
	fake := &fakeInspectClient{insp: dockerapi.ContainerInspect{}}
	_, _, err := ResolveWorkspaceVolumeAndNetwork(context.Background(), fake)
	if err == nil {
		t.Fatal("expected an error when no /workspace mount or pocketcoder-agent network is found")
	}
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd server/pocketbase/internal/hooks && go test -run TestResolveWorkspaceVolumeAndNetwork -v`
Expected: FAIL — function undefined

- [ ] **Step 3: Implement the resolver**

```go
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

// @pocketcoder-core: Harness Provisioning. Turns a harnesses catalog row
// into a running, dialable container on demand.
package hooks

import (
	"context"
	"fmt"
	"strings"

	"github.com/qtpi-automaton/pocketcoder/backend/internal/dockerapi"
)

// inspector is the minimal interface ResolveWorkspaceVolumeAndNetwork needs
// — satisfied by *dockerapi.Client, and by a small test double.
type inspector interface {
	Inspect(ctx context.Context, containerName string) (dockerapi.ContainerInspect, error)
}

// ResolveWorkspaceVolumeAndNetwork finds the real, possibly compose-project-
// prefixed names of the shared workspace volume and agent network by
// inspecting PocketBase's own container — belt-and-suspenders behind Task
// 4's pinned compose names (§5.1.2): matches by mount destination and
// network-name suffix, not by guessing a prefix.
func ResolveWorkspaceVolumeAndNetwork(ctx context.Context, client inspector) (volumeName, networkName string, err error) {
	insp, err := client.Inspect(ctx, "pocketcoder-pocketbase")
	if err != nil {
		return "", "", fmt.Errorf("inspect pocketcoder-pocketbase: %w", err)
	}
	for _, m := range insp.Mounts {
		if m.Destination == "/workspace" {
			volumeName = m.Name
		}
	}
	for name := range insp.NetworkSettings.Networks {
		if strings.HasSuffix(name, "pocketcoder-agent") {
			networkName = name
		}
	}
	if volumeName == "" {
		return "", "", fmt.Errorf("no /workspace mount found on pocketcoder-pocketbase")
	}
	if networkName == "" {
		return "", "", fmt.Errorf("no pocketcoder-agent network found on pocketcoder-pocketbase")
	}
	return volumeName, networkName, nil
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd server/pocketbase/internal/hooks && go test -run TestResolveWorkspaceVolumeAndNetwork -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add server/pocketbase/internal/hooks/harness_provision.go server/pocketbase/internal/hooks/harness_provision_test.go
git commit -m "feat(hooks): resolve real workspace volume and agent network names"
```

---

## Task 6: `ProvisionHarnessInstance`

**Files:**
- Modify: `server/pocketbase/internal/hooks/harness_provision.go`
- Test: `server/pocketbase/internal/hooks/harness_provision_test.go`

**Interfaces:**
- Consumes: `dockerapi.Client` (Tasks 1-3), `ResolveWorkspaceVolumeAndNetwork` (Task 5), `harnesses`/`harness_instances`/`provider_keys` schema (Plan 1).
- Produces: `func ProvisionHarnessInstance(ctx context.Context, app core.App, client *dockerapi.Client, harnessID, launchKey string) (*core.Record, error)` — idempotent: returns the existing row if one already exists for `(harnessID, launchKey)`, otherwise creates a `pending` row, mints a per-instance secret, renders `launch_template.env_template` against every `provider_keys` row's merged env vars, pulls the image, creates+starts the container (with that env and the minted secret), and updates the row to `running`+`secret` or `error`+`last_error`. Consumed by Task 7 (`buildSessionProfile`'s missing-instance path).

**Note on scope**: this renders provider keys into the container's environment at create time (§4.2/§5.5's stated create-time-only mechanism for non-Goose harnesses), which is the correct place for it — this plan does not add a *rotation* story beyond what §5.5 already accepts (destroy-and-recreate), since that's explicitly out of scope for v1.

- [ ] **Step 1: Write the failing tests**

```go
func TestProvisionHarnessInstanceCreatesAndStartsContainer(t *testing.T) {
	app := testApp(t)
	harness := createTestHarness(t, app, map[string]any{
		"container_image": "example.com/harness:1.0",
		"launch_template": map[string]any{"cmd": []string{"/adapter"}, "port": 3000},
	})
	fake := newFakeDockerClient() // records Create/Start/PullImage calls; add to a shared test-doubles file in this package
	rec, err := ProvisionHarnessInstance(context.Background(), app, fake, harness.Id, "")
	if err != nil {
		t.Fatal(err)
	}
	if rec.GetString("status") != "running" {
		t.Errorf("status = %q, want running", rec.GetString("status"))
	}
	if !fake.pulledImage("example.com/harness:1.0") {
		t.Error("expected the harness's image to be pulled")
	}
	if !fake.started(rec.GetString("container_name")) {
		t.Error("expected the created container to be started")
	}
}

func TestProvisionHarnessInstanceIsIdempotent(t *testing.T) {
	app := testApp(t)
	harness := createTestHarness(t, app, map[string]any{"container_image": "x", "launch_template": map[string]any{"cmd": []string{"/adapter"}}})
	fake := newFakeDockerClient()
	rec1, err := ProvisionHarnessInstance(context.Background(), app, fake, harness.Id, "")
	if err != nil {
		t.Fatal(err)
	}
	rec2, err := ProvisionHarnessInstance(context.Background(), app, fake, harness.Id, "")
	if err != nil {
		t.Fatal(err)
	}
	if rec1.Id != rec2.Id {
		t.Error("expected the second call to return the same row, not create a duplicate")
	}
	if fake.createCallCount != 1 {
		t.Errorf("expected exactly one Create call across both invocations, got %d", fake.createCallCount)
	}
}

func TestProvisionHarnessInstanceSurfacesPullFailure(t *testing.T) {
	app := testApp(t)
	harness := createTestHarness(t, app, map[string]any{"container_image": "nonexistent:latest", "launch_template": map[string]any{"cmd": []string{"/adapter"}, "port": 3000}})
	fake := newFakeDockerClient()
	fake.pullErr = fmt.Errorf("No such image")
	rec, err := ProvisionHarnessInstance(context.Background(), app, fake, harness.Id, "")
	if err != nil {
		t.Fatal("ProvisionHarnessInstance itself should not error — the failure surfaces on the row")
	}
	if rec.GetString("status") != "error" {
		t.Errorf("status = %q, want error", rec.GetString("status"))
	}
	if rec.GetString("last_error") == "" {
		t.Error("expected last_error to be populated with the pull failure")
	}
}

func TestProvisionHarnessInstanceErrorsOnMissingPort(t *testing.T) {
	app := testApp(t)
	harness := createTestHarness(t, app, map[string]any{"container_image": "x", "launch_template": map[string]any{"cmd": []string{"/adapter"}}}) // no "port"
	fake := newFakeDockerClient()
	rec, err := ProvisionHarnessInstance(context.Background(), app, fake, harness.Id, "")
	if err != nil {
		t.Fatal(err)
	}
	if rec.GetString("status") != "error" {
		t.Errorf("status = %q, want error — a launch_template with no port must not silently produce ws://host:0/acp", rec.GetString("status"))
	}
}

func TestProvisionHarnessInstanceRendersProviderKeysAndMintsSecret(t *testing.T) {
	app := testApp(t)
	createTestProviderKey(t, app, map[string]any{"provider": "anthropic", "env_vars": map[string]any{"ANTHROPIC_API_KEY": "sk-test-123"}})
	harness := createTestHarness(t, app, map[string]any{
		"container_image": "example.com/harness:1.0",
		"launch_template": map[string]any{
			"cmd":  []string{"/adapter"},
			"port": 3000,
			"env_template": map[string]any{
				"ANTHROPIC_API_KEY": "{{.ANTHROPIC_API_KEY}}",
				"ADAPTER_SECRET":    "{{.__adapter_secret}}",
			},
		},
	})
	fake := newFakeDockerClient()
	rec, err := ProvisionHarnessInstance(context.Background(), app, fake, harness.Id, "")
	if err != nil {
		t.Fatal(err)
	}
	if rec.GetString("secret") == "" {
		t.Error("expected a minted, non-empty secret on the harness_instances row")
	}
	env := fake.lastCreateSpec.Env
	found := map[string]bool{}
	for _, kv := range env {
		if kv == "ANTHROPIC_API_KEY=sk-test-123" {
			found["key"] = true
		}
		if kv == "ADAPTER_SECRET="+rec.GetString("secret") {
			found["secret"] = true
		}
	}
	if !found["key"] {
		t.Errorf("env = %v, want ANTHROPIC_API_KEY=sk-test-123 rendered from provider_keys", env)
	}
	if !found["secret"] {
		t.Errorf("env = %v, want ADAPTER_SECRET matching the row's minted secret", env)
	}
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd server/pocketbase/internal/hooks && go test -run TestProvisionHarnessInstance -v`
Expected: FAIL — function undefined

- [ ] **Step 3: Implement `ProvisionHarnessInstance`**

```go
import (
	"bytes"
	"crypto/rand"
	"encoding/hex"
	"text/template"

	"github.com/pocketbase/pocketbase/core"
	"github.com/google/uuid"
)

// dockerProvisioner is the subset of *dockerapi.Client ProvisionHarnessInstance
// needs — satisfied by the real client and by a test double.
type dockerProvisioner interface {
	inspector
	PullImage(ctx context.Context, image string) error
	Create(ctx context.Context, name string, spec dockerapi.CreateSpec) (string, error)
	Start(ctx context.Context, containerName string) error
}

func ProvisionHarnessInstance(ctx context.Context, app core.App, client dockerProvisioner, harnessID, launchKey string) (*core.Record, error) {
	existing, err := app.FindFirstRecordByFilter("harness_instances", "harness = {:h} && launch_key = {:k}",
		map[string]any{"h": harnessID, "k": launchKey})
	if err == nil && existing != nil {
		return existing, nil
	}

	harness, err := app.FindRecordById("harnesses", harnessID)
	if err != nil {
		return nil, fmt.Errorf("look up harness %s: %w", harnessID, err)
	}

	secret, err := mintSecret()
	if err != nil {
		return nil, fmt.Errorf("mint harness instance secret: %w", err)
	}

	coll, err := app.FindCollectionByNameOrId("harness_instances")
	if err != nil {
		return nil, err
	}
	rec := core.NewRecord(coll)
	containerName := "pocketcoder-harness-" + uuid.NewString()[:8]
	rec.Set("harness", harnessID)
	rec.Set("launch_key", launchKey)
	rec.Set("container_name", containerName)
	rec.Set("secret", secret)
	rec.Set("status", "pending")
	rec.Set("managed", true)
	if err := app.Save(rec); err != nil {
		return nil, fmt.Errorf("save pending harness_instances row: %w", err)
	}
	fail := func(err error) (*core.Record, error) {
		rec.Set("status", "error")
		rec.Set("last_error", err.Error())
		app.Save(rec)
		return rec, nil
	}

	volumeName, networkName, err := ResolveWorkspaceVolumeAndNetwork(ctx, client)
	if err != nil {
		return fail(err)
	}

	image := harness.GetString("container_image")
	var launch struct {
		Cmd         []string          `json:"cmd"`
		Port        int               `json:"port"`
		EnvTemplate map[string]string `json:"env_template"`
	}
	_ = harness.UnmarshalJSONField("launch_template", &launch)
	if launch.Port == 0 {
		return fail(fmt.Errorf("harness %s's launch_template has no port", harnessID))
	}

	env, err := renderEnv(app, launch.EnvTemplate, secret)
	if err != nil {
		return fail(fmt.Errorf("render launch_template.env_template: %w", err))
	}

	if err := client.PullImage(ctx, image); err != nil {
		return fail(err)
	}

	_, err = client.Create(ctx, containerName, dockerapi.CreateSpec{
		Image: image, Cmd: launch.Cmd, Env: env,
		VolumeName: volumeName, VolumeDest: "/workspace",
		NetworkName: networkName,
	})
	if err != nil {
		return fail(err)
	}
	if err := client.Start(ctx, containerName); err != nil {
		return fail(err)
	}

	rec.Set("status", "running")
	rec.Set("acp_endpoint", fmt.Sprintf("ws://%s:%d/acp", containerName, launch.Port))
	if err := app.Save(rec); err != nil {
		return nil, fmt.Errorf("save running harness_instances row: %w", err)
	}
	return rec, nil
}

// mintSecret generates the per-instance credential the bundled adapter
// enforces on its WS upgrade (§5.4.1) — this, not an empty string, is what
// populates Target.Secret once this row is resolved.
func mintSecret() (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}

// renderEnv merges every provider_keys row's env_vars into one lookup map
// (the same "merge every row" convention gooseconfig.RenderKeysEnv already
// uses for Goose's own keys.env — deliberately not scoped to one specific
// provider here, since launch_template doesn't declare which provider(s) a
// given harness needs ahead of time), adds a reserved "__adapter_secret" key
// for the minted per-instance secret, and renders each env_template value
// as a Go text/template against that map — e.g. an entry
// {"ANTHROPIC_API_KEY": "{{.ANTHROPIC_API_KEY}}"} becomes
// "ANTHROPIC_API_KEY=sk-..." in the returned KEY=VALUE slice Docker's
// container-create API expects.
func renderEnv(app core.App, envTemplate map[string]string, secret string) ([]string, error) {
	keyRecs, err := app.FindRecordsByFilter("provider_keys", "1=1", "", 0, 0)
	if err != nil {
		return nil, fmt.Errorf("query provider_keys: %w", err)
	}
	values := map[string]string{"__adapter_secret": secret}
	for _, r := range keyRecs {
		var vars map[string]string
		if err := r.UnmarshalJSONField("env_vars", &vars); err != nil {
			continue
		}
		for k, v := range vars {
			values[k] = v
		}
	}

	env := make([]string, 0, len(envTemplate))
	for name, tmplStr := range envTemplate {
		tmpl, err := template.New(name).Parse(tmplStr)
		if err != nil {
			return nil, fmt.Errorf("parse env_template[%s]: %w", name, err)
		}
		var buf bytes.Buffer
		if err := tmpl.Execute(&buf, values); err != nil {
			return nil, fmt.Errorf("render env_template[%s]: %w", name, err)
		}
		env = append(env, name+"="+buf.String())
	}
	return env, nil
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd server/pocketbase/internal/hooks && go test -run TestProvisionHarnessInstance -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add server/pocketbase/internal/hooks/harness_provision.go server/pocketbase/internal/hooks/harness_provision_test.go
git commit -m "feat(hooks): add ProvisionHarnessInstance"
```

---

## Task 7: Wire `buildSessionProfile`'s missing-instance path onto provisioning

**Files:**
- Modify: `server/pocketbase/internal/api/profile.go` (the section Plan 1 left as "surfaces a clear 'harness not provisioned' error" without implementing it)
- Test: `server/pocketbase/internal/api/profile_test.go`

**Interfaces:**
- Consumes: `hooks.ProvisionHarnessInstance` (Task 6).
- Produces: `buildSessionProfile`, on finding no `harness_instances` row for the resolved `(harness, launch_key)`, kicks off provisioning in the background and returns a distinct sentinel error `ErrHarnessProvisioning`, so the API layer can surface "harness starting, try again shortly" instead of either blocking the request on an image pull or silently proceeding with an empty `Target`.

- [ ] **Step 1: Write the failing test**

```go
func TestBuildSessionProfileTriggersProvisioningWhenInstanceMissing(t *testing.T) {
	app := testApp(t)
	harness := createTestHarness(t, app, map[string]any{"cli_id": "new-harness", "container_image": "x"})
	chat := createTestChat(t, app, map[string]any{"harness": harness.Id})
	// deliberately: no harness_instances row exists yet for this harness

	_, err := buildSessionProfile(app, chat.Id)
	if !errors.Is(err, ErrHarnessProvisioning) {
		t.Fatalf("expected ErrHarnessProvisioning, got %v", err)
	}

	// Provisioning is kicked off in a background goroutine (Task 6's row
	// creation isn't synchronous with buildSessionProfile's return), so this
	// polls briefly rather than asserting immediately — a bare synchronous
	// check here would be flaky, not a faithful test of async behavior.
	deadline := time.Now().Add(2 * time.Second)
	var rec *core.Record
	for time.Now().Before(deadline) {
		if r, err := app.FindFirstRecordByFilter("harness_instances", "harness = {:h}", map[string]any{"h": harness.Id}); err == nil && r != nil {
			rec = r
			break
		}
		time.Sleep(10 * time.Millisecond)
	}
	if rec == nil {
		t.Fatal("expected a harness_instances row to appear within 2s of triggering background provisioning")
	}
	if rec.GetString("status") != "pending" && rec.GetString("status") != "running" {
		t.Errorf("status = %q, want pending or running (provisioning started)", rec.GetString("status"))
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd server/pocketbase/internal/api && go test -run TestBuildSessionProfileTriggersProvisioningWhenInstanceMissing -v`
Expected: FAIL — `ErrHarnessProvisioning` undefined, or the missing-instance path silently leaves `Target` empty instead of erroring

- [ ] **Step 3: Wire the missing-instance branch**

In `profile.go`, add near the top:

```go
var ErrHarnessProvisioning = errors.New("harness is being provisioned — retry shortly")
```

Replace the comment-only placeholder from Plan 1's Task 9 (the block starting `instance, err := app.FindFirstRecordByFilter("harness_instances", ...)`) with:

```go
instance, err := app.FindFirstRecordByFilter("harness_instances", "harness = {:h} && launch_key = {:k}",
	map[string]any{"h": harnessRec.Id, "k": launchKey})
if err == nil && instance != nil {
	p.ResolvedInstanceID = instance.Id
	p.Target = coordinator.Target{URL: instance.GetString("acp_endpoint"), Secret: instance.GetString("secret")}
	if instance.GetString("status") == "pending" {
		return p, ErrHarnessProvisioning
	}
	if instance.GetString("status") == "error" {
		return p, fmt.Errorf("harness failed to start: %s", instance.GetString("last_error"))
	}
} else {
	harnessID, launchKeyCopy := harnessRec.Id, launchKey
	go func() {
		if _, perr := hooks.ProvisionHarnessInstance(context.Background(), app, dockerapi.New(), harnessID, launchKeyCopy); perr != nil {
			log.Printf("[Profile] background provisioning failed for harness %s: %v", harnessID, perr)
		}
	}()
	return p, ErrHarnessProvisioning
}
```

Update the HTTP handlers in `api/agent.go` that call `buildSessionProfile` (both the `session/prompt` route and the `stream` route's cold-replay branch) to check `errors.Is(err, ErrHarnessProvisioning)` and return a `202`-style "still starting" response instead of the generic `500` they'd otherwise return.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd server/pocketbase/internal/api && go test -run TestBuildSessionProfileTriggersProvisioningWhenInstanceMissing -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add server/pocketbase/internal/api/profile.go server/pocketbase/internal/api/agent.go server/pocketbase/internal/api/profile_test.go
git commit -m "feat(api): trigger background provisioning when buildSessionProfile finds no instance row"
```

---

## Task 8: Event watcher — reactive status + startup reconciliation sweep

**Files:**
- Create: `server/pocketbase/internal/hooks/harness_watcher.go`
- Test: `server/pocketbase/internal/hooks/harness_watcher_test.go`

**Interfaces:**
- Consumes: `dockerapi.Client.Events`/`.ListAll` (Task 3).
- Produces: `func StartHarnessWatcher(ctx context.Context, app core.App, client *dockerapi.Client)` — subscribes to events first, then sweeps, updating `harness_instances.status`; skips every `managed = false` row.

- [ ] **Step 1: Write the failing tests**

```go
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
}

func TestWatcherReconciliationSweepSkipsUnmanagedRows(t *testing.T) {
	app := testApp(t)
	unmanaged := createTestHarnessInstance(t, app, map[string]any{"container_name": "pocketcoder-goose", "status": "running", "managed": false})
	fake := newFakeEventClient()
	fake.listAllResult = nil // pocketcoder-goose "not found" in a ListAll snapshot — should NOT be marked stopped, since it's unmanaged
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go StartHarnessWatcher(ctx, app, fake)
	time.Sleep(50 * time.Millisecond)
	rec, _ := app.FindRecordById("harness_instances", unmanaged.Id)
	if rec.GetString("status") != "running" {
		t.Error("the sweep must never touch a managed=false row, even if it's absent from ListAll")
	}
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd server/pocketbase/internal/hooks && go test -run TestWatcher -v`
Expected: FAIL — `StartHarnessWatcher` undefined

- [ ] **Step 3: Implement the watcher**

```go
type eventSource interface {
	Events(ctx context.Context) (<-chan dockerapi.Event, error)
	ListAll(ctx context.Context) ([]dockerapi.ContainerSummary, error)
}

// StartHarnessWatcher subscribes to the Docker event stream BEFORE running
// the startup reconciliation sweep — deliberately, so a container that
// changes state in the gap between the sweep's snapshot and the
// subscription taking effect isn't missed (§5.3).
func StartHarnessWatcher(ctx context.Context, app core.App, client eventSource) {
	events, err := client.Events(ctx)
	if err != nil {
		log.Printf("[HarnessWatcher] failed to subscribe to docker events: %v", err)
		return
	}

	reconcile(ctx, app, client)

	for {
		select {
		case ev, ok := <-events:
			if !ok {
				return
			}
			if ev.Type != "" && ev.Type != "container" {
				continue
			}
			applyStatus(app, ev.ContainerName, dockerEventToStatus(ev.Action))
		case <-ctx.Done():
			return
		}
	}
}

func dockerEventToStatus(action string) string {
	switch action {
	case "start":
		return "running"
	case "die", "stop", "kill":
		return "stopped"
	default:
		return ""
	}
}

func applyStatus(app core.App, containerName, status string) {
	if status == "" {
		return
	}
	rec, err := app.FindFirstRecordByFilter("harness_instances", "container_name = {:n}", map[string]any{"n": containerName})
	if err != nil || rec == nil {
		return
	}
	if !rec.GetBool("managed") {
		return // never touch the compose-managed default Goose row
	}
	rec.Set("status", status)
	app.Save(rec)
}

func reconcile(ctx context.Context, app core.App, client eventSource) {
	all, err := client.ListAll(ctx)
	if err != nil {
		log.Printf("[HarnessWatcher] reconciliation sweep failed: %v", err)
		return
	}
	running := map[string]bool{}
	for _, c := range all {
		for _, n := range c.Names {
			running[strings.TrimPrefix(n, "/")] = c.State == "running"
		}
	}
	instances, err := app.FindRecordsByFilter("harness_instances", "managed = true", "", 0, 0)
	if err != nil {
		return
	}
	for _, inst := range instances {
		name := inst.GetString("container_name")
		wantRunning, seen := running[name]
		if !seen {
			continue // absent from the sweep entirely — leave as-is, a future event will correct it
		}
		status := "stopped"
		if wantRunning {
			status = "running"
		}
		if inst.GetString("status") != status {
			inst.Set("status", status)
			app.Save(inst)
		}
	}
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd server/pocketbase/internal/hooks && go test -run TestWatcher -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add server/pocketbase/internal/hooks/harness_watcher.go server/pocketbase/internal/hooks/harness_watcher_test.go
git commit -m "feat(hooks): add reactive harness_instances status watcher with startup reconciliation"
```

Register `StartHarnessWatcher` in `main.go`'s `OnServe` handler, run as a background goroutine with a context tied to the app's shutdown signal (follow whatever pattern the existing `RegisterGooseConfigHooks`/coordinator startup already uses for lifecycle-bound goroutines).

---

## Task 9: `harness-adapter` — framing, standardized against `internal/agent/acp/websocket.go`

**Files:**
- Create: `server/harness-adapter/main.go`
- Create: `server/harness-adapter/adapter.go`
- Test: `server/harness-adapter/adapter_test.go`

**Interfaces:**
- Produces: a standalone binary, `harness-adapter --cmd <binary> --port <port> --secret <token>`, that listens for websocket connections and bridges each to a freshly-spawned stdio subprocess of `<binary>`.

- [ ] **Step 0: Initialize a separate Go module**

`server/harness-adapter` is a standalone binary, not part of `server/pocketbase`'s module — this repo has exactly one `go.mod` today (`server/pocketbase/go.mod`), and nothing else creates one for this directory.

```bash
mkdir -p server/harness-adapter
cd server/harness-adapter
go mod init github.com/qtpi-automaton/pocketcoder/harness-adapter
go get github.com/coder/websocket@v1.8.15   # match the version pinned in server/pocketbase/go.mod
```

- [ ] **Step 1: Write the failing tests**

```go
package main

import (
	"bufio"
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/coder/websocket"
)

// fakeEchoScript is used as the "harness binary" under test — a tiny shell
// script that echoes each stdin line back to stdout, standing in for a real
// ACP agent's stdio behavior for framing-correctness purposes only (this
// test is about the bridge, not about ACP semantics).
func TestAdapterRoundTripsOneMessagePerFrame(t *testing.T) {
	srv := httptest.NewServer(newAdapterHandler(adapterConfig{
		Cmd: []string{"cat"}, Secret: "s3cr3t", MaxLineBytes: 64 << 20,
	}))
	defer srv.Close()
	wsURL := "ws" + strings.TrimPrefix(srv.URL, "http") + "/acp?token=s3cr3t"
	conn, _, err := websocket.Dial(context.Background(), wsURL, nil)
	if err != nil {
		t.Fatal(err)
	}
	conn.SetReadLimit(64 << 20)
	defer conn.Close(websocket.StatusNormalClosure, "")

	msg := `{"jsonrpc":"2.0","method":"ping","id":1}`
	if err := conn.Write(context.Background(), websocket.MessageText, []byte(msg)); err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	_, data, err := conn.Read(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if string(data) != msg {
		t.Errorf("got %q, want %q echoed back unmodified", string(data), msg)
	}
}

func TestAdapterRejectsWrongToken(t *testing.T) {
	srv := httptest.NewServer(newAdapterHandler(adapterConfig{Cmd: []string{"cat"}, Secret: "s3cr3t", MaxLineBytes: 64 << 20}))
	defer srv.Close()
	wsURL := "ws" + strings.TrimPrefix(srv.URL, "http") + "/acp?token=wrong"
	_, _, err := websocket.Dial(context.Background(), wsURL, nil)
	if err == nil {
		t.Fatal("expected the upgrade to be rejected with the wrong token")
	}
}

func TestAdapterRoundTripsMessageAboveDefaultScannerLimit(t *testing.T) {
	// 200KB message — well above bufio.Scanner's 64KB default token size,
	// well within the adapter's required raised limit. This is the
	// regression test for the "two limits, not one" finding.
	srv := httptest.NewServer(newAdapterHandler(adapterConfig{Cmd: []string{"cat"}, Secret: "s3cr3t", MaxLineBytes: 64 << 20}))
	defer srv.Close()
	wsURL := "ws" + strings.TrimPrefix(srv.URL, "http") + "/acp?token=s3cr3t"
	conn, _, err := websocket.Dial(context.Background(), wsURL, nil)
	if err != nil {
		t.Fatal(err)
	}
	conn.SetReadLimit(64 << 20)
	defer conn.Close(websocket.StatusNormalClosure, "")

	big := `{"jsonrpc":"2.0","method":"ping","params":{"blob":"` + strings.Repeat("x", 200*1024) + `"},"id":1}`
	if err := conn.Write(context.Background(), websocket.MessageText, []byte(big)); err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	_, data, err := conn.Read(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if len(data) != len(big) {
		t.Errorf("got %d bytes back, want %d — message truncated somewhere in the bridge", len(data), len(big))
	}
}

func TestAdapterSpawnsFreshSubprocessPerConnection(t *testing.T) {
	// Two connections against the same adapter must each get their own
	// subprocess — asserted indirectly here via a script that increments a
	// counter file on each new invocation; a shared/reused process would
	// only increment once.
	srv := httptest.NewServer(newAdapterHandler(adapterConfig{Cmd: []string{"sh", "-c", "echo spawned; cat"}, Secret: "", MaxLineBytes: 64 << 20}))
	defer srv.Close()
	dialOne := func() string {
		wsURL := "ws" + strings.TrimPrefix(srv.URL, "http") + "/acp"
		conn, _, err := websocket.Dial(context.Background(), wsURL, nil)
		if err != nil {
			t.Fatal(err)
		}
		defer conn.Close(websocket.StatusNormalClosure, "")
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		defer cancel()
		_, data, err := conn.Read(ctx)
		if err != nil {
			t.Fatal(err)
		}
		return string(data)
	}
	first := dialOne()
	second := dialOne()
	if first != "spawned" || second != "spawned" {
		t.Errorf("expected both connections to see a freshly-spawned process announce itself, got %q and %q", first, second)
	}
}

func TestAdapterDoesNotHangOnOversizedMessage(t *testing.T) {
	// Regression test for the teardown bug: an oversized line used to leave
	// the subprocess (and its still-open stdout pipe) running forever with
	// nothing draining it, since only the failing goroutine exited and
	// nothing killed the process or closed the connection. bridgeConnection
	// must now return promptly regardless.
	srv := httptest.NewServer(newAdapterHandler(adapterConfig{Cmd: []string{"cat"}, Secret: "", MaxLineBytes: 1024}))
	defer srv.Close()
	wsURL := "ws" + strings.TrimPrefix(srv.URL, "http") + "/acp"
	conn, _, err := websocket.Dial(context.Background(), wsURL, nil)
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close(websocket.StatusNormalClosure, "")

	oversized := strings.Repeat("x", 4096) // well above the 1024-byte MaxLineBytes configured above
	if err := conn.Write(context.Background(), websocket.MessageText, []byte(oversized)); err != nil {
		t.Fatal(err)
	}

	done := make(chan struct{})
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
		defer cancel()
		conn.Read(ctx) // expected to fail/close once teardown runs, not hang
		close(done)
	}()
	select {
	case <-done:
		// expected: the connection closes promptly instead of hanging
	case <-time.After(2 * time.Second):
		t.Fatal("bridge did not tear down within 2s of an oversized message — the deadlock/leak regression")
	}
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd server/harness-adapter && go test -v`
Expected: FAIL — package doesn't exist yet

- [ ] **Step 3: Implement the adapter**

```go
// server/harness-adapter/adapter.go
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

// @pocketcoder-core: stdio<->websocket bridge for stdio-native ACP harnesses
// (§5.4/§5.4.1 of the multi-harness design spec). Byte-transparent: this
// file must never parse or filter ACP JSON-RPC content — reframing only.
package main

import (
	"bufio"
	"context"
	"io"
	"net/http"
	"os/exec"
	"sync"

	"github.com/coder/websocket"
)

type adapterConfig struct {
	Cmd          []string
	Secret       string
	MaxLineBytes int64
}

func newAdapterHandler(cfg adapterConfig) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/acp", func(w http.ResponseWriter, r *http.Request) {
		if cfg.Secret != "" && r.URL.Query().Get("token") != cfg.Secret {
			http.Error(w, "invalid token", http.StatusUnauthorized)
			return
		}
		conn, err := websocket.Accept(w, r, nil)
		if err != nil {
			return
		}
		conn.SetReadLimit(cfg.MaxLineBytes)
		defer conn.Close(websocket.StatusNormalClosure, "") // harmless if bridgeConnection's own teardown already closed it — coder/websocket's Close is safe to call more than once
		bridgeConnection(r.Context(), conn, cfg)
	})
	return mux
}

// initialStdoutBufferSize is the bufio.Reader's internal read-chunk size,
// NOT a cap on message size — readUnboundedLine accumulates across
// ReadLine's isPrefix continuations regardless of this value, so it only
// affects syscall batching, not the (much larger) MaxLineBytes ceiling. A
// 64 MiB buffer here, once per bridged connection (i.e. once per prompt,
// per §5.4's spawn-per-connection model), would be wasteful for no benefit.
const initialStdoutBufferSize = 4096

// bridgeConnection spawns cfg.Cmd fresh for this one connection and relays
// newline-delimited JSON-RPC both directions: one subprocess stdout line ->
// one WS TEXT frame; one WS TEXT frame -> one subprocess stdin line. Never
// inspects message content beyond finding line boundaries.
//
// Teardown is symmetric and idempotent: whichever direction exits first
// (oversized line, subprocess exit, WS close, ctx cancellation) triggers
// killing the subprocess AND closing the WS connection, which together
// unblock whichever side was still stuck on a pipe read/write or a
// conn.Read/Write — otherwise a goroutine, its subprocess, and the OS pipe
// buffer backing it can all hang forever on exactly the size-limit or
// abrupt-disconnect paths this bridge exists to handle correctly.
func bridgeConnection(ctx context.Context, conn *websocket.Conn, cfg adapterConfig) {
	cmd := exec.Command(cfg.Cmd[0], cfg.Cmd[1:]...) // NOT CommandContext: teardown() below kills it on our own terms, so a ctx cancellation racing a normal exit is handled the same way as every other exit path, not as a special case
	stdin, err := cmd.StdinPipe()
	if err != nil {
		return
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return
	}
	if err := cmd.Start(); err != nil {
		return
	}

	var once sync.Once
	teardown := func() {
		once.Do(func() {
			_ = cmd.Process.Kill()                              // unblocks a stuck stdout read or stdin write
			_ = conn.Close(websocket.StatusInternalError, "bridge closing") // unblocks a stuck conn.Read/Write
		})
	}
	defer teardown()

	var wg sync.WaitGroup
	wg.Add(2)

	// stdout (subprocess) -> WS
	go func() {
		defer wg.Done()
		defer teardown()
		reader := bufio.NewReaderSize(stdout, initialStdoutBufferSize)
		for {
			line, err := readUnboundedLine(reader, cfg.MaxLineBytes)
			if err != nil {
				return
			}
			if len(line) == 0 {
				continue
			}
			if err := conn.Write(ctx, websocket.MessageText, line); err != nil {
				return
			}
		}
	}()

	// WS -> stdin (subprocess)
	go func() {
		defer wg.Done()
		defer teardown()
		defer stdin.Close()
		for {
			_, data, err := conn.Read(ctx)
			if err != nil {
				return
			}
			if _, err := stdin.Write(append(data, '\n')); err != nil {
				return
			}
		}
	}()

	wg.Wait()  // both directions have stopped — guaranteed by teardown() unblocking whichever side didn't exit on its own
	cmd.Wait() // reap; a non-nil exit error here is expected and ignored in the common (intentionally-killed) case
}

// readUnboundedLine reads up to a '\n' without Go's bufio.Scanner 64KB
// default token-size ceiling — the stdio-leg half of the "two limits, not
// one" finding (§5.4.1). maxBytes still bounds it, matching the WS leg's
// raised SetReadLimit, so neither side is silently unbounded either.
func readUnboundedLine(r *bufio.Reader, maxBytes int64) ([]byte, error) {
	var buf []byte
	for {
		chunk, isPrefix, err := r.ReadLine()
		if err != nil {
			return nil, err
		}
		buf = append(buf, chunk...)
		if int64(len(buf)) > maxBytes {
			return nil, io.ErrShortBuffer
		}
		if !isPrefix {
			return buf, nil
		}
	}
}
```

```go
// server/harness-adapter/main.go
package main

import (
	"flag"
	"log"
	"net/http"
	"strings"
)

func main() {
	cmd := flag.String("cmd", "", "the stdio ACP binary to spawn per connection, e.g. 'claude-agent-acp'")
	port := flag.String("port", "3000", "port to listen on")
	secret := flag.String("secret", "", "?token= value the adapter enforces on the WS upgrade")
	flag.Parse()
	if *cmd == "" {
		log.Fatal("harness-adapter: --cmd is required")
	}
	handler := newAdapterHandler(adapterConfig{
		Cmd:          strings.Fields(*cmd),
		Secret:       *secret,
		MaxLineBytes: 64 << 20,
	})
	log.Printf("harness-adapter listening on :%s, spawning %q per connection", *port, *cmd)
	log.Fatal(http.ListenAndServe(":"+*port, handler))
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd server/harness-adapter && go test -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add server/harness-adapter/main.go server/harness-adapter/adapter.go server/harness-adapter/adapter_test.go
git commit -m "feat(harness-adapter): add byte-transparent stdio-to-websocket bridge"
```

---

## Task 10: Example `Dockerfile` + `launch_template` for a stdio-native harness

**Files:**
- Create: `server/harness-adapter/Dockerfile`

**Interfaces:**
- Produces: documentation-as-code showing how a future `harnesses` catalog row for `claude-agent-acp` (or any stdio-native binary) actually bundles the adapter — not itself an executable task, but the concrete reference an admin adding a new harness row needs.

- [ ] **Step 1: Write the Dockerfile**

```dockerfile
# Example: bundling a stdio-native ACP harness (claude-agent-acp) with the
# harness-adapter (§5.4 of the multi-harness selection design spec). This
# is a REFERENCE for populating a harnesses.container_image — not itself
# built by this repo's own compose file, since harness images are
# per-catalog-entry, not part of the base deployment.
FROM node:20-slim AS harness-adapter-build
WORKDIR /adapter
COPY server/harness-adapter/ .
RUN go build -o /usr/local/bin/harness-adapter .  # requires a Go build stage in practice; shown collapsed here for brevity

FROM node:20-slim
RUN npm install -g @zed-industries/claude-agent-acp
COPY --from=harness-adapter-build /usr/local/bin/harness-adapter /usr/local/bin/harness-adapter
EXPOSE 3000
ENTRYPOINT ["harness-adapter", "--cmd", "claude-agent-acp", "--port", "3000"]
```

A corresponding `harnesses` row's `launch_template` (§4.2, illustrative — not schema-enforced structure beyond being valid JSON):

```json
{"cmd": ["harness-adapter", "--cmd", "claude-agent-acp", "--port", "3000"], "port": 3000}
```

(`Task 6`'s `ProvisionHarnessInstance` reads `cmd`/`port` from exactly this shape.)

- [ ] **Step 2: Commit**

```bash
git add server/harness-adapter/Dockerfile
git commit -m "docs: add example Dockerfile for a stdio-native harness bundling harness-adapter"
```

---

## Self-Review

**Revised after independent review (Sonnet).** That review found and this revision fixed: a nil-pointer crash in Task 1's own test (missing `http: srv.Client()`); a missing Go module for `server/harness-adapter` (Task 9 now has an explicit Step 0); a missing `"context"` import; a real deadlock/leak in `bridgeConnection`'s shutdown path (an oversized line, or any other early exit by one bridging goroutine, used to leave the subprocess and OS pipe running forever with nothing tearing it down — fixed with symmetric, idempotent teardown that kills the subprocess and closes the connection from whichever side exits first, plus a regression test); an oversized preallocated buffer unrelated to the actual size-limit fix; a flaky test asserting immediately after firing a background goroutine (now polls); a missing port-validation check; and — the most significant gap — `ProvisionHarnessInstance` never actually rendering `launch_template.env_template` against `provider_keys` or minting the per-instance `secret` the bundled adapter is supposed to enforce, meaning every harness this plan provisions would have gotten no provider API key and no auth at all. All of these are now fixed in Tasks 1, 6, and 9 above.

**One gap left as an accepted, stated limitation, not fixed**: a `harness_instances` row stuck in `status = "error"` (e.g. a transient pull failure) has no automated retry — `ProvisionHarnessInstance`'s idempotency check treats it identically to a healthy row, so `buildSessionProfile` (Task 7) returns the same hard error for that harness on every future chat until an admin manually deletes the row. The design spec's §5.1.1 only requires the failure to be *surfaced*, not retried, so this isn't a spec-coverage gap — but it's a real operational rough edge worth flagging explicitly rather than leaving implicit, and a natural candidate for a small follow-up (e.g. treat an `error` row older than N minutes as eligible for re-provisioning) once a real non-Goose harness is in use.

**Spec coverage:**
- §5.1.1 (image pull, `IMAGES=1`) → Tasks 2, 4.
- §5.1.2 (volume/network resolution) → Tasks 1, 5; pinned names → Task 4.
- §5.2 (default-Goose row) → already covered by Plan 1; this plan's Task 6 (`ProvisionHarnessInstance`) is deliberately never invoked for it (`managed = false` rows are pre-seeded, never provisioned).
- §5.3 (event watcher, subscribe-then-sweep, skip `managed = false`) → Task 8.
- §5.4/§5.4.1 (bundled adapter, framing, two size limits, `?token=` auth, byte-transparency, spawn-per-connection) → Task 9.
- §5.5 (`AdminConn` stays Goose-only) → no code in this plan touches `AdminConn`; correctly out of scope, not silently missed.
- The gap Plan 1 explicitly left open (missing-instance path in `buildSessionProfile`) → Task 7.

**Placeholder scan:** No `TBD`/"implement later" patterns. Task 10's Dockerfile is explicitly a reference/example, stated as such, not a claim that it's wired into the deployment — that's a real, correct scope boundary (per-catalog-entry images aren't part of this repo's base compose file), not an unaddressed gap.

**Type consistency:** `dockerapi.Client`/`CreateSpec`/`ContainerInspect`/`Event`/`ContainerSummary` used identically from their Task 1-3 definitions through Tasks 5-8's consumption. `ProvisionHarnessInstance`'s signature (Task 6) matches its Task 7 call site exactly, including the `dockerProvisioner` interface satisfying `*dockerapi.Client`. `adapterConfig{Cmd, Secret, MaxLineBytes}` is used identically across Task 9's tests and implementation.
