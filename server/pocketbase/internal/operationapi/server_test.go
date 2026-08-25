package operationapi

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/router"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/openapi"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/operation"
)

func dispatchEvent() (*core.RequestEvent, *httptest.ResponseRecorder) {
	rec := httptest.NewRecorder()
	re := &core.RequestEvent{Event: router.Event{
		Request:  httptest.NewRequest(http.MethodGet, "/items/", nil),
		Response: rec,
	}}
	return re, rec
}

func dispatchContext(re *core.RequestEvent) context.Context {
	return context.WithValue(context.Background(), requestEventContextKey{}, re)
}

func routeFor(id string, action operation.Action) operation.Route {
	return operation.Route{OperationID: id, Method: http.MethodGet, Path: "/items/{id}", Action: action}
}

func TestDispatchRejectsUnavailableRequestContext(t *testing.T) {
	s := &server{registry: operation.NewRegistry()}
	_, err := s.dispatch(context.Background(), "anything", nil)
	if err == nil || err.Error() != "PocketBase request context is unavailable" {
		t.Fatalf("err=%v", err)
	}
}

func TestDispatchRejectsUnknownOperation(t *testing.T) {
	s := &server{registry: operation.NewRegistry()}
	re, _ := dispatchEvent()
	_, err := s.dispatch(dispatchContext(re), "unknown", nil)
	if err == nil || err.Error() != "operation is not registered: unknown" {
		t.Fatalf("err=%v", err)
	}
}

func TestDispatchRejectsDirectOperation(t *testing.T) {
	reg := operation.NewRegistry()
	route := routeFor("direct", func(*core.RequestEvent) error { t.Fatal("action called"); return nil })
	route.Direct = true
	reg.Add(route)
	re, _ := dispatchEvent()
	_, err := (&server{registry: reg}).dispatch(dispatchContext(re), "direct", nil)
	if err == nil || err.Error() != "direct operation reached strict server: direct" {
		t.Fatalf("err=%v", err)
	}
}

func TestDispatchSetsPathValues(t *testing.T) {
	reg := operation.NewRegistry()
	reg.Add(routeFor("path", func(re *core.RequestEvent) error {
		if got := re.Request.PathValue("id"); got != "abc" {
			t.Errorf("PathValue(id)=%q", got)
		}
		return nil
	}))
	re, _ := dispatchEvent()
	if _, err := (&server{registry: reg}).dispatch(dispatchContext(re), "path", map[string]string{"id": "abc"}); err != nil {
		t.Fatal(err)
	}
}

func TestDispatchUnauthorizedDoesNotInvokeAction(t *testing.T) {
	called := false
	reg := operation.NewRegistry()
	route := routeFor("private", func(*core.RequestEvent) error { called = true; return nil })
	route.Auth = true
	reg.Add(route)
	re, _ := dispatchEvent()
	response, err := (&server{registry: reg}).dispatch(dispatchContext(re), "private", nil)
	if err != nil {
		t.Fatal(err)
	}
	if response.status != http.StatusUnauthorized {
		t.Fatalf("status=%d", response.status)
	}
	if called {
		t.Fatal("action called without authentication")
	}
}

func TestDispatchMapsActionError(t *testing.T) {
	reg := operation.NewRegistry()
	reg.Add(routeFor("failure", func(*core.RequestEvent) error { return errors.New("boom") }))
	re, _ := dispatchEvent()
	response, err := (&server{registry: reg}).dispatch(dispatchContext(re), "failure", nil)
	if err != nil {
		t.Fatal(err)
	}
	// router.ErrorHandler maps a plain (non-*router.ApiError) error through
	// router.ToApiError, which defaults to NewBadRequestError (400) rather
	// than 500 -- every real internal/api handler always returns a typed
	// ApiError (via pocketCoderError/apis.NewApiError/re.XxxError), so this
	// default-mapping path is a fallback for handlers that don't, not the
	// common case; the point of this test is that dispatch really does run
	// the action's error through router.ErrorHandler, not that any specific
	// status wins.
	if response.status != http.StatusBadRequest {
		t.Fatalf("status=%d", response.status)
	}
	// PocketBase's ApiError deliberately never serializes a plain action
	// error's raw message (only *router.ApiError's own Message field is
	// marshaled) -- a generic "Something went wrong" body is the correct,
	// by-design outcome here, not a leak of "boom".
	if !strings.Contains(string(response.body), "Something went wrong") {
		t.Fatalf("body=%q", response.body)
	}
	if strings.Contains(string(response.body), "boom") {
		t.Fatalf("action error text leaked into response body: %q", response.body)
	}
}

func TestDispatchCapturesAndWritesResponse(t *testing.T) {
	reg := operation.NewRegistry()
	reg.Add(routeFor("success", func(re *core.RequestEvent) error {
		re.Response.Header().Set("X-Test", "yes")
		re.Response.WriteHeader(http.StatusCreated)
		_, _ = re.Response.Write([]byte("hello"))
		return nil
	}))
	re, _ := dispatchEvent()
	response, err := (&server{registry: reg}).dispatch(dispatchContext(re), "success", nil)
	if err != nil {
		t.Fatal(err)
	}
	if response.status != http.StatusCreated || string(response.body) != "hello" || response.header.Get("X-Test") != "yes" {
		t.Fatalf("response status=%d headers=%v body=%q", response.status, response.header, response.body)
	}
	out := httptest.NewRecorder()
	if err := response.write(out); err != nil {
		t.Fatal(err)
	}
	if out.Code != http.StatusCreated || out.Header().Get("X-Test") != "yes" || out.Body.String() != "hello" {
		t.Fatalf("written status=%d headers=%v body=%q", out.Code, out.Header(), out.Body.String())
	}
}

// TestServerMethodsDelegateToDispatch covers the ~24 mechanical
// server.Xxx wrapper methods: each is a one-line delegation to dispatch
// with a fixed operationID and pathValues built from the request object.
// A spy route per operationID records what dispatch actually received, so
// this proves each wrapper wires the right operationID/pathValues rather
// than re-testing dispatch's own logic (already covered above).
func TestServerMethodsDelegateToDispatch(t *testing.T) {
	seen := map[string]map[string]string{}
	reg := operation.NewRegistry()
	for _, id := range []string{
		"cancelChatSession", "respondToElicitation", "promptChat", "respondToPermission",
		"setChatConfigOption", "setChatMode", "streamChatEvents", "getWorkspaceFile",
		"listWorkspaceFiles", "cancelHarnessAuth", "disconnectHarnessAuth", "pollHarnessAuth",
		"startHarnessAuth", "getHarnessAuthStatus", "submitHarnessAuth", "streamContainerLogs",
		"storeMcpOAuthToken", "executeMcpRequest", "listOllamaModels", "pullOllamaModel",
		"proxyObservability", "sendPushNotification", "endLiveActivity", "getReleaseCompatibility", "getReleaseStatus",
		"runScheduleNow",
	} {
		opID := id
		reg.Add(routeFor(opID, func(re *core.RequestEvent) error {
			values := map[string]string{}
			for _, name := range []string{"chatId", "id", "scheduleId"} {
				if v := re.Request.PathValue(name); v != "" {
					values[name] = v
				}
			}
			seen[opID] = values
			return nil
		}))
	}

	s := &server{registry: reg}

	// Each call gets its own request/context: dispatch calls
	// re.Request.SetPathValue on the shared underlying request, so reusing
	// one across calls would leak earlier calls' path values into later
	// ones with no path params of their own.
	newCtx := func() context.Context {
		re, _ := dispatchEvent()
		return dispatchContext(re)
	}
	call := func(name string, err error) {
		t.Helper()
		if err != nil {
			t.Fatalf("%s: %v", name, err)
		}
	}

	_, err := s.CancelChatSession(newCtx(), openapi.CancelChatSessionRequestObject{ChatId: "c1"})
	call("CancelChatSession", err)
	_, err = s.RespondToElicitation(newCtx(), openapi.RespondToElicitationRequestObject{ChatId: "c1", Id: "e1"})
	call("RespondToElicitation", err)
	_, err = s.PromptChat(newCtx(), openapi.PromptChatRequestObject{ChatId: "c1"})
	call("PromptChat", err)
	_, err = s.RespondToPermission(newCtx(), openapi.RespondToPermissionRequestObject{ChatId: "c1", Id: "p1"})
	call("RespondToPermission", err)
	_, err = s.SetChatConfigOption(newCtx(), openapi.SetChatConfigOptionRequestObject{ChatId: "c1"})
	call("SetChatConfigOption", err)
	_, err = s.SetChatMode(newCtx(), openapi.SetChatModeRequestObject{ChatId: "c1"})
	call("SetChatMode", err)
	_, err = s.StreamChatEvents(newCtx(), openapi.StreamChatEventsRequestObject{})
	call("StreamChatEvents", err)
	_, err = s.GetWorkspaceFile(newCtx(), openapi.GetWorkspaceFileRequestObject{})
	call("GetWorkspaceFile", err)
	_, err = s.ListWorkspaceFiles(newCtx(), openapi.ListWorkspaceFilesRequestObject{})
	call("ListWorkspaceFiles", err)
	_, err = s.CancelHarnessAuth(newCtx(), openapi.CancelHarnessAuthRequestObject{})
	call("CancelHarnessAuth", err)
	_, err = s.DisconnectHarnessAuth(newCtx(), openapi.DisconnectHarnessAuthRequestObject{})
	call("DisconnectHarnessAuth", err)
	_, err = s.PollHarnessAuth(newCtx(), openapi.PollHarnessAuthRequestObject{})
	call("PollHarnessAuth", err)
	_, err = s.StartHarnessAuth(newCtx(), openapi.StartHarnessAuthRequestObject{})
	call("StartHarnessAuth", err)
	_, err = s.GetHarnessAuthStatus(newCtx(), openapi.GetHarnessAuthStatusRequestObject{})
	call("GetHarnessAuthStatus", err)
	_, err = s.SubmitHarnessAuth(newCtx(), openapi.SubmitHarnessAuthRequestObject{})
	call("SubmitHarnessAuth", err)
	_, err = s.StreamContainerLogs(newCtx(), openapi.StreamContainerLogsRequestObject{})
	call("StreamContainerLogs", err)
	_, err = s.StoreMcpOAuthToken(newCtx(), openapi.StoreMcpOAuthTokenRequestObject{})
	call("StoreMcpOAuthToken", err)
	_, err = s.ExecuteMcpRequest(newCtx(), openapi.ExecuteMcpRequestRequestObject{})
	call("ExecuteMcpRequest", err)
	_, err = s.ListOllamaModels(newCtx(), openapi.ListOllamaModelsRequestObject{})
	call("ListOllamaModels", err)
	_, err = s.PullOllamaModel(newCtx(), openapi.PullOllamaModelRequestObject{})
	call("PullOllamaModel", err)
	_, err = s.ProxyObservability(newCtx(), openapi.ProxyObservabilityRequestObject{})
	call("ProxyObservability", err)
	_, err = s.SendPushNotification(newCtx(), openapi.SendPushNotificationRequestObject{})
	call("SendPushNotification", err)
	_, err = s.EndLiveActivity(newCtx(), openapi.EndLiveActivityRequestObject{Id: "a1"})
	call("EndLiveActivity", err)
	_, err = s.GetReleaseCompatibility(newCtx(), openapi.GetReleaseCompatibilityRequestObject{})
	call("GetReleaseCompatibility", err)
	_, err = s.GetReleaseStatus(newCtx(), openapi.GetReleaseStatusRequestObject{})
	call("GetReleaseStatus", err)
	_, err = s.RunScheduleNow(newCtx(), openapi.RunScheduleNowRequestObject{ScheduleId: "s1"})
	call("RunScheduleNow", err)

	wantPathValues := map[string]map[string]string{
		"cancelChatSession":       {"chatId": "c1"},
		"respondToElicitation":    {"chatId": "c1", "id": "e1"},
		"promptChat":              {"chatId": "c1"},
		"respondToPermission":     {"chatId": "c1", "id": "p1"},
		"setChatConfigOption":     {"chatId": "c1"},
		"setChatMode":             {"chatId": "c1"},
		"streamChatEvents":        {},
		"getWorkspaceFile":        {},
		"listWorkspaceFiles":      {},
		"cancelHarnessAuth":       {},
		"disconnectHarnessAuth":   {},
		"pollHarnessAuth":         {},
		"startHarnessAuth":        {},
		"getHarnessAuthStatus":    {},
		"submitHarnessAuth":       {},
		"streamContainerLogs":     {},
		"storeMcpOAuthToken":      {},
		"executeMcpRequest":       {},
		"listOllamaModels":        {},
		"pullOllamaModel":         {},
		"proxyObservability":      {},
		"sendPushNotification":    {},
		"endLiveActivity":         {"id": "a1"},
		"getReleaseCompatibility": {},
		"getReleaseStatus":        {},
		"runScheduleNow":          {"scheduleId": "s1"},
	}
	for opID, want := range wantPathValues {
		got, ok := seen[opID]
		if !ok {
			t.Errorf("%s: dispatch never invoked", opID)
			continue
		}
		if len(got) != len(want) {
			t.Errorf("%s: pathValues=%v, want %v", opID, got, want)
			continue
		}
		for k, v := range want {
			if got[k] != v {
				t.Errorf("%s: pathValues[%s]=%q, want %q", opID, k, got[k], v)
			}
		}
	}
}

// TestVisitResponsesAllWriteThrough covers the ~24 mechanical
// rawResponse.VisitXxxResponse methods, each of which is a one-line
// delegation to rawResponse.write (already directly tested above via
// TestDispatchCapturesAndWritesResponse's response.write call) -- this
// proves every Visit* variant reaches that same write path, not just the
// bare write method itself.
func TestVisitResponsesAllWriteThrough(t *testing.T) {
	r := rawResponse{status: http.StatusTeapot, body: []byte("teapot")}
	visitors := []func(http.ResponseWriter) error{
		r.VisitCancelChatSessionResponse, r.VisitRespondToElicitationResponse,
		r.VisitPromptChatResponse, r.VisitRespondToPermissionResponse,
		r.VisitSetChatConfigOptionResponse, r.VisitSetChatModeResponse,
		r.VisitStreamChatEventsResponse, r.VisitGetWorkspaceFileResponse,
		r.VisitListWorkspaceFilesResponse, r.VisitCancelHarnessAuthResponse,
		r.VisitDisconnectHarnessAuthResponse, r.VisitPollHarnessAuthResponse,
		r.VisitStartHarnessAuthResponse, r.VisitGetHarnessAuthStatusResponse,
		r.VisitSubmitHarnessAuthResponse, r.VisitStreamContainerLogsResponse,
		r.VisitStoreMcpOAuthTokenResponse, r.VisitExecuteMcpRequestResponse,
		r.VisitListOllamaModelsResponse, r.VisitPullOllamaModelResponse,
		r.VisitProxyObservabilityResponse, r.VisitSendPushNotificationResponse,
		r.VisitGetReleaseCompatibilityResponse, r.VisitGetReleaseStatusResponse,
		r.VisitRunScheduleNowResponse,
	}
	for i, visit := range visitors {
		out := httptest.NewRecorder()
		if err := visit(out); err != nil {
			t.Fatalf("visitor %d: %v", i, err)
		}
		if out.Code != http.StatusTeapot || out.Body.String() != "teapot" {
			t.Fatalf("visitor %d: status=%d body=%q", i, out.Code, out.Body.String())
		}
	}
}
