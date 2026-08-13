package hooks_test

import (
	"encoding/base64"
	"encoding/json"
	"testing"

	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/hooks"
)

func TestMemoryMcpServerEncodesUnicodeIdentity(t *testing.T) {
	server, err := hooks.MemoryMcpServer("family", "profile-1", "Pocó 🌱")
	if err != nil {
		t.Fatal(err)
	}
	if server.Http == nil || server.Http.Name != "memory" || server.Http.Url != "http://pocket-memory:8000/mcp" {
		t.Fatalf("memory MCP server = %+v", server)
	}
	if len(server.Http.Headers) != 1 || server.Http.Headers[0].Name != "X-PocketCoder-Memory-Context" {
		t.Fatalf("memory headers = %+v", server.Http.Headers)
	}
	decoded, err := base64.RawURLEncoding.DecodeString(server.Http.Headers[0].Value)
	if err != nil {
		t.Fatal(err)
	}
	var identity struct {
		Version        int    `json:"version"`
		AccountID      string `json:"account_id"`
		AgentProfileID string `json:"agent_profile_id"`
		AgentName      string `json:"agent_name"`
	}
	if err := json.Unmarshal(decoded, &identity); err != nil {
		t.Fatal(err)
	}
	if identity.Version != 1 || identity.AccountID != "family" || identity.AgentProfileID != "profile-1" || identity.AgentName != "Pocó 🌱" {
		t.Fatalf("decoded identity = %+v", identity)
	}
}

func TestMemoryMcpServerRejectsIncompleteIdentity(t *testing.T) {
	if _, err := hooks.MemoryMcpServer("family", "", "Poco"); err == nil {
		t.Fatal("expected empty profile identity to be rejected")
	}
}
