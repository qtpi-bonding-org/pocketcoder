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
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
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
	Image                               string
	Cmd                                 []string
	Env                                 []string
	VolumeName, VolumeDest, NetworkName string
}

func (c *Client) Create(ctx context.Context, name string, spec CreateSpec) (string, error) {
	payload := map[string]any{
		"Image": spec.Image,
		"Cmd":   spec.Cmd,
		"Env":   spec.Env,
		"HostConfig": map[string]any{
			"Binds": []string{spec.VolumeName + ":" + spec.VolumeDest},
			// Every other service in docker-compose.yml runs
			// `restart: unless-stopped` — a provisioned harness must match,
			// or a host reboot (an Aeroform box has no SSH step per
			// CLAUDE.md, so nobody's there to `docker start` it by hand)
			// silently strands every chat on that harness with no
			// automated recovery, unlike Goose. The event watcher (Task 8)
			// only reflects status reactively; it does not restart
			// anything, so this is the only thing that brings the
			// container back after a reboot.
			"RestartPolicy": map[string]any{"Name": "unless-stopped"},
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
