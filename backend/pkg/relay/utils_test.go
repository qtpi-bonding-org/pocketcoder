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
	"testing"
)

// mockRecord implements a minimal record for testing
type mockRecord struct {
	id             string
	collectionName string
	data           map[string]any
}

func (m *mockRecord) GetString(field string) string {
	if val, ok := m.data[field]; ok {
		if str, ok := val.(string); ok {
			return str
		}
	}
	return ""
}

// appFilterFinder interface for testing - only implements the method we need
type appFilterFinder interface {
	FindFirstRecordByFilter(collection any, filter string, params ...map[string]any) (*mockRecord, error)
}

// mockApp implements a minimal appFilterFinder interface for testing resolveChatID
type mockApp struct {
	records map[string]*mockRecord
}

func (m *mockApp) FindFirstRecordByFilter(collection any, filter string, params ...map[string]any) (*mockRecord, error) {
	// Simple filter matching for testing
	// Expected filters:
	// - "agent_id = {:id}" for main agent lookup
	// - "subagent_id = {:id}" for subagent lookup

	// Extract args map from variadic parameters
	var args map[string]any
	if len(params) > 0 {
		args = params[0]
	} else {
		args = make(map[string]any)
	}

	if collection == "chats" {
		for _, record := range m.records {
			if record.collectionName != "chats" {
				continue
			}
			if args["id"] == record.GetString("agent_id") {
				return record, nil
			}
		}
	}

	if collection == "subagents" {
		for _, record := range m.records {
			if record.collectionName != "subagents" {
				continue
			}
			if args["id"] == record.GetString("subagent_id") {
				return record, nil
			}
		}
	}

	return nil, nil
}

// relayServiceWithFilterFinder is a test version of RelayService that uses our test interface
type relayServiceWithFilterFinder struct {
	app appFilterFinder
}

func (r *relayServiceWithFilterFinder) resolveChatID(sessionID string) string {
	if sessionID == "" {
		return ""
	}

	// 1. Check if it's the main agent (Poco)
	record, err := r.app.FindFirstRecordByFilter("chats", "agent_id = {:id}", map[string]any{"id": sessionID})
	if err == nil && record != nil {
		return record.id
	}

	// 2. Check if it's a subagent
	subagent, err := r.app.FindFirstRecordByFilter("subagents", "subagent_id = {:id}", map[string]any{"id": sessionID})
	if err == nil && subagent != nil {
		// Resolve via delegating_agent_id -> chats.agent_id -> chats.id
		delegatingAgentID := subagent.GetString("delegating_agent_id")
		if delegatingAgentID == "" {
			return ""
		}
		chatRecord, err := r.app.FindFirstRecordByFilter("chats", "agent_id = {:id}", map[string]any{"id": delegatingAgentID})
		if err == nil && chatRecord != nil {
			return chatRecord.id
		}
	}

	return ""
}

// TestResolveChatID_MainAgent tests that resolveChatID correctly resolves
// a main agent via the agent_id field.
// Validates: Requirements 9.1
func TestResolveChatID_MainAgent(t *testing.T) {
	// Setup mock data
	chatRecord := &mockRecord{
		id:             "chat-uuid-abc",
		collectionName: "chats",
		data: map[string]any{
			"agent_id": "poco-session-123",
		},
	}

	mock := &mockApp{
		records: map[string]*mockRecord{
			"chat1": chatRecord,
		},
	}

	relay := &relayServiceWithFilterFinder{app: mock}

	// Test main agent resolution via agent_id
	result := relay.resolveChatID("poco-session-123")

	if result != "chat-uuid-abc" {
		t.Errorf("Expected chat ID 'chat-uuid-abc', got '%s'", result)
	}
}

// TestResolveChatID_Subagent tests that resolveChatID correctly resolves
// a subagent via delegating_agent_id -> chats.agent_id -> chats.id
// Validates: Requirements 9.2
func TestResolveChatID_Subagent(t *testing.T) {
	// Setup mock data
	parentChat := &mockRecord{
		id:             "chat-uuid-abc",
		collectionName: "chats",
		data: map[string]any{
			"agent_id": "poco-session-123",
		},
	}

	subagentRecord := &mockRecord{
		id:             "subagent-uuid-xyz",
		collectionName: "subagents",
		data: map[string]any{
			"subagent_id":          "subagent-xyz",
			"delegating_agent_id": "poco-session-123",
		},
	}

	mock := &mockApp{
		records: map[string]*mockRecord{
			"chat1":     parentChat,
			"subagent1": subagentRecord,
		},
	}

	relay := &relayServiceWithFilterFinder{app: mock}

	// Test subagent resolution via delegating_agent_id -> chats.agent_id
	result := relay.resolveChatID("subagent-xyz")

	if result != "chat-uuid-abc" {
		t.Errorf("Expected chat ID 'chat-uuid-abc', got '%s'", result)
	}
}

// TestResolveChatID_EmptySessionID tests that resolveChatID returns empty
// string for empty session ID.
func TestResolveChatID_EmptySessionID(t *testing.T) {
	mock := &mockApp{
		records: map[string]*mockRecord{},
	}

	relay := &relayServiceWithFilterFinder{app: mock}

	result := relay.resolveChatID("")

	if result != "" {
		t.Errorf("Expected empty string, got '%s'", result)
	}
}

// TestResolveChatID_NotFound tests that resolveChatID returns empty
// string when no matching chat or subagent is found.
func TestResolveChatID_NotFound(t *testing.T) {
	chatRecord := &mockRecord{
		id:             "chat-uuid-abc",
		collectionName: "chats",
		data: map[string]any{
			"agent_id": "poco-session-123",
		},
	}

	mock := &mockApp{
		records: map[string]*mockRecord{
			"chat1": chatRecord,
		},
	}

	relay := &relayServiceWithFilterFinder{app: mock}

	// Test with non-existent session ID
	result := relay.resolveChatID("non-existent-id")

	if result != "" {
		t.Errorf("Expected empty string, got '%s'", result)
	}
}

// TestResolveChatID_SubagentWithEmptyDelegatingAgentID tests that resolveChatID
// returns empty string when subagent has empty delegating_agent_id.
func TestResolveChatID_SubagentWithEmptyDelegatingAgentID(t *testing.T) {
	subagentRecord := &mockRecord{
		id:             "subagent-uuid-xyz",
		collectionName: "subagents",
		data: map[string]any{
			"subagent_id":          "subagent-xyz",
			"delegating_agent_id": "", // Empty delegating_agent_id
		},
	}

	mock := &mockApp{
		records: map[string]*mockRecord{
			"subagent1": subagentRecord,
		},
	}

	relay := &relayServiceWithFilterFinder{app: mock}

	result := relay.resolveChatID("subagent-xyz")

	if result != "" {
		t.Errorf("Expected empty string for subagent with empty delegating_agent_id, got '%s'", result)
	}
}