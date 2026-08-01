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
