package hooks

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"os"

	acpsdk "github.com/coder/acp-go-sdk"
)

const (
	mcpGatewayExtensionName = "gateway"
	mcpGatewayURL           = "http://mcp-gateway:8811/mcp"
	memoryExtensionName     = "memory"
	memoryURL               = "http://pocket-memory:8000/mcp"
	memoryContextHeaderName = "X-PocketCoder-Memory-Context"
)

// McpGatewayHttpServer returns the gateway in the standard ACP shape used by
// every harness's session/new request.
func McpGatewayHttpServer() *acpsdk.McpServer {
	token := os.Getenv("MCP_GATEWAY_AUTH_TOKEN")
	if token == "" {
		return nil
	}
	return &acpsdk.McpServer{Http: &acpsdk.McpServerHttpInline{
		Type: "http", Name: mcpGatewayExtensionName, Url: mcpGatewayURL,
		Headers: []acpsdk.HttpHeader{{Name: "Authorization", Value: "Bearer " + token}},
	}}
}

// MemoryMcpServer returns the account/profile-attributed memory service in the
// same standard ACP shape used by every harness session.
func MemoryMcpServer(accountID, agentProfileID, agentName string) (*acpsdk.McpServer, error) {
	if accountID == "" || agentProfileID == "" || agentName == "" {
		return nil, fmt.Errorf("memory identity fields must not be empty")
	}
	context, err := json.Marshal(struct {
		Version        int    `json:"version"`
		AccountID      string `json:"account_id"`
		AgentProfileID string `json:"agent_profile_id"`
		AgentName      string `json:"agent_name"`
	}{
		Version:        1,
		AccountID:      accountID,
		AgentProfileID: agentProfileID,
		AgentName:      agentName,
	})
	if err != nil {
		return nil, fmt.Errorf("encode memory identity: %w", err)
	}
	return &acpsdk.McpServer{Http: &acpsdk.McpServerHttpInline{
		Type: "http", Name: memoryExtensionName, Url: memoryURL,
		Headers: []acpsdk.HttpHeader{{
			Name:  memoryContextHeaderName,
			Value: base64.RawURLEncoding.EncodeToString(context),
		}},
	}}, nil
}
