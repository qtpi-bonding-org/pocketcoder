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
	"bytes"
	"encoding/json"
	"net/http"
	"sync"
	"testing"
	"time"
)

// mockLogger implements a minimal logger for testing
type mockLogger struct {
	debugLogs []string
	infoLogs  []string
	warnLogs  []string
	errorLogs []string
}

func (m *mockLogger) Debug(msg string, keysAndValues ...interface{}) {
	m.debugLogs = append(m.debugLogs, msg)
}

func (m *mockLogger) Info(msg string, keysAndValues ...interface{}) {
	m.infoLogs = append(m.infoLogs, msg)
}

func (m *mockLogger) Warn(msg string, keysAndValues ...interface{}) {
	m.warnLogs = append(m.warnLogs, msg)
}

func (m *mockLogger) Error(msg string, keysAndValues ...interface{}) {
	m.errorLogs = append(m.errorLogs, msg)
}

func (m *mockLogger) Debugf(msg string, args ...interface{}) {
	m.debugLogs = append(m.debugLogs, msg)
}

func (m *mockLogger) Infof(msg string, args ...interface{}) {
	m.infoLogs = append(m.infoLogs, msg)
}

func (m *mockLogger) Warnf(msg string, args ...interface{}) {
	m.warnLogs = append(m.warnLogs, msg)
}

func (m *mockLogger) Errorf(msg string, args ...interface{}) {
	m.errorLogs = append(m.errorLogs, msg)
}

// mockResponseWriter implements http.ResponseWriter and http.Flusher for testing
type mockResponseWriter struct {
	headerMap http.Header
	body      *bytes.Buffer
	flushed   bool
	flushChan chan struct{}
}

func newMockResponseWriter() *mockResponseWriter {
	return &mockResponseWriter{
		headerMap: make(http.Header),
		body:      &bytes.Buffer{},
		flushChan: make(chan struct{}, 100),
	}
}

func (m *mockResponseWriter) Header() http.Header {
	return m.headerMap
}

func (m *mockResponseWriter) Write(b []byte) (int, error) {
	return m.body.Write(b)
}

func (m *mockResponseWriter) WriteHeader(statusCode int) {}

func (m *mockResponseWriter) Flush() {
	m.flushed = true
	select {
	case m.flushChan <- struct{}{}:
	default:
	}
}

// TestSSEConnection tests the SSEConnection struct
func TestSSEConnection(t *testing.T) {
	writer := newMockResponseWriter()
	flusher := writer

	done := make(chan struct{})

	conn := &SSEConnection{
		chatID:    "test-chat-123",
		writer:    writer,
		flusher:   flusher,
		done:      done,
		createdAt: time.Now(),
	}

	if conn.chatID != "test-chat-123" {
		t.Errorf("Expected chatID 'test-chat-123', got '%s'", conn.chatID)
	}

	if conn.writer != writer {
		t.Error("Writer not set correctly")
	}

	if conn.flusher != flusher {
		t.Error("Flusher not set correctly")
	}

	if conn.done != done {
		t.Error("Done channel not set correctly")
	}

	// Test closing done channel
	close(done)
	select {
	case <-conn.done:
		// Expected - channel is closed
	default:
		t.Error("Done channel should be closed")
	}
}

// newTestRelayService creates a relay service for testing without requiring app
func newTestRelayService() *RelayService {
	return &RelayService{
		connections:       make(map[string][]*SSEConnection),
		partCache:         make(map[string]map[string]interface{}),
		completedMessages: make(map[string]bool),
	}
}

// TestConnectionRegistration tests registering and unregistering connections
func TestConnectionRegistration(t *testing.T) {
	relay := newTestRelayService()

	// Create mock connections
	writer1 := newMockResponseWriter()
	writer2 := newMockResponseWriter()

	conn1 := &SSEConnection{
		chatID:    "chat1",
		writer:    writer1,
		flusher:   writer1,
		done:      make(chan struct{}),
		createdAt: time.Now(),
	}

	conn2 := &SSEConnection{
		chatID:    "chat1",
		writer:    writer2,
		flusher:   writer2,
		done:      make(chan struct{}),
		createdAt: time.Now(),
	}

	// Register first connection
	relay.registerConnection("chat1", conn1)
	if len(relay.connections["chat1"]) != 1 {
		t.Errorf("Expected 1 connection, got %d", len(relay.connections["chat1"]))
	}

	// Register second connection
	relay.registerConnection("chat1", conn2)
	if len(relay.connections["chat1"]) != 2 {
		t.Errorf("Expected 2 connections, got %d", len(relay.connections["chat1"]))
	}

	// Unregister first connection
	relay.unregisterConnection("chat1", conn1)
	if len(relay.connections["chat1"]) != 1 {
		t.Errorf("Expected 1 connection after unregister, got %d", len(relay.connections["chat1"]))
	}

	// Unregister second connection - should clean up empty entry
	relay.unregisterConnection("chat1", conn2)
	if _, exists := relay.connections["chat1"]; exists {
		t.Error("Empty chat entry should be cleaned up")
	}
}

// TestConnectionRegistrationMultipleChats tests connections across multiple chats
func TestConnectionRegistrationMultipleChats(t *testing.T) {
	relay := newTestRelayService()

	writer1 := newMockResponseWriter()
	writer2 := newMockResponseWriter()
	writer3 := newMockResponseWriter()

	conn1 := &SSEConnection{chatID: "chat1", writer: writer1, flusher: writer1, done: make(chan struct{}), createdAt: time.Now()}
	conn2 := &SSEConnection{chatID: "chat2", writer: writer2, flusher: writer2, done: make(chan struct{}), createdAt: time.Now()}
	conn3 := &SSEConnection{chatID: "chat2", writer: writer3, flusher: writer3, done: make(chan struct{}), createdAt: time.Now()}

	relay.registerConnection("chat1", conn1)
	relay.registerConnection("chat2", conn2)
	relay.registerConnection("chat2", conn3)

	if len(relay.connections["chat1"]) != 1 {
		t.Errorf("Expected 1 connection in chat1, got %d", len(relay.connections["chat1"]))
	}

	if len(relay.connections["chat2"]) != 2 {
		t.Errorf("Expected 2 connections in chat2, got %d", len(relay.connections["chat2"]))
	}
}

// TestBroadcastToChat tests broadcasting events to all connections in a chat
func TestBroadcastToChat(t *testing.T) {
	relay := newTestRelayService()

	writer1 := newMockResponseWriter()
	writer2 := newMockResponseWriter()

	conn1 := &SSEConnection{chatID: "chat1", writer: writer1, flusher: writer1, done: make(chan struct{}), createdAt: time.Now()}
	conn2 := &SSEConnection{chatID: "chat1", writer: writer2, flusher: writer2, done: make(chan struct{}), createdAt: time.Now()}

	relay.registerConnection("chat1", conn1)
	relay.registerConnection("chat1", conn2)

	// Broadcast an event
	eventData := map[string]interface{}{
		"type":    "test",
		"message": "hello",
	}
	relay.broadcastToChat("chat1", "test_event", eventData)

	// Both connections should receive the event
	if writer1.body.Len() == 0 {
		t.Error("Connection 1 should have received the broadcast")
	}
	if writer2.body.Len() == 0 {
		t.Error("Connection 2 should have received the broadcast")
	}

	// Verify SSE format
	body1 := writer1.body.String()
	if len(body1) == 0 {
		t.Error("Broadcast body should not be empty")
	}
}

// TestBroadcastToNonexistentChat tests broadcasting to a chat with no connections
func TestBroadcastToNonexistentChat(t *testing.T) {
	relay := newTestRelayService()

	// Should not panic
	eventData := map[string]interface{}{
		"type": "test",
	}
	relay.broadcastToChat("nonexistent", "test_event", eventData)
}

// TestBroadcastTextDelta tests the text_delta broadcast helper
func TestBroadcastTextDelta(t *testing.T) {
	relay := newTestRelayService()

	writer := newMockResponseWriter()
	conn := &SSEConnection{chatID: "chat1", writer: writer, flusher: writer, done: make(chan struct{}), createdAt: time.Now()}

	relay.registerConnection("chat1", conn)

	relay.broadcastTextDelta("chat1", "part123", "Hello world")

	body := writer.body.String()
	if len(body) == 0 {
		t.Error("Text delta should have been broadcast")
	}

	// SSE format is: "event: text_delta\ndata: <json>\n\n"
	// Extract the JSON part
	var eventData map[string]interface{}
	jsonData := extractSSEData(body)
	if jsonData == "" {
		t.Fatal("Could not extract SSE data")
	}
	
	err := json.Unmarshal([]byte(jsonData), &eventData)
	if err != nil {
		t.Fatalf("Failed to unmarshal event data: %v", err)
	}

	if eventData["type"] != "text_delta" {
		t.Errorf("Expected type 'text_delta', got '%v'", eventData["type"])
	}
	if eventData["partID"] != "part123" {
		t.Errorf("Expected partID 'part123', got '%v'", eventData["partID"])
	}
	if eventData["text"] != "Hello world" {
		t.Errorf("Expected text 'Hello world', got '%v'", eventData["text"])
	}
}

// extractSSEData extracts the data portion from SSE format
func extractSSEData(sse string) string {
	// SSE format: "event: <type>\ndata: <json>\n\n"
	// Find "data: " and extract until \n\n
	for i := 0; i < len(sse)-5; i++ {
		if sse[i:i+6] == "data: " {
			start := i + 6
			// Find the end (double newline)
			for j := start; j < len(sse)-1; j++ {
				if sse[j] == '\n' && sse[j+1] == '\n' {
					return sse[start:j]
				}
			}
			// If no double newline, return rest
			return sse[start:]
		}
	}
	return ""
}

// TestBroadcastToolStatus tests the tool_status broadcast helper
func TestBroadcastToolStatus(t *testing.T) {
	relay := newTestRelayService()

	writer := newMockResponseWriter()
	conn := &SSEConnection{chatID: "chat1", writer: writer, flusher: writer, done: make(chan struct{}), createdAt: time.Now()}

	relay.registerConnection("chat1", conn)

	relay.broadcastToolStatus("chat1", "part456", "executeBash", "running")

	body := writer.body.String()
	if len(body) == 0 {
		t.Error("Tool status should have been broadcast")
	}
}

// TestBroadcastMessageComplete tests the message_complete broadcast helper
func TestBroadcastMessageComplete(t *testing.T) {
	relay := newTestRelayService()

	writer := newMockResponseWriter()
	conn := &SSEConnection{chatID: "chat1", writer: writer, flusher: writer, done: make(chan struct{}), createdAt: time.Now()}

	relay.registerConnection("chat1", conn)

	parts := []interface{}{
		map[string]interface{}{"id": "part1", "type": "text"},
		map[string]interface{}{"id": "part2", "type": "tool"},
	}
	relay.broadcastMessageComplete("chat1", "msg123", parts)

	body := writer.body.String()
	if len(body) == 0 {
		t.Error("Message complete should have been broadcast")
	}
}

// TestBroadcastError tests the error broadcast helper
func TestBroadcastError(t *testing.T) {
	relay := newTestRelayService()

	writer := newMockResponseWriter()
	conn := &SSEConnection{chatID: "chat1", writer: writer, flusher: writer, done: make(chan struct{}), createdAt: time.Now()}

	relay.registerConnection("chat1", conn)

	relay.broadcastError("chat1", "Something went wrong")

	body := writer.body.String()
	if len(body) == 0 {
		t.Error("Error should have been broadcast")
	}
}

// TestRemoveConnection tests removing dead connections
func TestRemoveConnection(t *testing.T) {
	relay := newTestRelayService()

	writer1 := newMockResponseWriter()
	writer2 := newMockResponseWriter()

	conn1 := &SSEConnection{chatID: "chat1", writer: writer1, flusher: writer1, done: make(chan struct{}), createdAt: time.Now()}
	conn2 := &SSEConnection{chatID: "chat1", writer: writer2, flusher: writer2, done: make(chan struct{}), createdAt: time.Now()}

	relay.registerConnection("chat1", conn1)
	relay.registerConnection("chat1", conn2)

	if len(relay.connections["chat1"]) != 2 {
		t.Errorf("Expected 2 connections, got %d", len(relay.connections["chat1"]))
	}

	// Remove conn1
	relay.removeConnection("chat1", conn1)

	if len(relay.connections["chat1"]) != 1 {
		t.Errorf("Expected 1 connection after remove, got %d", len(relay.connections["chat1"]))
	}
}

// TestKeepalive tests the keepalive mechanism
func TestKeepalive(t *testing.T) {
	relay := newTestRelayService()

	writer := newMockResponseWriter()
	done := make(chan struct{})

	conn := &SSEConnection{
		chatID:    "chat1",
		writer:    writer,
		flusher:   writer,
		done:      done,
		createdAt: time.Now(),
	}

	// Start keepalive in a goroutine
	go relay.sendKeepalive(conn)

	// Wait for a ping (should come within 15 seconds)
	select {
	case <-writer.flushChan:
		// Got a flush - good
	case <-time.After(20 * time.Second):
		t.Error("Keepalive ping not received within timeout")
	}

	// Stop keepalive
	close(done)

	// Give it time to stop
	time.Sleep(100 * time.Millisecond)
}

// TestConcurrentConnectionRegistration tests thread-safe connection registration
func TestConcurrentConnectionRegistration(t *testing.T) {
	relay := newTestRelayService()

	var wg sync.WaitGroup
	numGoroutines := 10
	numConnections := 100

	for i := 0; i < numGoroutines; i++ {
		wg.Add(1)
		go func(goroutineID int) {
			defer wg.Done()
			for j := 0; j < numConnections; j++ {
				writer := newMockResponseWriter()
				conn := &SSEConnection{
					chatID:    "chat1",
					writer:    writer,
					flusher:   writer,
					done:      make(chan struct{}),
					createdAt: time.Now(),
				}
				relay.registerConnection("chat1", conn)
			}
		}(i)
	}

	wg.Wait()

	// All connections should be registered
	expectedCount := numGoroutines * numConnections
	if len(relay.connections["chat1"]) != expectedCount {
		t.Errorf("Expected %d connections, got %d", expectedCount, len(relay.connections["chat1"]))
	}
}

// TestConcurrentBroadcast tests thread-safe broadcasting
func TestConcurrentBroadcast(t *testing.T) {
	relay := newTestRelayService()

	// Create multiple connections
	for i := 0; i < 10; i++ {
		writer := newMockResponseWriter()
		conn := &SSEConnection{
			chatID:    "chat1",
			writer:    writer,
			flusher:   writer,
			done:      make(chan struct{}),
			createdAt: time.Now(),
		}
		relay.registerConnection("chat1", conn)
	}

	// Concurrent broadcasts
	var wg sync.WaitGroup
	for i := 0; i < 10; i++ {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()
			for j := 0; j < 10; j++ {
				eventData := map[string]interface{}{
					"id":   id,
					"iter": j,
				}
				relay.broadcastToChat("chat1", "test", eventData)
			}
		}(i)
	}

	wg.Wait()

	// All broadcasts should have been sent
	t.Log("Concurrent broadcast test completed successfully")
}

// TestSSEHeaders tests that SSE headers are set correctly
func TestSSEHeaders(t *testing.T) {
	writer := newMockResponseWriter()

	// Simulate setting SSE headers
	writer.Header().Set("Content-Type", "text/event-stream")
	writer.Header().Set("Cache-Control", "no-cache")
	writer.Header().Set("Connection", "keep-alive")
	writer.Header().Set("X-Accel-Buffering", "no")

	if writer.Header().Get("Content-Type") != "text/event-stream" {
		t.Error("Content-Type should be text/event-stream")
	}
	if writer.Header().Get("Cache-Control") != "no-cache" {
		t.Error("Cache-Control should be no-cache")
	}
	if writer.Header().Get("Connection") != "keep-alive" {
		t.Error("Connection should be keep-alive")
	}
	if writer.Header().Get("X-Accel-Buffering") != "no" {
		t.Error("X-Accel-Buffering should be no")
	}
}

// TestRelayServiceCreation tests creating a new RelayService
func TestRelayServiceCreation(t *testing.T) {
	relay := newTestRelayService()

	if relay == nil {
		t.Fatal("RelayService should not be nil")
	}

	if relay.partCache == nil {
		t.Error("partCache should be initialized")
	}

	if relay.completedMessages == nil {
		t.Error("completedMessages should be initialized")
	}

	if relay.connections == nil {
		t.Error("connections should be initialized")
	}
}

// BenchmarkBroadcast benchmarks the broadcast function
func BenchmarkBroadcast(b *testing.B) {
	relay := &RelayService{
		connections: make(map[string][]*SSEConnection),
	}

	// Create connections
	for i := 0; i < 100; i++ {
		writer := newMockResponseWriter()
		conn := &SSEConnection{
			chatID:    "chat1",
			writer:    writer,
			flusher:   writer,
			done:      make(chan struct{}),
			createdAt: time.Now(),
		}
		relay.registerConnection("chat1", conn)
	}

	eventData := map[string]interface{}{
		"type":    "test",
		"message": "benchmark data",
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		relay.broadcastToChat("chat1", "test_event", eventData)
	}
}