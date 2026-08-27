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
	"net/http/httptest"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/router"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/api"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/filesystem"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/hooks"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/ollama"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/openapi"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/operation"
)

type requestEventContextKey struct{}

// authMiddleware enforces operation.Route.Auth uniformly for every
// operation reachable through the strict server, converted or not -- this
// replaces dispatch()'s inline "if route.Auth && re.Auth == nil" check,
// which becomes redundant once every operation runs through this
// middleware and is removed once all operations are converted off the
// rawResponse bridge.
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
				return nil, errors.New("operation is not registered: " + operationID)
			}
			if route.Auth {
				re, ok := ctx.Value(requestEventContextKey{}).(*core.RequestEvent)
				if !ok {
					return nil, errors.New("PocketBase request context is unavailable")
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
func Register(app *pocketbase.PocketBase, e *core.ServeEvent, coord func() coordinator.AgentRuntime) (coordinator.AgentRuntime, error) {
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
	api.AddHarnessAuthOperations(app, registry, api.HarnessAuthDeps{})
	api.AddScheduleOperations(app, registry, coord)

	operation.MountDirect(e, registry.Routes())
	strict := openapi.NewStrictHandlerWithOptions(
		&server{registry: registry, app: app, agent: agentCoordinator, agentErr: agentErr},
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
	registry *operation.Registry
	app      core.App
	agent    coordinator.AgentRuntime
	agentErr error
}

func (s *server) dispatch(ctx context.Context, operationID string, pathValues map[string]string) (rawResponse, error) {
	re, ok := ctx.Value(requestEventContextKey{}).(*core.RequestEvent)
	if !ok {
		return rawResponse{}, errors.New("PocketBase request context is unavailable")
	}
	route, ok := s.registry.Get(operationID)
	if !ok {
		return rawResponse{}, errors.New("operation is not registered: " + operationID)
	}
	if route.Direct {
		return rawResponse{}, errors.New("direct operation reached strict server: " + operationID)
	}
	for name, value := range pathValues {
		re.Request.SetPathValue(name, value)
	}
	if body, ok := re.Request.Body.(router.Rereader); ok {
		body.Reread()
	}

	recorder := httptest.NewRecorder()
	response := &router.ResponseWriter{ResponseWriter: recorder}
	previousResponse := re.Response
	re.Response = response
	defer func() { re.Response = previousResponse }()

	if err := route.Action(re); err != nil {
		router.ErrorHandler(response, re.Request, err)
	}
	result := recorder.Result()
	defer result.Body.Close()
	return rawResponse{status: result.StatusCode, header: result.Header, body: recorder.Body.Bytes()}, nil
}

// invokeAction is the temporary adapter for operations whose business logic
// still lives in a PocketBase Action. It returns the action's result to the
// strict method, which then constructs the operation-specific response type.
// Keeping this adapter separate makes the response contract explicit while
// the remaining handlers are migrated.
func (s *server) invokeAction(ctx context.Context, operationID string, pathValues map[string]string) (*httptest.ResponseRecorder, error) {
	re, ok := ctx.Value(requestEventContextKey{}).(*core.RequestEvent)
	if !ok {
		return nil, errors.New("PocketBase request context is unavailable")
	}
	route, ok := s.registry.Get(operationID)
	if !ok {
		return nil, errors.New("operation is not registered: " + operationID)
	}
	for name, value := range pathValues {
		re.Request.SetPathValue(name, value)
	}
	if body, ok := re.Request.Body.(router.Rereader); ok {
		body.Reread()
	}
	recorder := httptest.NewRecorder()
	response := &router.ResponseWriter{ResponseWriter: recorder}
	previousResponse := re.Response
	re.Response = response
	defer func() { re.Response = previousResponse }()
	if err := route.Action(re); err != nil {
		return nil, err
	}
	return recorder, nil
}

func decodeAction[T any](rec *httptest.ResponseRecorder, out *T) error {
	if rec.Code < http.StatusOK || rec.Code >= http.StatusMultipleChoices {
		return fmt.Errorf("operation returned unexpected status %d", rec.Code)
	}
	if err := json.Unmarshal(rec.Body.Bytes(), out); err != nil {
		return fmt.Errorf("decode operation response: %w", err)
	}
	return nil
}

type rawResponse struct {
	status int
	header http.Header
	body   []byte
}

func (r rawResponse) write(w http.ResponseWriter) error {
	for name, values := range r.header {
		for _, value := range values {
			w.Header().Add(name, value)
		}
	}
	w.WriteHeader(r.status)
	_, err := w.Write(r.body)
	return err
}

func (r rawResponse) VisitCancelChatSessionResponse(w http.ResponseWriter) error { return r.write(w) }
func (r rawResponse) VisitRespondToElicitationResponse(w http.ResponseWriter) error {
	return r.write(w)
}
func (r rawResponse) VisitPromptChatResponse(w http.ResponseWriter) error          { return r.write(w) }
func (r rawResponse) VisitRespondToPermissionResponse(w http.ResponseWriter) error { return r.write(w) }
func (r rawResponse) VisitSetChatConfigOptionResponse(w http.ResponseWriter) error { return r.write(w) }
func (r rawResponse) VisitSetChatModeResponse(w http.ResponseWriter) error         { return r.write(w) }
func (r rawResponse) VisitStreamChatEventsResponse(w http.ResponseWriter) error    { return r.write(w) }
func (r rawResponse) VisitGetWorkspaceFileResponse(w http.ResponseWriter) error    { return r.write(w) }
func (r rawResponse) VisitListWorkspaceFilesResponse(w http.ResponseWriter) error  { return r.write(w) }
func (r rawResponse) VisitCancelHarnessAuthResponse(w http.ResponseWriter) error   { return r.write(w) }
func (r rawResponse) VisitDisconnectHarnessAuthResponse(w http.ResponseWriter) error {
	return r.write(w)
}
func (r rawResponse) VisitPollHarnessAuthResponse(w http.ResponseWriter) error  { return r.write(w) }
func (r rawResponse) VisitStartHarnessAuthResponse(w http.ResponseWriter) error { return r.write(w) }
func (r rawResponse) VisitGetHarnessAuthStatusResponse(w http.ResponseWriter) error {
	return r.write(w)
}
func (r rawResponse) VisitSubmitHarnessAuthResponse(w http.ResponseWriter) error   { return r.write(w) }
func (r rawResponse) VisitStreamContainerLogsResponse(w http.ResponseWriter) error { return r.write(w) }
func (r rawResponse) VisitListContainersResponse(w http.ResponseWriter) error      { return r.write(w) }
func (r rawResponse) VisitGetHarnessInstanceLogsResponse(w http.ResponseWriter) error {
	return r.write(w)
}
func (r rawResponse) VisitStoreMcpOAuthTokenResponse(w http.ResponseWriter) error { return r.write(w) }
func (r rawResponse) VisitExecuteMcpRequestResponse(w http.ResponseWriter) error  { return r.write(w) }
func (r rawResponse) VisitListOllamaModelsResponse(w http.ResponseWriter) error   { return r.write(w) }
func (r rawResponse) VisitPullOllamaModelResponse(w http.ResponseWriter) error    { return r.write(w) }
func (r rawResponse) VisitProxyObservabilityResponse(w http.ResponseWriter) error { return r.write(w) }
func (r rawResponse) VisitSendPushNotificationResponse(w http.ResponseWriter) error {
	return r.write(w)
}
func (r rawResponse) VisitEndLiveActivityResponse(w http.ResponseWriter) error { return r.write(w) }
func (r rawResponse) VisitGetReleaseCompatibilityResponse(w http.ResponseWriter) error {
	return r.write(w)
}
func (r rawResponse) VisitGetReleaseStatusResponse(w http.ResponseWriter) error { return r.write(w) }
func (r rawResponse) VisitRunScheduleNowResponse(w http.ResponseWriter) error   { return r.write(w) }

func (s *server) CancelChatSession(ctx context.Context, request openapi.CancelChatSessionRequestObject) (openapi.CancelChatSessionResponseObject, error) {
	if s.agentErr != nil {
		return nil, s.agentErr
	}
	re, ok := ctx.Value(requestEventContextKey{}).(*core.RequestEvent)
	if !ok {
		return nil, errors.New("PocketBase request context is unavailable")
	}
	re.Request.SetPathValue("chatId", string(request.ChatId))
	if err := api.CancelChatSession(s.app, s.agent, re); err != nil {
		return nil, err
	}
	return openapi.CancelChatSession202Response{}, nil
}

func (s *server) agentRequestEvent(ctx context.Context, chatID string) (*core.RequestEvent, error) {
	if s.agentErr != nil {
		return nil, s.agentErr
	}
	re, ok := ctx.Value(requestEventContextKey{}).(*core.RequestEvent)
	if !ok {
		return nil, errors.New("PocketBase request context is unavailable")
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
		return nil, err
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
	if err := s.agent.ResolveElicitation(string(request.ChatId), string(request.Id), resp); err != nil {
		if errors.Is(err, coordinator.ErrNoPendingElicitation) {
			return nil, re.NotFoundError("Pending elicitation not found", err)
		}
		return nil, apis.NewApiError(http.StatusBadGateway, "Unable to submit elicitation response", err)
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
		return nil, err
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
		return nil, err
	}
	if err := json.Unmarshal(b, &input); err != nil {
		return nil, re.BadRequestError("Invalid permission response", err)
	}
	var callErr error
	switch {
	case input.Outcome.Selected != nil:
		optionID := strings.TrimSpace(string(input.Outcome.Selected.OptionId))
		if optionID == "" {
			return nil, re.BadRequestError("optionId is required", nil)
		}
		callErr = s.agent.Approve(re.Request.Context(), string(request.ChatId), string(request.Id), optionID)
	case input.Outcome.Cancelled != nil:
		callErr = s.agent.DenyPermission(string(request.ChatId), string(request.Id))
	default:
		return nil, re.BadRequestError("outcome must be selected or cancelled", nil)
	}
	if errors.Is(callErr, coordinator.ErrNoPendingPermission) {
		return nil, re.NotFoundError("Pending permission not found", callErr)
	}
	if errors.Is(callErr, coordinator.ErrPermissionOptionNotOffered) {
		return nil, re.BadRequestError("Permission option was not offered", callErr)
	}
	if callErr != nil {
		return nil, apis.NewApiError(http.StatusBadGateway, "Unable to submit permission decision", callErr)
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
	if err := s.agent.SetConfigOption(re.Request.Context(), string(request.ChatId), req); err != nil {
		if errors.Is(err, coordinator.ErrNoActiveRun) {
			return nil, re.BadRequestError("No active run to set config on", nil)
		}
		return nil, apis.NewApiError(http.StatusBadGateway, "Unable to set config option", err)
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
	if err := s.agent.SetMode(re.Request.Context(), string(request.ChatId), request.Body.ModeId); err != nil {
		if errors.Is(err, coordinator.ErrNoActiveRun) {
			return nil, re.BadRequestError("No active run to set mode on", nil)
		}
		return nil, apis.NewApiError(http.StatusBadGateway, "Unable to set mode", err)
	}
	return openapi.SetChatMode202Response{}, nil
}
func (s *server) StreamChatEvents(ctx context.Context, _ openapi.StreamChatEventsRequestObject) (openapi.StreamChatEventsResponseObject, error) {
	return s.dispatch(ctx, "streamChatEvents", nil)
}
func (s *server) GetWorkspaceFile(ctx context.Context, _ openapi.GetWorkspaceFileRequestObject) (openapi.GetWorkspaceFileResponseObject, error) {
	return s.dispatch(ctx, "getWorkspaceFile", nil)
}
func (s *server) ListWorkspaceFiles(ctx context.Context, _ openapi.ListWorkspaceFilesRequestObject) (openapi.ListWorkspaceFilesResponseObject, error) {
	rec, err := s.invokeAction(ctx, "listWorkspaceFiles", nil)
	if err != nil {
		return nil, err
	}
	var response openapi.ListWorkspaceFiles200JSONResponse
	if err := decodeAction(rec, &response); err != nil {
		return nil, err
	}
	return response, nil
}
func (s *server) CancelHarnessAuth(ctx context.Context, _ openapi.CancelHarnessAuthRequestObject) (openapi.CancelHarnessAuthResponseObject, error) {
	rec, err := s.invokeAction(ctx, "cancelHarnessAuth", nil)
	if err != nil {
		return nil, err
	}
	var response openapi.CancelHarnessAuth200JSONResponse
	if err := decodeAction(rec, &response); err != nil {
		return nil, err
	}
	return response, nil
}
func (s *server) DisconnectHarnessAuth(ctx context.Context, _ openapi.DisconnectHarnessAuthRequestObject) (openapi.DisconnectHarnessAuthResponseObject, error) {
	rec, err := s.invokeAction(ctx, "disconnectHarnessAuth", nil)
	if err != nil {
		return nil, err
	}
	var response openapi.DisconnectHarnessAuth200JSONResponse
	if err := decodeAction(rec, &response); err != nil {
		return nil, err
	}
	return response, nil
}
func (s *server) PollHarnessAuth(ctx context.Context, _ openapi.PollHarnessAuthRequestObject) (openapi.PollHarnessAuthResponseObject, error) {
	rec, err := s.invokeAction(ctx, "pollHarnessAuth", nil)
	if err != nil {
		return nil, err
	}
	var response openapi.PollHarnessAuth200JSONResponse
	if err := decodeAction(rec, &response); err != nil {
		return nil, err
	}
	return response, nil
}
func (s *server) StartHarnessAuth(ctx context.Context, _ openapi.StartHarnessAuthRequestObject) (openapi.StartHarnessAuthResponseObject, error) {
	rec, err := s.invokeAction(ctx, "startHarnessAuth", nil)
	if err != nil {
		return nil, err
	}
	var response openapi.StartHarnessAuth200JSONResponse
	if err := decodeAction(rec, &response); err != nil {
		return nil, err
	}
	return response, nil
}
func (s *server) GetHarnessAuthStatus(ctx context.Context, _ openapi.GetHarnessAuthStatusRequestObject) (openapi.GetHarnessAuthStatusResponseObject, error) {
	rec, err := s.invokeAction(ctx, "getHarnessAuthStatus", nil)
	if err != nil {
		return nil, err
	}
	var response openapi.GetHarnessAuthStatus200JSONResponse
	if err := decodeAction(rec, &response); err != nil {
		return nil, err
	}
	return response, nil
}
func (s *server) SubmitHarnessAuth(ctx context.Context, _ openapi.SubmitHarnessAuthRequestObject) (openapi.SubmitHarnessAuthResponseObject, error) {
	rec, err := s.invokeAction(ctx, "submitHarnessAuth", nil)
	if err != nil {
		return nil, err
	}
	var response openapi.SubmitHarnessAuth200JSONResponse
	if err := decodeAction(rec, &response); err != nil {
		return nil, err
	}
	return response, nil
}
func (s *server) StreamContainerLogs(ctx context.Context, _ openapi.StreamContainerLogsRequestObject) (openapi.StreamContainerLogsResponseObject, error) {
	return s.dispatch(ctx, "streamContainerLogs", nil)
}
func (s *server) ListContainers(ctx context.Context, _ openapi.ListContainersRequestObject) (openapi.ListContainersResponseObject, error) {
	return s.dispatch(ctx, "listContainers", nil)
}
func (s *server) GetHarnessInstanceLogs(ctx context.Context, request openapi.GetHarnessInstanceLogsRequestObject) (openapi.GetHarnessInstanceLogsResponseObject, error) {
	return s.dispatch(ctx, "getHarnessInstanceLogs", map[string]string{"id": request.Id})
}
func (s *server) StoreMcpOAuthToken(ctx context.Context, _ openapi.StoreMcpOAuthTokenRequestObject) (openapi.StoreMcpOAuthTokenResponseObject, error) {
	rec, err := s.invokeAction(ctx, "storeMcpOAuthToken", nil)
	if err != nil {
		return nil, err
	}
	var response openapi.StoreMcpOAuthToken200JSONResponse
	if err := decodeAction(rec, &response); err != nil {
		return nil, err
	}
	return response, nil
}
func (s *server) ExecuteMcpRequest(ctx context.Context, _ openapi.ExecuteMcpRequestRequestObject) (openapi.ExecuteMcpRequestResponseObject, error) {
	rec, err := s.invokeAction(ctx, "executeMcpRequest", nil)
	if err != nil {
		return nil, err
	}
	var response openapi.ExecuteMcpRequest200JSONResponse
	if err := decodeAction(rec, &response); err != nil {
		return nil, err
	}
	return response, nil
}
func (s *server) ListOllamaModels(ctx context.Context, _ openapi.ListOllamaModelsRequestObject) (openapi.ListOllamaModelsResponseObject, error) {
	rec, err := s.invokeAction(ctx, "listOllamaModels", nil)
	if err != nil {
		return nil, err
	}
	var response openapi.ListOllamaModels200JSONResponse
	if err := decodeAction(rec, &response); err != nil {
		return nil, err
	}
	return response, nil
}
func (s *server) PullOllamaModel(ctx context.Context, _ openapi.PullOllamaModelRequestObject) (openapi.PullOllamaModelResponseObject, error) {
	return s.dispatch(ctx, "pullOllamaModel", nil)
}
func (s *server) ProxyObservability(ctx context.Context, _ openapi.ProxyObservabilityRequestObject) (openapi.ProxyObservabilityResponseObject, error) {
	return s.dispatch(ctx, "proxyObservability", nil)
}
func (s *server) SendPushNotification(ctx context.Context, _ openapi.SendPushNotificationRequestObject) (openapi.SendPushNotificationResponseObject, error) {
	rec, err := s.invokeAction(ctx, "sendPushNotification", nil)
	if err != nil {
		return nil, err
	}
	var response openapi.SendPushNotification200JSONResponse
	if err := decodeAction(rec, &response); err != nil {
		return nil, err
	}
	return response, nil
}
func (s *server) EndLiveActivity(ctx context.Context, request openapi.EndLiveActivityRequestObject) (openapi.EndLiveActivityResponseObject, error) {
	rec, err := s.invokeAction(ctx, "endLiveActivity", map[string]string{"id": string(request.Id)})
	if err != nil {
		return nil, err
	}
	var response openapi.EndLiveActivity200JSONResponse
	if err := decodeAction(rec, &response); err != nil {
		return nil, err
	}
	return response, nil
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
			return nil, fmt.Errorf("unexpected release compatibility value type %T", compatibility)
		}
		if err := json.Unmarshal(raw, &compatMap); err != nil {
			return nil, fmt.Errorf("decode release compatibility document: %w", err)
		}
	}
	return openapi.GetReleaseCompatibility200JSONResponse{
		SchemaVersion: 1,
		DataVersion:   dataVersion,
		Compatibility: compatMap,
	}, nil
}
func (s *server) GetReleaseStatus(ctx context.Context, _ openapi.GetReleaseStatusRequestObject) (openapi.GetReleaseStatusResponseObject, error) {
	rec, err := s.invokeAction(ctx, "getReleaseStatus", nil)
	if err != nil {
		return nil, err
	}
	var response openapi.GetReleaseStatus200JSONResponse
	if err := decodeAction(rec, &response); err != nil {
		return nil, err
	}
	return response, nil
}
func (s *server) RunScheduleNow(ctx context.Context, request openapi.RunScheduleNowRequestObject) (openapi.RunScheduleNowResponseObject, error) {
	rec, err := s.invokeAction(ctx, "runScheduleNow", map[string]string{"scheduleId": request.ScheduleId})
	if err != nil {
		return nil, err
	}
	var response openapi.RunScheduleNow202JSONResponse
	if err := decodeAction(rec, &response); err != nil {
		return nil, err
	}
	return response, nil
}

var _ openapi.StrictServerInterface = (*server)(nil)
