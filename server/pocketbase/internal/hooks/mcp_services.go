package hooks

import (
	"os"

	acpsdk "github.com/coder/acp-go-sdk"
)

const (
	mcpGatewayExtensionName = "gateway"
	mcpGatewayURL           = "http://mcp-gateway:8811/mcp"
	cogneeExtensionName     = "cognee"
	cogneeURL               = "http://cognee:8000/mcp"
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

// CogneeMcpServer returns the memory service in the same standard ACP shape.
func CogneeMcpServer() *acpsdk.McpServer {
	return &acpsdk.McpServer{Http: &acpsdk.McpServerHttpInline{Type: "http", Name: cogneeExtensionName, Url: cogneeURL}}
}
