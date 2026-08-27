// Package operationapi binds PocketCoder's generated OpenAPI server to the
// existing PocketBase request context and direct operation actions.
package operationapi

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
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
		&server{registry: registry},
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
	return s.dispatch(ctx, "cancelChatSession", map[string]string{"chatId": string(request.ChatId)})
}
func (s *server) RespondToElicitation(ctx context.Context, request openapi.RespondToElicitationRequestObject) (openapi.RespondToElicitationResponseObject, error) {
	return s.dispatch(ctx, "respondToElicitation", map[string]string{"chatId": string(request.ChatId), "id": string(request.Id)})
}
func (s *server) PromptChat(ctx context.Context, request openapi.PromptChatRequestObject) (openapi.PromptChatResponseObject, error) {
	return s.dispatch(ctx, "promptChat", map[string]string{"chatId": string(request.ChatId)})
}
func (s *server) RespondToPermission(ctx context.Context, request openapi.RespondToPermissionRequestObject) (openapi.RespondToPermissionResponseObject, error) {
	return s.dispatch(ctx, "respondToPermission", map[string]string{"chatId": string(request.ChatId), "id": string(request.Id)})
}
func (s *server) SetChatConfigOption(ctx context.Context, request openapi.SetChatConfigOptionRequestObject) (openapi.SetChatConfigOptionResponseObject, error) {
	return s.dispatch(ctx, "setChatConfigOption", map[string]string{"chatId": string(request.ChatId)})
}
func (s *server) SetChatMode(ctx context.Context, request openapi.SetChatModeRequestObject) (openapi.SetChatModeResponseObject, error) {
	return s.dispatch(ctx, "setChatMode", map[string]string{"chatId": string(request.ChatId)})
}
func (s *server) StreamChatEvents(ctx context.Context, _ openapi.StreamChatEventsRequestObject) (openapi.StreamChatEventsResponseObject, error) {
	return s.dispatch(ctx, "streamChatEvents", nil)
}
func (s *server) GetWorkspaceFile(ctx context.Context, _ openapi.GetWorkspaceFileRequestObject) (openapi.GetWorkspaceFileResponseObject, error) {
	return s.dispatch(ctx, "getWorkspaceFile", nil)
}
func (s *server) ListWorkspaceFiles(ctx context.Context, _ openapi.ListWorkspaceFilesRequestObject) (openapi.ListWorkspaceFilesResponseObject, error) {
	return s.dispatch(ctx, "listWorkspaceFiles", nil)
}
func (s *server) CancelHarnessAuth(ctx context.Context, _ openapi.CancelHarnessAuthRequestObject) (openapi.CancelHarnessAuthResponseObject, error) {
	return s.dispatch(ctx, "cancelHarnessAuth", nil)
}
func (s *server) DisconnectHarnessAuth(ctx context.Context, _ openapi.DisconnectHarnessAuthRequestObject) (openapi.DisconnectHarnessAuthResponseObject, error) {
	return s.dispatch(ctx, "disconnectHarnessAuth", nil)
}
func (s *server) PollHarnessAuth(ctx context.Context, _ openapi.PollHarnessAuthRequestObject) (openapi.PollHarnessAuthResponseObject, error) {
	return s.dispatch(ctx, "pollHarnessAuth", nil)
}
func (s *server) StartHarnessAuth(ctx context.Context, _ openapi.StartHarnessAuthRequestObject) (openapi.StartHarnessAuthResponseObject, error) {
	return s.dispatch(ctx, "startHarnessAuth", nil)
}
func (s *server) GetHarnessAuthStatus(ctx context.Context, _ openapi.GetHarnessAuthStatusRequestObject) (openapi.GetHarnessAuthStatusResponseObject, error) {
	return s.dispatch(ctx, "getHarnessAuthStatus", nil)
}
func (s *server) SubmitHarnessAuth(ctx context.Context, _ openapi.SubmitHarnessAuthRequestObject) (openapi.SubmitHarnessAuthResponseObject, error) {
	return s.dispatch(ctx, "submitHarnessAuth", nil)
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
	return s.dispatch(ctx, "storeMcpOAuthToken", nil)
}
func (s *server) ExecuteMcpRequest(ctx context.Context, _ openapi.ExecuteMcpRequestRequestObject) (openapi.ExecuteMcpRequestResponseObject, error) {
	return s.dispatch(ctx, "executeMcpRequest", nil)
}
func (s *server) ListOllamaModels(ctx context.Context, _ openapi.ListOllamaModelsRequestObject) (openapi.ListOllamaModelsResponseObject, error) {
	return s.dispatch(ctx, "listOllamaModels", nil)
}
func (s *server) PullOllamaModel(ctx context.Context, _ openapi.PullOllamaModelRequestObject) (openapi.PullOllamaModelResponseObject, error) {
	return s.dispatch(ctx, "pullOllamaModel", nil)
}
func (s *server) ProxyObservability(ctx context.Context, _ openapi.ProxyObservabilityRequestObject) (openapi.ProxyObservabilityResponseObject, error) {
	return s.dispatch(ctx, "proxyObservability", nil)
}
func (s *server) SendPushNotification(ctx context.Context, _ openapi.SendPushNotificationRequestObject) (openapi.SendPushNotificationResponseObject, error) {
	return s.dispatch(ctx, "sendPushNotification", nil)
}
func (s *server) EndLiveActivity(ctx context.Context, request openapi.EndLiveActivityRequestObject) (openapi.EndLiveActivityResponseObject, error) {
	return s.dispatch(ctx, "endLiveActivity", map[string]string{"id": string(request.Id)})
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
	return s.dispatch(ctx, "getReleaseStatus", nil)
}
func (s *server) RunScheduleNow(ctx context.Context, request openapi.RunScheduleNowRequestObject) (openapi.RunScheduleNowResponseObject, error) {
	return s.dispatch(ctx, "runScheduleNow", map[string]string{"scheduleId": request.ScheduleId})
}

var _ openapi.StrictServerInterface = (*server)(nil)
