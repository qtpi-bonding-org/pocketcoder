package api

import (
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/agent/coordinator"
	"net/http"
	"strings"
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/filesystem"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/hooks"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/operation"
)

// mountAllPocketCoderOperations mounts the same operation registry used by
// operationapi.Register, but without the generated strict adapter. This lets
// the table below exercise every route's real PocketBase auth boundary without
// needing a live Goose, Docker proxy, Ollama runtime, SQLPage, or push relay.
func mountAllPocketCoderOperations(t testing.TB, app core.App, e *core.ServeEvent) {
	t.Helper()
	registry := operation.NewRegistry()

	if _, err := AddAgentOperations(app, registry, AgentDeps{}); err != nil {
		t.Fatal(err)
	}
	AddMcpOperations(app, registry, McpDeps{})
	AddMcpOAuthOperations(app, registry)
	AddProxyOperations(registry, ProxyDeps{})
	AddLogOperations(registry, LogsDeps{})
	AddOllamaOperations(registry, OllamaDeps{})
	AddReleaseStatusOperations(registry)
	filesystem.AddFileOperations(registry)
	hooks.AddPushOperations(app, registry)
	AddHarnessAuthOperations(app, registry, HarnessAuthDeps{})
	AddScheduleOperations(app, registry, func() coordinator.AgentRuntime { return nil })
	AddLiveActivityOperations(app, registry)

	operation.MountForTests(e, registry.Routes())
}

func TestEveryPocketCoderEndpointHasAnAuthBoundary(t *testing.T) {
	for _, tc := range testsByEndpoint {
		t.Run(tc.name, func(t *testing.T) {
			scenario := tests.ApiScenario{
				Name:           tc.name + " requires authentication",
				Method:         tc.method,
				URL:            tc.url,
				ExpectedStatus: http.StatusUnauthorized,
				ExpectedContent: []string{
					"requires valid record authorization token",
				},
				BeforeTestFunc: func(_ testing.TB, app *tests.TestApp, e *core.ServeEvent) {
					mountAllPocketCoderOperations(t, app, e)
				},
			}
			if tc.body != "" {
				scenario.Body = strings.NewReader(tc.body)
			}
			scenario.Test(t)
		})
	}
}

var testsByEndpoint = []struct {
	name   string
	method string
	url    string
	body   string
}{
	{"promptChat", http.MethodPost, "/api/pocketcoder/v1/chats/test-chat/session/prompt", `{"prompt":[{"type":"text","text":"test"}]}`},
	{"streamChatEvents", http.MethodGet, "/api/pocketcoder/v1/chats/test-chat/stream?cursor=0", ""},
	{"cancelChatSession", http.MethodPost, "/api/pocketcoder/v1/chats/test-chat/session/cancel", ""},
	{"setChatMode", http.MethodPost, "/api/pocketcoder/v1/chats/test-chat/session/set-mode", `{"modeId":"approve"}`},
	{"setChatConfigOption", http.MethodPost, "/api/pocketcoder/v1/chats/test-chat/session/set-config-option", `{"configId":"provider","value":"openrouter"}`},
	{"respondToPermission", http.MethodPost, "/api/pocketcoder/v1/chats/test-chat/session/request-permission/test-request", `{}`},
	{"respondToElicitation", http.MethodPost, "/api/pocketcoder/v1/chats/test-chat/session/elicitation/test-request", `{}`},
	{"getHarnessAuthStatus", http.MethodPost, "/api/pocketcoder/v1/harness-auth/status", `{"harness":"test-harness"}`},
	{"startHarnessAuth", http.MethodPost, "/api/pocketcoder/v1/harness-auth/start", `{"harness":"test-harness","credentialMode":"none"}`},
	{"pollHarnessAuth", http.MethodPost, "/api/pocketcoder/v1/harness-auth/poll", `{"harness":"test-harness"}`},
	{"submitHarnessAuth", http.MethodPost, "/api/pocketcoder/v1/harness-auth/submit", `{"harness":"test-harness","code":"test"}`},
	{"cancelHarnessAuth", http.MethodPost, "/api/pocketcoder/v1/harness-auth/cancel", `{"harness":"test-harness"}`},
	{"disconnectHarnessAuth", http.MethodPost, "/api/pocketcoder/v1/harness-auth/disconnect", `{"harness":"test-harness"}`},
	{"runScheduleNow", http.MethodPost, "/api/pocketcoder/v1/schedules/test-schedule/run", ""},
	{"getWorkspaceFile", http.MethodGet, "/api/pocketcoder/v1/files?path=test.txt", ""},
	{"listWorkspaceFiles", http.MethodGet, "/api/pocketcoder/v1/files-list", ""},
	{"listOllamaModels", http.MethodGet, "/api/pocketcoder/v1/ollama/models", ""},
	{"pullOllamaModel", http.MethodPost, "/api/pocketcoder/v1/ollama/pull", `{"model":"qwen3:0.6b"}`},
	{"executeMcpRequest", http.MethodPost, "/api/pocketcoder/v1/mcp/request", `{"server_name":"test-server"}`},
	{"storeMcpOAuthToken", http.MethodPost, "/api/pocketcoder/v1/mcp/oauth/store", `{"server_name":"test-server","access_token":"test-token"}`},
	{"getReleaseStatus", http.MethodGet, "/api/pocketcoder/v1/release/status", ""},
	{"streamContainerLogs", http.MethodGet, "/api/pocketcoder/v1/logs/pocketcoder-pocketbase", ""},
	{"proxyObservability", http.MethodGet, "/api/pocketcoder/v1/proxy/observability/", ""},
	{"sendPushNotification", http.MethodPost, "/api/pocketcoder/v1/push", `{"user_id":"test-user","type":"test"}`},
	{"endLiveActivity", http.MethodPost, "/api/pocketcoder/v1/live-activities/test-activity/end", ""},
}

func TestCompatibilityEndpointIsPublicAtTheOperationBoundary(t *testing.T) {
	scenario := tests.ApiScenario{
		Name:            "getReleaseCompatibility is public",
		Method:          http.MethodGet,
		URL:             "/api/pocketcoder/v1/compatibility",
		ExpectedStatus:  http.StatusOK,
		ExpectedContent: []string{"schemaVersion", "compatibility"},
		BeforeTestFunc: func(_ testing.TB, app *tests.TestApp, e *core.ServeEvent) {
			mountAllPocketCoderOperations(t, app, e)
		},
	}
	scenario.Test(t)
}
