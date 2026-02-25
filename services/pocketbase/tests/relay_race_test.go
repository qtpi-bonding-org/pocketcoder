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
	"fmt"
	"sort"
	"sync"
	"testing"
)

// TestMessagePartRaceConditions tests that message parts are correctly assembled
// regardless of the order in which part.updated and message.updated events arrive.
//
// This simulates the real-world scenario where:
// - OpenCode sends multiple message.part.updated events (tools, text)
// - OpenCode sends one message.updated event (completion)
// - Network/goroutine scheduling can cause these to arrive in ANY order
//
// We test ALL permutations to ensure the final result is always correct.
func TestMessagePartRaceConditions(t *testing.T) {
	// Define our mock events
	events := []mockEvent{
		// Tool part 1: executeBash
		{
			eventType: "part",
			part: map[string]interface{}{
				"id":        "prt_tool1",
				"messageID": "msg_test123",
				"type":      "tool",
				"name":      "executeBash",
				"input": map[string]interface{}{
					"command": "echo hello",
				},
				"state": map[string]interface{}{
					"status": "success",
					"output": "hello\n",
				},
			},
		},
		// Tool part 2: readFile
		{
			eventType: "part",
			part: map[string]interface{}{
				"id":        "prt_tool2",
				"messageID": "msg_test123",
				"type":      "tool",
				"name":      "readFile",
				"input": map[string]interface{}{
					"path": "test.txt",
				},
				"state": map[string]interface{}{
					"status": "success",
					"output": "file contents",
				},
			},
		},
		// Tool part 3: fsWrite
		{
			eventType: "part",
			part: map[string]interface{}{
				"id":        "prt_tool3",
				"messageID": "msg_test123",
				"type":      "tool",
				"name":      "fsWrite",
				"input": map[string]interface{}{
					"path": "output.txt",
					"text": "test data",
				},
				"state": map[string]interface{}{
					"status": "success",
					"output": "File written successfully",
				},
			},
		},
		// Text part 1: Initial response
		{
			eventType: "part",
			part: map[string]interface{}{
				"id":        "prt_text1",
				"messageID": "msg_test123",
				"type":      "text",
				"text":      "I'll help you with that. Let me run the command.",
			},
		},
		// Text part 2: Middle response
		{
			eventType: "part",
			part: map[string]interface{}{
				"id":        "prt_text2",
				"messageID": "msg_test123",
				"type":      "text",
				"text":      "Now let me read the file to verify.",
			},
		},
		// Text part 3: Final response
		{
			eventType: "part",
			part: map[string]interface{}{
				"id":        "prt_text3",
				"messageID": "msg_test123",
				"type":      "text",
				"text":      "Done! I've completed all the tasks.",
			},
		},
		// Completion event
		{
			eventType: "completion",
			info: map[string]interface{}{
				"id":   "msg_test123",
				"role": "assistant",
				"time": map[string]interface{}{
					"completed": float64(1234567890),
				},
			},
		},
	}

	// Expected final state: all 6 parts should be present
	expectedPartIDs := []string{
		"prt_tool1", "prt_tool2", "prt_tool3",
		"prt_text1", "prt_text2", "prt_text3",
	}

	// Generate all permutations
	permutations := generatePermutations(events)
	t.Logf("Testing %d permutations of %d events", len(permutations), len(events))

	// Test each permutation
	failedPermutations := 0
	for i, perm := range permutations {
		t.Run(fmt.Sprintf("Permutation_%d", i), func(t *testing.T) {
			// Create a fresh relay service for this test
			relay := newMockRelayService()

			// Process events in this permutation order
			for _, event := range perm {
				if event.eventType == "part" {
					relay.upsertMessagePartMock("chat_test", event.part)
				} else if event.eventType == "completion" {
					relay.handleMessageCompletionMock("chat_test", event.info)
				}
			}

			// Verify final state
			finalParts := relay.getFinalParts("msg_test123")
			if len(finalParts) != len(expectedPartIDs) {
				t.Errorf("Expected %d parts, got %d", len(expectedPartIDs), len(finalParts))
				failedPermutations++
				return
			}

			// Verify all expected part IDs are present
			actualPartIDs := make([]string, 0, len(finalParts))
			for _, part := range finalParts {
				if partMap, ok := part.(map[string]interface{}); ok {
					if id, ok := partMap["id"].(string); ok {
						actualPartIDs = append(actualPartIDs, id)
					}
				}
			}

			sort.Strings(actualPartIDs)
			sort.Strings(expectedPartIDs)

			for i, expectedID := range expectedPartIDs {
				if i >= len(actualPartIDs) || actualPartIDs[i] != expectedID {
					t.Errorf("Missing or mismatched part ID: expected %s, got %v", expectedID, actualPartIDs)
					failedPermutations++
					return
				}
			}
		})
	}

	if failedPermutations > 0 {
		t.Errorf("FAILED: %d/%d permutations failed", failedPermutations, len(permutations))
	} else {
		t.Logf("SUCCESS: All %d permutations passed", len(permutations))
	}
}

// mockEvent represents either a part.updated or message.updated event
type mockEvent struct {
	eventType string                 // "part" or "completion"
	part      map[string]interface{} // for part.updated
	info      map[string]interface{} // for message.updated
}

// mockRelayService is a minimal relay service for testing (no database)
type mockRelayService struct {
	partCache         map[string]map[string]interface{} // ocMsgID -> partID -> part
	partCacheMu       sync.Mutex
	completedMessages map[string]bool
	completedMu       sync.RWMutex
	msgMutexes        sync.Map // ocMsgID -> *sync.Mutex
	finalMessages     map[string][]interface{} // ocMsgID -> final parts array
	finalMu           sync.Mutex
}

func newMockRelayService() *mockRelayService {
	return &mockRelayService{
		partCache:         make(map[string]map[string]interface{}),
		completedMessages: make(map[string]bool),
		finalMessages:     make(map[string][]interface{}),
	}
}

// upsertMessagePartMock simulates the real upsertMessagePart logic without database
func (r *mockRelayService) upsertMessagePartMock(chatID string, part map[string]interface{}) {
	ocMsgID, _ := part["messageID"].(string)
	if ocMsgID == "" {
		return
	}
	partID, _ := part["id"].(string)

	// 1. Acquire per-message lock
	val, _ := r.msgMutexes.LoadOrStore(ocMsgID, &sync.Mutex{})
	mu := val.(*sync.Mutex)
	mu.Lock()
	defer mu.Unlock()

	// 2. Check if message already completed (late arrival)
	r.completedMu.RLock()
	isCompleted := r.completedMessages[ocMsgID]
	r.completedMu.RUnlock()

	if isCompleted {
		// Late arrival - patch the final message
		r.finalMu.Lock()
		if r.finalMessages[ocMsgID] == nil {
			r.finalMessages[ocMsgID] = make([]interface{}, 0)
		}
		// Check if part already exists
		found := false
		for i, existingPart := range r.finalMessages[ocMsgID] {
			if ep, ok := existingPart.(map[string]interface{}); ok {
				if ep["id"] == partID {
					r.finalMessages[ocMsgID][i] = part
					found = true
					break
				}
			}
		}
		if !found {
			r.finalMessages[ocMsgID] = append(r.finalMessages[ocMsgID], part)
		}
		r.finalMu.Unlock()
		return
	}

	// 3. Normal path - cache the part
	r.partCacheMu.Lock()
	if r.partCache[ocMsgID] == nil {
		r.partCache[ocMsgID] = make(map[string]interface{})
	}
	r.partCache[ocMsgID][partID] = part
	r.partCacheMu.Unlock()
}

// handleMessageCompletionMock simulates the real handleMessageCompletion logic
func (r *mockRelayService) handleMessageCompletionMock(chatID string, info map[string]interface{}) {
	ocMsgID, _ := info["id"].(string)
	if ocMsgID == "" {
		return
	}

	role, _ := info["role"].(string)
	if role != "assistant" {
		return
	}

	// 1. Acquire per-message lock
	val, _ := r.msgMutexes.LoadOrStore(ocMsgID, &sync.Mutex{})
	mu := val.(*sync.Mutex)
	mu.Lock()

	// 2. Flush cached parts
	r.partCacheMu.Lock()
	var cachedParts []interface{}
	if parts, ok := r.partCache[ocMsgID]; ok {
		for _, p := range parts {
			cachedParts = append(cachedParts, p)
		}
		delete(r.partCache, ocMsgID)
	}
	r.partCacheMu.Unlock()

	// 3. Store final message with parts
	r.finalMu.Lock()
	r.finalMessages[ocMsgID] = cachedParts
	r.finalMu.Unlock()

	// 4. Mark as completed
	r.completedMu.Lock()
	r.completedMessages[ocMsgID] = true
	r.completedMu.Unlock()

	// 5. Release lock
	mu.Unlock()
	r.msgMutexes.Delete(ocMsgID)
}

// getFinalParts returns the final assembled parts for a message
func (r *mockRelayService) getFinalParts(ocMsgID string) []interface{} {
	r.finalMu.Lock()
	defer r.finalMu.Unlock()
	
	parts := r.finalMessages[ocMsgID]
	if parts == nil {
		return []interface{}{}
	}
	
	// Return a copy to avoid race conditions
	result := make([]interface{}, len(parts))
	copy(result, parts)
	return result
}

// generatePermutations generates all permutations of the input slice
func generatePermutations(events []mockEvent) [][]mockEvent {
	var result [][]mockEvent
	permute(events, 0, &result)
	return result
}

func permute(events []mockEvent, start int, result *[][]mockEvent) {
	if start == len(events)-1 {
		// Make a copy of the current permutation
		perm := make([]mockEvent, len(events))
		copy(perm, events)
		*result = append(*result, perm)
		return
	}

	for i := start; i < len(events); i++ {
		events[start], events[i] = events[i], events[start]
		permute(events, start+1, result)
		events[start], events[i] = events[i], events[start]
	}
}

// TestMessagePartRaceConditions_Subset tests a smaller subset for faster iteration
func TestMessagePartRaceConditions_Subset(t *testing.T) {
	// Test just a few critical orderings
	testCases := []struct {
		name   string
		events []mockEvent
	}{
		{
			name: "Completion_First",
			events: []mockEvent{
				{eventType: "completion", info: map[string]interface{}{"id": "msg_test", "role": "assistant", "time": map[string]interface{}{"completed": float64(123)}}},
				{eventType: "part", part: map[string]interface{}{"id": "prt_1", "messageID": "msg_test", "type": "text", "text": "hello"}},
				{eventType: "part", part: map[string]interface{}{"id": "prt_2", "messageID": "msg_test", "type": "tool", "name": "test"}},
			},
		},
		{
			name: "Completion_Last",
			events: []mockEvent{
				{eventType: "part", part: map[string]interface{}{"id": "prt_1", "messageID": "msg_test", "type": "text", "text": "hello"}},
				{eventType: "part", part: map[string]interface{}{"id": "prt_2", "messageID": "msg_test", "type": "tool", "name": "test"}},
				{eventType: "completion", info: map[string]interface{}{"id": "msg_test", "role": "assistant", "time": map[string]interface{}{"completed": float64(123)}}},
			},
		},
		{
			name: "Completion_Middle",
			events: []mockEvent{
				{eventType: "part", part: map[string]interface{}{"id": "prt_1", "messageID": "msg_test", "type": "text", "text": "hello"}},
				{eventType: "completion", info: map[string]interface{}{"id": "msg_test", "role": "assistant", "time": map[string]interface{}{"completed": float64(123)}}},
				{eventType: "part", part: map[string]interface{}{"id": "prt_2", "messageID": "msg_test", "type": "tool", "name": "test"}},
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			relay := newMockRelayService()

			for _, event := range tc.events {
				if event.eventType == "part" {
					relay.upsertMessagePartMock("chat_test", event.part)
				} else if event.eventType == "completion" {
					relay.handleMessageCompletionMock("chat_test", event.info)
				}
			}

			finalParts := relay.getFinalParts("msg_test")
			if len(finalParts) != 2 {
				t.Errorf("Expected 2 parts, got %d", len(finalParts))
				t.Logf("Final parts: %+v", finalParts)
			}
		})
	}
}

// TestMessagePartContent verifies that part content is preserved correctly
func TestMessagePartContent(t *testing.T) {
	relay := newMockRelayService()

	// Send a tool part with complex state
	toolPart := map[string]interface{}{
		"id":        "prt_tool",
		"messageID": "msg_content_test",
		"type":      "tool",
		"name":      "executeBash",
		"input": map[string]interface{}{
			"command": "echo 'test output'",
		},
		"state": map[string]interface{}{
			"status": "success",
			"output": "test output\n",
			"metadata": map[string]interface{}{
				"exitCode": 0,
			},
		},
	}

	textPart := map[string]interface{}{
		"id":        "prt_text",
		"messageID": "msg_content_test",
		"type":      "text",
		"text":      "Here's the output: test output",
	}

	// Process in order: tool, text, completion
	relay.upsertMessagePartMock("chat_test", toolPart)
	relay.upsertMessagePartMock("chat_test", textPart)
	relay.handleMessageCompletionMock("chat_test", map[string]interface{}{
		"id":   "msg_content_test",
		"role": "assistant",
		"time": map[string]interface{}{"completed": float64(123)},
	})

	// Verify content
	finalParts := relay.getFinalParts("msg_content_test")
	if len(finalParts) != 2 {
		t.Fatalf("Expected 2 parts, got %d", len(finalParts))
	}

	// Find and verify tool part
	var foundTool, foundText bool
	for _, part := range finalParts {
		partMap := part.(map[string]interface{})
		partType := partMap["type"].(string)

		if partType == "tool" {
			foundTool = true
			state := partMap["state"].(map[string]interface{})
			output := state["output"].(string)
			if output != "test output\n" {
				t.Errorf("Tool output mismatch: expected 'test output\\n', got '%s'", output)
			}
		} else if partType == "text" {
			foundText = true
			text := partMap["text"].(string)
			if text != "Here's the output: test output" {
				t.Errorf("Text content mismatch: expected 'Here's the output: test output', got '%s'", text)
			}
		}
	}

	if !foundTool {
		t.Error("Tool part not found in final parts")
	}
	if !foundText {
		t.Error("Text part not found in final parts")
	}
}

// BenchmarkMessagePartPermutations benchmarks the permutation test
func BenchmarkMessagePartPermutations(b *testing.B) {
	events := []mockEvent{
		{eventType: "part", part: map[string]interface{}{"id": "prt_1", "messageID": "msg_bench", "type": "text"}},
		{eventType: "part", part: map[string]interface{}{"id": "prt_2", "messageID": "msg_bench", "type": "text"}},
		{eventType: "part", part: map[string]interface{}{"id": "prt_3", "messageID": "msg_bench", "type": "tool"}},
		{eventType: "completion", info: map[string]interface{}{"id": "msg_bench", "role": "assistant"}},
	}

	permutations := generatePermutations(events)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		for _, perm := range permutations {
			relay := newMockRelayService()
			for _, event := range perm {
				if event.eventType == "part" {
					relay.upsertMessagePartMock("chat_test", event.part)
				} else {
					relay.handleMessageCompletionMock("chat_test", event.info)
				}
			}
		}
	}
}
