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

package relay

import (
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/labstack/echo/v4"
)

// handleStreamEndpoint handles SSE streaming connections for a specific chat.
// GET /api/chats/:id/stream
func (r *RelayService) handleStreamEndpoint(c echo.Context) error {
	chatID := c.Param("id")
	if chatID == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "chat ID is required"})
	}

	// 1. Verify chat exists and user has access (authentication)
	if err := r.verifyChatAccess(c, chatID); err != nil {
		return c.JSON(http.StatusForbidden, map[string]string{"error": "access denied"})
	}

	// 2. Set SSE headers
	c.Response().Header().Set("Content-Type", "text/event-stream")
	c.Response().Header().Set("Cache-Control", "no-cache")
	c.Response().Header().Set("Connection", "keep-alive")
	c.Response().Header().Set("X-Accel-Buffering", "no") // Disable nginx buffering

	// 3. Create SSEConnection with writer, flusher, done channel
	flusher, ok := c.Response().Writer.(http.Flusher)
	if !ok {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "flusher not available"})
	}

	conn := &SSEConnection{
		chatID:    chatID,
		writer:    c.Response().Writer,
		flusher:   flusher,
		done:      make(chan struct{}),
		createdAt: time.Now(),
	}

	// 4. Register connection in connections map (under chatID)
	r.registerConnection(chatID, conn)

	// 5. Send initial ping/keepalive messages periodically
	go r.sendKeepalive(conn)

	// 6. Wait for client disconnect (done channel or context cancellation)
	<-c.Request().Context().Done()

	// 7. Clean up connection from registry on disconnect
	r.unregisterConnection(chatID, conn)
	close(conn.done)

	return nil
}

// verifyChatAccess verifies that the user has access to the specified chat.
// This is a placeholder - implement actual authentication based on your auth system.
func (r *RelayService) verifyChatAccess(c echo.Context, chatID string) error {
	// Check if chat exists
	_, err := r.app.FindRecordById("chats", chatID)
	if err != nil {
		return fmt.Errorf("chat not found")
	}

	// TODO: Implement actual user authentication and access control
	// This could involve:
	// - Checking if user is authenticated (c.Get("user_id"))
	// - Verifying user is a participant in the chat
	// - Checking any role-based access permissions

	return nil
}

// registerConnection adds a connection to the registry for the specified chat.
func (r *RelayService) registerConnection(chatID string, conn *SSEConnection) {
	r.connectionsMu.Lock()
	defer r.connectionsMu.Unlock()

	r.connections[chatID] = append(r.connections[chatID], conn)
	r.app.Logger().Debug("[Relay/Stream] Registered SSE connection", "chatID", chatID, "totalConnections", len(r.connections[chatID]))
}

// unregisterConnection removes a connection from the registry.
func (r *RelayService) unregisterConnection(chatID string, conn *SSEConnection) {
	r.connectionsMu.Lock()
	defer r.connectionsMu.Unlock()

	conns := r.connections[chatID]
	for i, c := range conns {
		if c == conn {
			// Remove connection by swapping with last element
			conns[i] = conns[len(conns)-1]
			r.connections[chatID] = conns[:len(conns)-1]
			break
		}
	}

	r.app.Logger().Debug("[Relay/Stream] Unregistered SSE connection", "chatID", chatID, "remainingConnections", len(r.connections[chatID]))

	// Clean up empty chat entries
	if len(r.connections[chatID]) == 0 {
		delete(r.connections, chatID)
	}
}

// sendKeepalive periodically sends ping events to keep the connection alive.
func (r *RelayService) sendKeepalive(conn *SSEConnection) {
	ticker := time.NewTicker(15 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			// Send ping event
			fmt.Fprintf(conn.writer, ": ping\n\n")
			conn.flusher.Flush()
		case <-conn.done:
			return
		}
	}
}

// broadcastToChat sends an SSE event to all connected clients for a specific chat.
// Locks the connections mutex for reading, sends SSE events to all clients for the chat,
// handles write errors by removing dead connections, and unlocks the mutex.
func (r *RelayService) broadcastToChat(chatID string, eventType string, data interface{}) {
	// 1. Lock the connections mutex for reading
	r.connectionsMu.RLock()
	defer r.connectionsMu.RUnlock()

	// 2. Look up all connections for the given chatID
	conns := r.connections[chatID]
	if len(conns) == 0 {
		return
	}

	// 3. Format the SSE event
	jsonData, err := json.Marshal(data)
	if err != nil {
		r.app.Logger().Error("[Relay/Stream] Failed to marshal broadcast data", "error", err)
		return
	}

	event := fmt.Sprintf("event: %s\ndata: %s\n\n", eventType, string(jsonData))

	// 4. Write to each connection and flush
	for _, conn := range conns {
		select {
		case <-conn.done:
			// Connection is closed, skip
			continue
		default:
			_, err := fmt.Fprint(conn.writer, event)
			if err != nil {
				// 5. Handle write errors gracefully - remove dead connections
				r.app.Logger().Warn("[Relay/Stream] SSE write error, removing dead connection", "chatID", chatID, "error", err)
				go r.removeConnection(chatID, conn)
				continue
			}
			conn.flusher.Flush()
		}
	}
}

// removeConnection safely removes a connection from the registry.
// Called asynchronously when a write error occurs.
func (r *RelayService) removeConnection(chatID string, conn *SSEConnection) {
	r.connectionsMu.Lock()
	defer r.connectionsMu.Unlock()

	conns := r.connections[chatID]
	for i, c := range conns {
		if c == conn {
			// Remove this connection from the slice
			r.connections[chatID] = append(conns[:i], conns[i+1:]...)
			close(conn.done)
			r.app.Logger().Info("[Relay/Stream] Removed dead SSE connection", "chatID", chatID, "remaining", len(r.connections[chatID]))
			return
		}
	}
}

// broadcastTextDelta sends a text_delta event for a text part.
func (r *RelayService) broadcastTextDelta(chatID string, partID string, text string) {
	eventData := map[string]interface{}{
		"type":   "text_delta",
		"partID": partID,
		"text":   text,
	}
	r.broadcastToChat(chatID, "text_delta", eventData)
}

// broadcastToolStatus sends a tool_status event for a tool part.
func (r *RelayService) broadcastToolStatus(chatID string, partID string, tool string, status string) {
	eventData := map[string]interface{}{
		"type":   "tool_status",
		"partID": partID,
		"tool":   tool,
		"status": status,
	}
	r.broadcastToChat(chatID, "tool_status", eventData)
}

// broadcastMessageComplete sends a message_complete event when a message finishes.
func (r *RelayService) broadcastMessageComplete(chatID string, messageID string, parts []interface{}) {
	eventData := map[string]interface{}{
		"type":      "message_complete",
		"messageID": messageID,
		"parts":     parts,
	}
	r.broadcastToChat(chatID, "message_complete", eventData)
}

// broadcastError sends an error event to connected clients.
func (r *RelayService) broadcastError(chatID string, errorMessage string) {
	eventData := map[string]interface{}{
		"type":    "error",
		"message": errorMessage,
	}
	r.broadcastToChat(chatID, "error", eventData)
}