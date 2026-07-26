package hooks

import (
	"context"
	"encoding/json"
	"fmt"

	acpsdk "github.com/coder/acp-go-sdk"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/acp"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/coordinator"
)

type fakeImportAdminConn struct {
	byScheduleID map[string]string
}

func (f *fakeImportAdminConn) Initialize(context.Context, acpsdk.InitializeRequest) (acpsdk.InitializeResponse, error) {
	return acpsdk.InitializeResponse{}, nil
}
func (f *fakeImportAdminConn) NewSession(context.Context, acpsdk.NewSessionRequest) (acpsdk.NewSessionResponse, error) {
	return acpsdk.NewSessionResponse{}, nil
}
func (f *fakeImportAdminConn) LoadSession(context.Context, acpsdk.LoadSessionRequest) (acpsdk.LoadSessionResponse, error) {
	return acpsdk.LoadSessionResponse{}, nil
}
func (f *fakeImportAdminConn) SetSessionMode(context.Context, acpsdk.SetSessionModeRequest) (acpsdk.SetSessionModeResponse, error) {
	return acpsdk.SetSessionModeResponse{}, nil
}
func (f *fakeImportAdminConn) SetSessionConfigOption(context.Context, acpsdk.SetSessionConfigOptionRequest) (acpsdk.SetSessionConfigOptionResponse, error) {
	return acpsdk.SetSessionConfigOptionResponse{}, nil
}
func (f *fakeImportAdminConn) CallExtension(_ context.Context, method string, params any) (json.RawMessage, error) {
	p, ok := params.(listScheduleSessionsParams)
	if !ok {
		return nil, fmt.Errorf("unexpected params type %T for method %s", params, method)
	}
	resp, ok := f.byScheduleID[p.ScheduleID]
	if !ok {
		return json.RawMessage(`{"sessions":[]}`), nil
	}
	return json.RawMessage(resp), nil
}
func (f *fakeImportAdminConn) Prompt(context.Context, acpsdk.PromptRequest) (acpsdk.PromptResponse, error) {
	return acpsdk.PromptResponse{}, nil
}
func (f *fakeImportAdminConn) Cancel(context.Context, acpsdk.CancelNotification) error { return nil }
func (f *fakeImportAdminConn) UnstableDeleteSession(context.Context, acpsdk.UnstableDeleteSessionRequest) (acpsdk.UnstableDeleteSessionResponse, error) {
	return acpsdk.UnstableDeleteSessionResponse{}, nil
}
func (f *fakeImportAdminConn) Close() error { return nil }

var _ acp.Conn = (*fakeImportAdminConn)(nil)

func fakeImportCoordWith(fc *fakeImportAdminConn) func() *coordinator.Coordinator {
	coord, err := coordinator.New(coordinator.Config{
		GooseURL: "ws://unused", GooseSecret: "x", Workspace: "/tmp",
		Dial: func(ctx context.Context, client acpsdk.Client) (acp.Conn, error) {
			return fc, nil
		},
	})
	if err != nil {
		panic(err)
	}
	return func() *coordinator.Coordinator { return coord }
}
