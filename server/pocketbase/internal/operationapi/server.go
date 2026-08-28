// Package operationapi binds PocketCoder's generated OpenAPI server to the
// existing PocketBase request context and direct operation actions.
package operationapi

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	acpsdk "github.com/coder/acp-go-sdk"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/agent/coordinator"
	"net/http"

	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/router"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/api"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/errorutil"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/filesystem"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/hooks"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/mcpserver"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/ollama"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/openapi"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/operation"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/schedule"
)

type requestEventContextKey struct{}

// requestEventFromContext extracts the *core.RequestEvent PocketBase stashes
// on ctx. Every strict handler needing PocketBase-native access (SetPathValue,
// auth, etc.) does this exact lookup -- shared here so the "missing request
// event" case is logged and wrapped in exactly one place instead of once per
// call site.
func requestEventFromContext(ctx context.Context) (*core.RequestEvent, error) {
	re, ok := ctx.Value(requestEventContextKey{}).(*core.RequestEvent)
	if !ok {
		return nil, errorutil.Internal("request context unavailable", errors.New("missing *core.RequestEvent in context"))
	}
	return re, nil
}

func harnessStatusResponse(status api.HarnessAuthStatusResponse) openapi.HarnessAuthStatus {
	response := openapi.HarnessAuthStatus{Harness: status.Harness, Provider: status.Provider, Status: status.Status, Mode: openapi.HarnessAuthStatusMode(status.Mode)}
	if status.AccountID != "" {
		response.AccountId = &status.AccountID
	}
	if status.AccountName != "" {
		response.AccountName = &status.AccountName
	}
	if status.Visibility != "" {
		response.Visibility = &status.Visibility
	}
	if status.LastError != "" {
		response.LastError = &status.LastError
	}
	if status.Attempt != nil {
		response.Attempt = &openapi.HarnessAuthAttempt{Id: status.Attempt.ID, Status: status.Attempt.Status}
		if status.Attempt.LastError != "" {
			response.Attempt.LastError = &status.Attempt.LastError
		}
	}
	if status.Challenge != nil {
		response.Challenge = &openapi.HarnessAuthChallenge{Type: status.Challenge.Type, Text: status.Challenge.Text}
		if status.Challenge.Target != "" {
			response.Challenge.Target = &status.Challenge.Target
		}
		if status.Challenge.Details != "" {
			response.Challenge.Details = &status.Challenge.Details
		}
	}
	return response
}

// authMiddleware enforces operation.Route.Auth uniformly for every
// operation reachable through the strict server, converted or not -- this
// replaces dispatch()'s inline "if route.Auth && re.Auth == nil" check,
// which becomes redundant once every operation runs through this
// middleware and is removed once all operations are converted off the
// strict-server middleware.
//
// One deliberate, accepted behavior change: the generated strict-server
// wrapper decodes a JSON request body BEFORE any StrictMiddlewareFunc
// runs (see e.g. pocketcoder.gen.go's PromptChat wrapper). So an
// unauthenticated request with a malformed JSON body now gets 400 (bad
// request body) instead of 401 (unauthorized) -- previously, dispatch()
// checked auth first and never reached body-binding for an unauthenticated
// caller. This is a minor, common, and accepted information-disclosure
// nuance (confirms "this endpoint parses JSON" to an unauthenticated
// caller, nothing more) -- not a security regression worth blocking this
// migration over.
func authMiddleware(registry *operation.Registry) openapi.StrictMiddlewareFunc {
	return func(f openapi.StrictHandlerFunc, operationID string) openapi.StrictHandlerFunc {
		return func(ctx context.Context, w http.ResponseWriter, r *http.Request, request any) (any, error) {
			route, ok := registry.Get(operationID)
			if !ok {
				return nil, errorutil.Internal("operation is not registered", errors.New("operation is not registered: "+operationID))
			}
			if route.Auth {
				re, err := requestEventFromContext(ctx)
				if err != nil {
					return nil, err
				}
				if re.Auth == nil {
					return nil, apis.NewUnauthorizedError("Authentication required", nil)
				}
			}
			return f(ctx, w, r, request)
		}
	}
}

// Register installs every PocketCoder operation from one registry. Ordinary
// request/response operations cross the generated strict server interface.
// Streaming, proxy, and binary operations remain direct because buffering
// those responses would alter their transport semantics.
func Register(app core.App, e *core.ServeEvent, coord func() coordinator.AgentRuntime) (coordinator.AgentRuntime, error) {
	registry := operation.NewRegistry()
	api.AddMcpOperations(app, registry, api.McpDeps{})
	api.AddMcpOAuthOperations(app, registry)
	api.AddProxyOperations(registry, api.ProxyDeps{})
	api.AddLogOperations(registry, api.LogsDeps{App: app})
	api.AddOllamaOperations(registry, api.OllamaDeps{})
	api.AddReleaseStatusOperations(registry)
	agentCoordinator, agentErr := api.AddAgentOperations(app, registry, api.AgentDeps{})
	filesystem.AddFileOperations(registry)
	hooks.AddPushOperations(app, registry)
	api.AddLiveActivityOperations(app, registry)
	harnessRuntime := api.AddHarnessAuthOperations(app, registry, api.HarnessAuthDeps{})
	scheduleRunner := api.AddScheduleOperations(app, registry, coord)

	operation.MountDirect(e, registry.Routes())
	strict := openapi.NewStrictHandlerWithOptions(
		&server{registry: registry, app: app, agent: agentCoordinator, agentErr: agentErr, scheduleRunner: scheduleRunner, harnessRuntime: harnessRuntime},
		[]openapi.StrictMiddlewareFunc{authMiddleware(registry)},
		openapi.StrictHTTPServerOptions{
			// router.ErrorHandler already produces this project's
			// ErrorResponse shape ({status, message, data}) as of the
			// 2026-08-27 OpenAPI schema fix -- both function signatures
			// are identical (func(http.ResponseWriter, *http.Request,
			// error)), so no wrapper is needed.
			RequestErrorHandlerFunc:  router.ErrorHandler,
			ResponseErrorHandlerFunc: router.ErrorHandler,
		},
	)
	handler := openapi.Handler(strict)
	e.Router.Route("", "/api/pocketcoder/v1/{path...}", func(re *core.RequestEvent) error {
		request := re.Request.WithContext(context.WithValue(re.Request.Context(), requestEventContextKey{}, re))
		re.Request = request
		handler.ServeHTTP(re.Response, request)
		return nil
	})
	return agentCoordinator, agentErr
}

type server struct {
	registry       *operation.Registry
	app            core.App
	agent          coordinator.AgentRuntime
	agentErr       error
	scheduleRunner *schedule.Runner
	harnessRuntime api.HarnessAuthRuntime
}

func (s *server) CancelChatSession(ctx context.Context, request openapi.CancelChatSessionRequestObject) (openapi.CancelChatSessionResponseObject, error) {
	if s.agentErr != nil {
		return nil, errorutil.Internal("retrieve agent runtime", s.agentErr)
	}
	re, err := requestEventFromContext(ctx)
	if err != nil {
		return nil, err
	}
	re.Request.SetPathValue("chatId", string(request.ChatId))
	if err := api.CancelChatSession(s.app, s.agent, re); err != nil {
		return nil, errorutil.Internal("cancel chat session", err)
	}
	return openapi.CancelChatSession202Response{}, nil
}

func (s *server) agentRequestEvent(ctx context.Context, chatID string) (*core.RequestEvent, error) {
	if s.agentErr != nil {
		return nil, errorutil.Internal("retrieve agent runtime", s.agentErr)
	}
	re, err := requestEventFromContext(ctx)
	if err != nil {
		return nil, err
	}
	re.Request.SetPathValue("chatId", chatID)
	if _, err := api.RequireOwnedRecordForOperation(s.app, re, "chats", chatID); err != nil {
		return nil, err
	}
	return re, nil
}
func (s *server) RespondToElicitation(ctx context.Context, request openapi.RespondToElicitationRequestObject) (openapi.RespondToElicitationResponseObject, error) {
	re, err := s.agentRequestEvent(ctx, string(request.ChatId))
	if err != nil {
		return nil, err
	}
	var input struct {
		Action  string         `json:"action"`
		Content map[string]any `json:"content,omitempty"`
	}
	b, err := json.Marshal(request.Body)
	if err != nil {
		return nil, apis.NewBadRequestError("invalid elicitation response format", nil)
	}
	if err := json.Unmarshal(b, &input); err != nil {
		return nil, re.BadRequestError("Invalid elicitation response", err)
	}
	var resp acpsdk.UnstableCreateElicitationResponse
	switch input.Action {
	case "accept":
		resp.Accept = &acpsdk.UnstableCreateElicitationAccept{Action: "accept", Content: input.Content}
	case "decline":
		resp.Decline = &acpsdk.UnstableCreateElicitationDecline{Action: "decline"}
	case "cancel":
		resp.Cancel = &acpsdk.UnstableCreateElicitationCancel{Action: "cancel"}
	default:
		return nil, re.BadRequestError("action must be accept, decline, or cancel", nil)
	}
	if err := api.RespondToElicitation(re, s.agent, string(request.ChatId), string(request.Id), resp); err != nil {
		return nil, errorutil.Internal("respond to elicitation", err)
	}
	return openapi.RespondToElicitation202Response{}, nil
}
func (s *server) PromptChat(ctx context.Context, request openapi.PromptChatRequestObject) (openapi.PromptChatResponseObject, error) {
	re, err := s.agentRequestEvent(ctx, string(request.ChatId))
	if err != nil {
		return nil, err
	}
	if body, ok := re.Request.Body.(router.Rereader); ok {
		body.Reread()
	}
	runID, err := api.PromptChat(s.app, s.agent, ollama.ResolveBaseURL(), re)
	if err != nil {
		return nil, errorutil.Internal("prompt chat", err)
	}
	return openapi.PromptChat202JSONResponse{RunId: runID}, nil
}
func (s *server) RespondToPermission(ctx context.Context, request openapi.RespondToPermissionRequestObject) (openapi.RespondToPermissionResponseObject, error) {
	re, err := s.agentRequestEvent(ctx, string(request.ChatId))
	if err != nil {
		return nil, err
	}
	var input acpsdk.RequestPermissionResponse
	b, err := json.Marshal(request.Body)
	if err != nil {
		return nil, apis.NewBadRequestError("invalid permission response format", nil)
	}
	if err := json.Unmarshal(b, &input); err != nil {
		return nil, re.BadRequestError("Invalid permission response", err)
	}
	if err := api.RespondToPermission(re, s.agent, string(request.ChatId), string(request.Id), input); err != nil {
		return nil, errorutil.Internal("respond to permission", err)
	}
	return openapi.RespondToPermission202Response{}, nil
}
func (s *server) SetChatConfigOption(ctx context.Context, request openapi.SetChatConfigOptionRequestObject) (openapi.SetChatConfigOptionResponseObject, error) {
	re, err := s.agentRequestEvent(ctx, string(request.ChatId))
	if err != nil {
		return nil, err
	}
	if request.Body == nil || strings.TrimSpace(request.Body.ConfigId) == "" || strings.TrimSpace(request.Body.Value) == "" {
		return nil, re.BadRequestError("a config option value is required", nil)
	}
	req := acpsdk.SetSessionConfigOptionRequest{ValueId: &acpsdk.SetSessionConfigOptionValueId{ConfigId: acpsdk.SessionConfigId(request.Body.ConfigId), Value: acpsdk.SessionConfigValueId(request.Body.Value)}}
	if err := api.SetChatConfigOption(re, s.agent, string(request.ChatId), req); err != nil {
		return nil, errorutil.Internal("set chat config option", err)
	}
	return openapi.SetChatConfigOption202Response{}, nil
}
func (s *server) SetChatMode(ctx context.Context, request openapi.SetChatModeRequestObject) (openapi.SetChatModeResponseObject, error) {
	re, err := s.agentRequestEvent(ctx, string(request.ChatId))
	if err != nil {
		return nil, err
	}
	if request.Body == nil || strings.TrimSpace(request.Body.ModeId) == "" {
		return nil, re.BadRequestError("modeId is required", nil)
	}
	if err := api.SetChatMode(re, s.agent, string(request.ChatId), request.Body.ModeId); err != nil {
		return nil, errorutil.Internal("set chat mode", err)
	}
	return openapi.SetChatMode202Response{}, nil
}
func (s *server) StreamChatEvents(ctx context.Context, _ openapi.StreamChatEventsRequestObject) (openapi.StreamChatEventsResponseObject, error) {
	return nil, errors.New("stream operation is mounted directly")
}
func (s *server) GetWorkspaceFile(ctx context.Context, _ openapi.GetWorkspaceFileRequestObject) (openapi.GetWorkspaceFileResponseObject, error) {
	return nil, errors.New("direct operation is mounted separately")
}
func (s *server) ListWorkspaceFiles(ctx context.Context, _ openapi.ListWorkspaceFilesRequestObject) (openapi.ListWorkspaceFilesResponseObject, error) {
	re, err := requestEventFromContext(ctx)
	if err != nil {
		return nil, err
	}
	path, entries, err := filesystem.ListWorkspaceFiles(re)
	if err != nil {
		return nil, errorutil.Internal("list workspace files", err)
	}
	result := make([]openapi.FileEntry, 0, len(entries))
	for _, entry := range entries {
		result = append(result, openapi.FileEntry{Name: entry.Name, IsDir: entry.IsDir, Size: entry.Size, ModTime: entry.ModTime})
	}
	return openapi.ListWorkspaceFiles200JSONResponse{Path: path, Entries: result}, nil
}
func (s *server) CancelHarnessAuth(ctx context.Context, _ openapi.CancelHarnessAuthRequestObject) (openapi.CancelHarnessAuthResponseObject, error) {
	re, err := requestEventFromContext(ctx)
	if err != nil {
		return nil, err
	}
	status, err := api.CancelHarnessAuth(s.app, s.harnessRuntime, re)
	if err != nil {
		return nil, errorutil.Internal("cancel harness auth", err)
	}
	return openapi.CancelHarnessAuth200JSONResponse(harnessStatusResponse(status)), nil
}
func (s *server) DisconnectHarnessAuth(ctx context.Context, _ openapi.DisconnectHarnessAuthRequestObject) (openapi.DisconnectHarnessAuthResponseObject, error) {
	re, err := requestEventFromContext(ctx)
	if err != nil {
		return nil, err
	}
	status, err := api.DisconnectHarnessAuth(s.app, s.harnessRuntime, re)
	if err != nil {
		return nil, errorutil.Internal("disconnect harness auth", err)
	}
	return openapi.DisconnectHarnessAuth200JSONResponse(harnessStatusResponse(status)), nil
}
func (s *server) PollHarnessAuth(ctx context.Context, _ openapi.PollHarnessAuthRequestObject) (openapi.PollHarnessAuthResponseObject, error) {
	re, err := requestEventFromContext(ctx)
	if err != nil {
		return nil, err
	}
	status, err := api.PollHarnessAuth(s.app, s.harnessRuntime, re)
	if err != nil {
		return nil, errorutil.Internal("poll harness auth", err)
	}
	return openapi.PollHarnessAuth200JSONResponse(harnessStatusResponse(status)), nil
}
func (s *server) StartHarnessAuth(ctx context.Context, _ openapi.StartHarnessAuthRequestObject) (openapi.StartHarnessAuthResponseObject, error) {
	re, err := requestEventFromContext(ctx)
	if err != nil {
		return nil, err
	}
	status, err := api.StartHarnessAuth(s.app, s.harnessRuntime, re)
	if err != nil {
		return nil, errorutil.Internal("start harness auth", err)
	}
	return openapi.StartHarnessAuth200JSONResponse(harnessStatusResponse(status)), nil
}
func (s *server) GetHarnessAuthStatus(ctx context.Context, _ openapi.GetHarnessAuthStatusRequestObject) (openapi.GetHarnessAuthStatusResponseObject, error) {
	re, err := requestEventFromContext(ctx)
	if err != nil {
		return nil, err
	}
	status, err := api.GetHarnessAuthStatus(s.app, re)
	if err != nil {
		return nil, errorutil.Internal("get harness auth status", err)
	}
	response := openapi.GetHarnessAuthStatus200JSONResponse{Harness: status.Harness, Provider: status.Provider, Status: status.Status, Mode: openapi.HarnessAuthStatusMode(status.Mode)}
	if status.AccountID != "" {
		response.AccountId = &status.AccountID
	}
	if status.AccountName != "" {
		response.AccountName = &status.AccountName
	}
	if status.Visibility != "" {
		response.Visibility = &status.Visibility
	}
	if status.LastError != "" {
		response.LastError = &status.LastError
	}
	if status.Attempt != nil {
		response.Attempt = &openapi.HarnessAuthAttempt{Id: status.Attempt.ID, Status: status.Attempt.Status}
		if status.Attempt.LastError != "" {
			response.Attempt.LastError = &status.Attempt.LastError
		}
	}
	if status.Challenge != nil {
		response.Challenge = &openapi.HarnessAuthChallenge{Type: status.Challenge.Type, Text: status.Challenge.Text}
		if status.Challenge.Target != "" {
			response.Challenge.Target = &status.Challenge.Target
		}
		if status.Challenge.Details != "" {
			response.Challenge.Details = &status.Challenge.Details
		}
	}
	return response, nil
}
func (s *server) SubmitHarnessAuth(ctx context.Context, _ openapi.SubmitHarnessAuthRequestObject) (openapi.SubmitHarnessAuthResponseObject, error) {
	re, err := requestEventFromContext(ctx)
	if err != nil {
		return nil, err
	}
	status, err := api.SubmitHarnessAuth(s.app, s.harnessRuntime, re)
	if err != nil {
		return nil, errorutil.Internal("submit harness auth", err)
	}
	return openapi.SubmitHarnessAuth200JSONResponse(harnessStatusResponse(status)), nil
}
func (s *server) StreamContainerLogs(ctx context.Context, _ openapi.StreamContainerLogsRequestObject) (openapi.StreamContainerLogsResponseObject, error) {
	return nil, errors.New("stream operation is mounted directly")
}
func (s *server) ListContainers(ctx context.Context, _ openapi.ListContainersRequestObject) (openapi.ListContainersResponseObject, error) {
	return nil, errors.New("direct operation is mounted separately")
}
func (s *server) GetHarnessInstanceLogs(ctx context.Context, request openapi.GetHarnessInstanceLogsRequestObject) (openapi.GetHarnessInstanceLogsResponseObject, error) {
	return nil, errors.New("direct operation is mounted separately")
}
func (s *server) StoreMcpOAuthToken(ctx context.Context, _ openapi.StoreMcpOAuthTokenRequestObject) (openapi.StoreMcpOAuthTokenResponseObject, error) {
	re, err := requestEventFromContext(ctx)
	if err != nil {
		return nil, err
	}
	if err := api.StoreMcpOAuthToken(s.app, re); err != nil {
		return nil, errorutil.Internal("store MCP OAuth token", err)
	}
	return openapi.StoreMcpOAuthToken200JSONResponse{Stored: true}, nil
}
func (s *server) ExecuteMcpRequest(ctx context.Context, _ openapi.ExecuteMcpRequestRequestObject) (openapi.ExecuteMcpRequestResponseObject, error) {
	re, err := requestEventFromContext(ctx)
	if err != nil {
		return nil, err
	}
	result, err := api.ExecuteMcpRequest(s.app, mcpserver.ResolveImageDigest, re)
	if err != nil {
		return nil, errorutil.Internal("execute MCP request", err)
	}
	response := openapi.ExecuteMcpRequest200JSONResponse{Id: result.ID, Status: result.Status}
	if result.Synced {
		synced := true
		response.Synced = &synced
	}
	return response, nil
}
func (s *server) ListOllamaModels(ctx context.Context, _ openapi.ListOllamaModelsRequestObject) (openapi.ListOllamaModelsResponseObject, error) {
	re, err := requestEventFromContext(ctx)
	if err != nil {
		return nil, err
	}
	models, enabled, err := api.ListOllamaModels(re, ollama.HTTPClient(), ollama.ResolveBaseURL())
	if err != nil {
		return nil, errorutil.Internal("list Ollama models", err)
	}
	items := make([]map[string]interface{}, 0, len(models))
	for _, model := range models {
		items = append(items, map[string]interface{}{"name": model.Name, "size": model.Size})
	}
	return openapi.ListOllamaModels200JSONResponse{Enabled: enabled, Models: items}, nil
}
func (s *server) PullOllamaModel(ctx context.Context, _ openapi.PullOllamaModelRequestObject) (openapi.PullOllamaModelResponseObject, error) {
	return nil, errors.New("direct operation is mounted separately")
}
func (s *server) ProxyObservability(ctx context.Context, _ openapi.ProxyObservabilityRequestObject) (openapi.ProxyObservabilityResponseObject, error) {
	return nil, errors.New("direct operation is mounted separately")
}
func (s *server) SendPushNotification(ctx context.Context, _ openapi.SendPushNotificationRequestObject) (openapi.SendPushNotificationResponseObject, error) {
	re, err := requestEventFromContext(ctx)
	if err != nil {
		return nil, err
	}
	if err := hooks.SendPushOperation(s.app, re); err != nil {
		return nil, errorutil.Internal("send push notification", err)
	}
	return openapi.SendPushNotification200JSONResponse{Ok: true}, nil
}
func (s *server) EndLiveActivity(ctx context.Context, request openapi.EndLiveActivityRequestObject) (openapi.EndLiveActivityResponseObject, error) {
	re, err := requestEventFromContext(ctx)
	if err != nil {
		return nil, err
	}
	re.Request.SetPathValue("id", string(request.Id))
	if err := api.EndLiveActivity(s.app, re); err != nil {
		return nil, errorutil.Internal("end live activity", err)
	}
	return openapi.EndLiveActivity200JSONResponse{Ok: true}, nil
}
func (s *server) GetReleaseCompatibility(_ context.Context, _ openapi.GetReleaseCompatibilityRequestObject) (openapi.GetReleaseCompatibilityResponseObject, error) {
	dataVersion, compatibility := api.ReleaseCompatibility()
	compatMap, ok := compatibility.(map[string]any)
	if !ok {
		// compatibility is a json.RawMessage read off disk (see
		// api.ReleaseCompatibility) rather than the hardcoded
		// developmentCompatibility map -- the generated
		// ReleaseCompatibilityResponse.Compatibility field is strictly
		// typed as map[string]interface{}, so it has to be decoded here.
		// The old untyped re.JSON(...) call let this ambiguity pass
		// through to the JSON encoder unexamined; the strict response type
		// makes that shape assumption explicit.
		raw, isRaw := compatibility.(json.RawMessage)
		if !isRaw {
			return nil, errorutil.Internal("unexpected release compatibility value type", fmt.Errorf("unexpected release compatibility value type %T", compatibility))
		}
		if err := json.Unmarshal(raw, &compatMap); err != nil {
			return nil, errorutil.Internal("decode release compatibility document", fmt.Errorf("decode release compatibility document: %w", err))
		}
	}
	return openapi.GetReleaseCompatibility200JSONResponse{
		SchemaVersion: 1,
		DataVersion:   dataVersion,
		Compatibility: compatMap,
	}, nil
}
func (s *server) GetReleaseStatus(ctx context.Context, _ openapi.GetReleaseStatusRequestObject) (openapi.GetReleaseStatusResponseObject, error) {
	current, metadata, err := api.ReleaseStatus()
	if err != nil {
		return nil, apis.NewApiError(http.StatusInternalServerError, "release state unavailable", nil)
	}
	response := openapi.ReleaseStatusResponse{SchemaVersion: 1, MetadataStatus: metadata}
	response.Current.ReleaseDigest = &current.ReleaseDigest
	response.Current.SourceCommit = &current.SourceCommit
	response.Current.ServerVersion = &current.ServerVersion
	response.Current.DataVersion = &current.DataVersion
	response.Current.DeploymentContractVersion = &current.DeploymentContractVersion
	response.Current.SelectedHarnesses = &current.SelectedHarnesses
	return openapi.GetReleaseStatus200JSONResponse(response), nil
}
func (s *server) RunScheduleNow(ctx context.Context, request openapi.RunScheduleNowRequestObject) (openapi.RunScheduleNowResponseObject, error) {
	re, err := requestEventFromContext(ctx)
	if err != nil {
		return nil, err
	}
	re.Request.SetPathValue("scheduleId", request.ScheduleId)
	if err := api.RunScheduleNow(s.app, s.scheduleRunner, re); err != nil {
		return nil, errorutil.Internal("run schedule now", err)
	}
	return openapi.RunScheduleNow202JSONResponse{Status: openapi.ScheduleRunAcceptedResponseStatus("started")}, nil
}

var _ openapi.StrictServerInterface = (*server)(nil)
