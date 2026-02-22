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
	"encoding/binary"
	"fmt"
	"io"
	"net/http"
	"strings"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
)

// RegisterLogsApi registers the native Docker log streaming endpoints.
func RegisterLogsApi(app *pocketbase.PocketBase, e *core.ServeEvent) {
	// 📜 Stream Container Logs (SSE)
	// This endpoint replaces Dozzle by providing a native SSE stream that the Flutter
	// app can consume to show real-time logs with custom styling.
	// Example: GET /api/pocketcoder/logs/pocketcoder-sandbox
	e.Router.GET("/api/pocketcoder/logs/{containerName}", func(re *core.RequestEvent) error {
		// 🛡️ Security Gate: Only allow authenticated admins to stream system logs.
		if re.Auth == nil || re.Auth.GetString("role") != "admin" {
			return re.ForbiddenError("Only admins can stream logs.", nil)
		}

		containerName := re.Request.PathValue("containerName")
		if containerName == "" {
			return re.BadRequestError("Container name is required.", nil)
		}

		// Docker API URL via the internal docker-socket-proxy.
		// We use follow=1 for real-time streaming and tail=100 for initial context.
		dockerUrl := fmt.Sprintf("http://docker-socket-proxy-write:2375/containers/%s/logs?follow=1&stdout=1&stderr=1&tail=100", containerName)

		resp, err := http.Get(dockerUrl)
		if err != nil {
			return re.InternalServerError("Failed to connect to docker proxy", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			return re.NotFoundError(fmt.Sprintf("Container %s not found or logs unavailable", containerName), nil)
		}

		// Set HTTP headers for Server-Sent Events (SSE).
		re.Response.Header().Set("Content-Type", "text/event-stream")
		re.Response.Header().Set("Cache-Control", "no-cache")
		re.Response.Header().Set("Connection", "keep-alive")
		re.Response.Header().Set("Transfer-Encoding", "chunked")
		re.Response.WriteHeader(http.StatusOK)

		// Reader for demuxing Docker's multiplexed log stream.
		// Each frame starts with an 8-byte header: [streamType, 0, 0, 0, size1, size2, size3, size4]
		reader := bufio.NewReader(resp.Body)
		
		for {
			header := make([]byte, 8)
			_, err := io.ReadFull(reader, header)
			if err != nil {
				// Connection closed or source stream ended.
				break
			}

			// streamType := header[0] // 0: stdin, 1: stdout, 2: stderr
			payloadSize := binary.BigEndian.Uint32(header[4:8])

			payload := make([]byte, payloadSize)
			_, err = io.ReadFull(reader, payload)
			if err != nil {
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
			re.Response.Flush()
		}

		return nil
	}).Bind(apis.RequireAuth())
}
