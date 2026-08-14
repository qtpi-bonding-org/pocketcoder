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

// @pocketcoder-core: Logs API. Native Docker log streaming via SSE.
package api

import (
	"bufio"
	"context"
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"net/http"
	"regexp"
	"strings"

	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/dockerapi"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/operation"
)

var safeContainerName = regexp.MustCompile(`^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,127}$`)

// dockerLogSource streams a container's combined stdout/stderr log,
// multiplexed in Docker's frame format, starting from the last 100 lines.
type dockerLogSource interface {
	StreamLogs(ctx context.Context, containerName string) (io.ReadCloser, error)
}

// errLogsUnavailable indicates the upstream Docker proxy responded, but not
// with a usable log stream (e.g. unknown container) -- distinct from a
// connection failure to the proxy itself.
var errLogsUnavailable = errors.New("logs unavailable")

// dockerProxyLogSource is the production dockerLogSource, backed by the
// internal docker-socket-proxy.
type dockerProxyLogSource struct{}

func (dockerProxyLogSource) StreamLogs(ctx context.Context, containerName string) (io.ReadCloser, error) {
	body, err := dockerapi.New().StreamLogs(ctx, containerName, 100)
	if errors.Is(err, dockerapi.ErrContainerNotFound) {
		return nil, fmt.Errorf("%w: %v", errLogsUnavailable, err)
	}
	return body, err
}

const maxDockerLogFrameSize = 1 << 20

func decodeDockerFrame(r *bufio.Reader) (stream byte, payload []byte, err error) {
	var header [8]byte
	if _, err := io.ReadFull(r, header[:]); err != nil {
		return 0, nil, err
	}
	size := binary.BigEndian.Uint32(header[4:])
	if size > maxDockerLogFrameSize {
		return 0, nil, fmt.Errorf("docker log frame payload %d exceeds maximum %d", size, maxDockerLogFrameSize)
	}
	payload = make([]byte, int(size))
	if _, err := io.ReadFull(r, payload); err != nil {
		return 0, nil, err
	}
	return header[0], payload, nil
}

type LogsDeps struct {
	Source dockerLogSource // nil -> dockerProxyLogSource{}
}

func AddLogOperations(registry *operation.Registry, deps LogsDeps) {
	source := deps.Source
	if source == nil {
		source = dockerProxyLogSource{}
	}

	// 📜 Stream Container Logs (SSE)
	// This endpoint replaces Dozzle by providing a native SSE stream that the Flutter
	// app can consume to show real-time logs with custom styling.
	// Example: GET /api/pocketcoder/v1/logs/pocketcoder-sandbox
	registry.Add(operation.Route{OperationID: "streamContainerLogs", Method: http.MethodGet, Path: "/api/pocketcoder/v1/logs/{containerName}", Auth: true, Direct: true, Action: func(re *core.RequestEvent) error {
		// 🛡️ Security Gate: Only allow authenticated admins to stream system logs.
		if err := requireRole(re, "admin"); err != nil {
			return err
		}

		containerName := re.Request.PathValue("containerName")
		if containerName == "" {
			return re.BadRequestError("Container name is required.", nil)
		}
		if !safeContainerName.MatchString(containerName) {
			return re.BadRequestError("Invalid container name.", nil)
		}

		body, err := source.StreamLogs(re.Request.Context(), containerName)
		if err != nil {
			if errors.Is(err, errLogsUnavailable) {
				return re.NotFoundError("Logs unavailable", nil)
			}
			return re.InternalServerError("Failed to connect to docker proxy", err)
		}
		defer body.Close()

		// Set HTTP headers for Server-Sent Events (SSE).
		re.Response.Header().Set("Content-Type", "text/event-stream")
		re.Response.Header().Set("Cache-Control", "no-cache")
		re.Response.Header().Set("Connection", "keep-alive")
		re.Response.Header().Set("Transfer-Encoding", "chunked")
		re.Response.WriteHeader(http.StatusOK)

		// Reader for demuxing Docker's multiplexed log stream.
		// Each frame starts with an 8-byte header: [streamType, 0, 0, 0, size1, size2, size3, size4]
		reader := bufio.NewReader(body)

		for {
			_, payload, err := decodeDockerFrame(reader)
			if err != nil {
				// Connection closed, truncated, or malformed upstream frame.
				break
			}

			// Format each log line as an SSE data packet.
			msg := string(payload)
			lines := strings.Split(msg, "\n")
			for _, line := range lines {
				trimmed := strings.TrimSpace(line)
				if trimmed != "" {
					fmt.Fprintf(re.Response, "data: %s\n\n", trimmed)
				}
			}

			// Flush to ensure the client receives the data immediately.
			if f, ok := re.Response.(http.Flusher); ok {
				f.Flush()
			}
		}

		return nil
	}})
}
