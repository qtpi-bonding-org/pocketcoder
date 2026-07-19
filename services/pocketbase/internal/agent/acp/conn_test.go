package acp

import (
	"context"

	acpsdk "github.com/coder/acp-go-sdk"
)

// Fails to build until Conn declares SetSessionConfigOption + UnstableDeleteSession.
var _ = func(c Conn) {
	var _ func(context.Context, acpsdk.SetSessionConfigOptionRequest) (acpsdk.SetSessionConfigOptionResponse, error) = c.SetSessionConfigOption
	var _ func(context.Context, acpsdk.UnstableDeleteSessionRequest) (acpsdk.UnstableDeleteSessionResponse, error) = c.UnstableDeleteSession
}
