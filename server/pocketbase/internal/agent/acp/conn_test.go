package acp

import (
	"context"
	"encoding/json"

	acpsdk "github.com/coder/acp-go-sdk"
)

// Fails to build until Conn declares SetSessionConfigOption + UnstableDeleteSession.
var _ = func(c Conn) {
	var _ func(context.Context, acpsdk.SetSessionConfigOptionRequest) (acpsdk.SetSessionConfigOptionResponse, error) = c.SetSessionConfigOption
	var _ func(context.Context, acpsdk.UnstableDeleteSessionRequest) (acpsdk.UnstableDeleteSessionResponse, error) = c.UnstableDeleteSession
}

// Fails to build until Conn declares CallExtension.
var _ = func(c Conn) {
	var _ func(context.Context, string, any) (json.RawMessage, error) = c.CallExtension
}
