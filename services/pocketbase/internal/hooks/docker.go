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

// @pocketcoder-core: Docker Utilities. Shared container restart logic via Docker Socket Proxy.
package hooks

import (
	"context"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"strings"
	"time"
)

const defaultDockerHost = "tcp://docker-socket-proxy-write:2375"

// restartContainer sends a restart command to the named container via the Docker Socket Proxy.
func restartContainer(containerName string, timeout time.Duration) error {
	log.Printf("🔄 [Docker] Restarting container '%s'...", containerName)

	host := os.Getenv("DOCKER_HOST")
	if host == "" {
		host = defaultDockerHost
	}

	proxyAddr := host
	if strings.HasPrefix(host, "tcp://") {
		proxyAddr = strings.TrimPrefix(host, "tcp://")
	}

	client := &http.Client{
		Transport: &http.Transport{
			DialContext: func(ctx context.Context, network, addr string) (net.Conn, error) {
				return net.Dial("tcp", proxyAddr)
			},
		},
		Timeout: timeout,
	}

	apiPath := fmt.Sprintf("http://%s/containers/%s/restart", proxyAddr, containerName)
	resp, err := client.Post(apiPath, "application/json", nil)
	if err != nil {
		return fmt.Errorf("failed to call Docker API via proxy: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusNotFound {
		log.Printf("⚠️ [Docker] Container '%s' not found, skipping restart", containerName)
		return nil
	}

	if resp.StatusCode >= 400 {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("Docker API returned error %s: %s", resp.Status, string(body))
	}

	log.Printf("✅ [Docker] Container '%s' restart sent successfully", containerName)
	return nil
}
