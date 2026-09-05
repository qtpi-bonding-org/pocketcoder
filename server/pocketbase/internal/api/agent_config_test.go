/*
PocketCoder: An accessible, secure, and user-friendly open-source coding assistant platform.
Copyright (C) 2026 Qtpi Bonding LLC

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

package api

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/ag-ui-protocol/ag-ui/sdks/community/go/pkg/core/events"
	acpsdk "github.com/coder/acp-go-sdk"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/agent/coordinator"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/operation"
)

func seedTwoModels(t *testing.T, app core.App, harness *core.Record) (hm1, hm2 *core.Record) {
	t.Helper()
	provider, err := app.FindFirstRecordByFilter("providers", "provider_id = 'anthropic'", nil)
	if err != nil {
		t.Fatal(err)
	}

	modelsColl, err := app.FindCollectionByNameOrId("models")
	if err != nil {
		t.Fatal(err)
	}
	model1 := core.NewRecord(modelsColl)
	model1.Set("name", "claude-3.5-sonnet")
	model1.Set("provider", provider.Id)
	if err := app.Save(model1); err != nil {
		t.Fatal(err)
	}

	model2 := core.NewRecord(modelsColl)
	model2.Set("name", "claude-3-opus")
	model2.Set("provider", provider.Id)
	if err := app.Save(model2); err != nil {
		t.Fatal(err)
	}

	hmColl, err := app.FindCollectionByNameOrId("harness_models")
	if err != nil {
		t.Fatal(err)
	}

	hm1 = core.NewRecord(hmColl)
	hm1.Set("harness", harness.Id)
	hm1.Set("model", model1.Id)
	hm1.Set("harness_model_id", "claude-3.5-sonnet")
	if err := app.Save(hm1); err != nil {
		t.Fatal(err)
	}

	hm2 = core.NewRecord(hmColl)
	hm2.Set("harness", harness.Id)
	hm2.Set("model", model2.Id)
	hm2.Set("harness_model_id", "claude-3-opus")
	if err := app.Save(hm2); err != nil {
		t.Fatal(err)
	}
	return hm1, hm2
}

func TestSetChatConfigOptionPersistsModelOverride(t *testing.T) {
	app := testApp(t)

	user := testUser(t, app, "model-persist@example.com")
	harness, _ := seedTestHarnessAndInstance(t, app, "test-harness", true, user.Id)
	_, hm2 := seedTwoModels(t, app, harness)

	chat := createTestChat(t, app, map[string]any{"harness": harness.Id})
	if chat.GetString("harness_model_override") != "" {
		t.Fatal("chat should start with no harness_model_override")
	}

	PersistModelOverride(app, chat.Id, "claude-3-opus")

	reloaded, err := app.FindRecordById("chats", chat.Id)
	if err != nil {
		t.Fatal(err)
	}
	override := reloaded.GetString("harness_model_override")
	if override != hm2.Id {
		t.Fatalf("harness_model_override = %q, want %q (hm2.Id)", override, hm2.Id)
	}
}

func TestPersistModelOverrideSwapsBetweenModels(t *testing.T) {
	app := testApp(t)

	user := testUser(t, app, "model-swap@example.com")
	harness, _ := seedTestHarnessAndInstance(t, app, "test-harness", true, user.Id)
	hm1, hm2 := seedTwoModels(t, app, harness)

	chat := createTestChat(t, app, map[string]any{"harness": harness.Id, "harness_model_override": hm1.Id})

	PersistModelOverride(app, chat.Id, "claude-3-opus")

	reloaded, err := app.FindRecordById("chats", chat.Id)
	if err != nil {
		t.Fatal(err)
	}
	if override := reloaded.GetString("harness_model_override"); override != hm2.Id {
		t.Fatalf("harness_model_override = %q, want %q (hm2.Id) after swapping from hm1", override, hm2.Id)
	}

	PersistModelOverride(app, chat.Id, "claude-3.5-sonnet")
	reloaded, err = app.FindRecordById("chats", chat.Id)
	if err != nil {
		t.Fatal(err)
	}
	if override := reloaded.GetString("harness_model_override"); override != hm1.Id {
		t.Fatalf("harness_model_override = %q, want %q (hm1.Id) after swapping back", override, hm1.Id)
	}
}

func TestPersistModelOverrideNoMatchingRow(t *testing.T) {
	app := testApp(t)

	user := testUser(t, app, "non-model-config@example.com")
	harness, _ := seedTestHarnessAndInstance(t, app, "test-harness", true, user.Id)
	seedTwoModels(t, app, harness)

	chat := createTestChat(t, app, map[string]any{"harness": harness.Id})

	PersistModelOverride(app, chat.Id, "nonexistent-model-id")

	reloaded, err := app.FindRecordById("chats", chat.Id)
	if err != nil {
		t.Fatal(err)
	}
	if reloaded.GetString("harness_model_override") != "" {
		t.Fatal("harness_model_override should not be set when model is not found")
	}
}

type fakeAgentRuntime struct{}

func (fakeAgentRuntime) StartPrompt(chatID, prompt string, resolve coordinator.ResolveSession, profileFn coordinator.ProfileFunc, created coordinator.OnSessionCreated, finished coordinator.OnRunFinished, opts ...coordinator.RunOption) (string, error) {
	return "", nil
}
func (fakeAgentRuntime) Attach(chatID string, cursor int) coordinator.Attachment {
	return coordinator.Attachment{}
}
func (fakeAgentRuntime) NextSeq(chatID string) int { return 0 }
func (fakeAgentRuntime) StreamColdReplay(ctx context.Context, chatID, sessionID string, profileFn coordinator.ProfileFunc, emit func(seq int, ev events.Event) error) error {
	return nil
}
func (fakeAgentRuntime) Cancel(ctx context.Context, chatID string) error          { return nil }
func (fakeAgentRuntime) SetMode(ctx context.Context, chatID, modeID string) error { return nil }
func (fakeAgentRuntime) SetConfigOption(ctx context.Context, chatID string, req acpsdk.SetSessionConfigOptionRequest) error {
	return nil
}
func (fakeAgentRuntime) Approve(ctx context.Context, chatID, requestID, optionID string) error {
	return nil
}
func (fakeAgentRuntime) DenyPermission(chatID, requestID string) error { return nil }
func (fakeAgentRuntime) ResolveElicitation(chatID, id string, resp acpsdk.UnstableCreateElicitationResponse) error {
	return nil
}
func (fakeAgentRuntime) DeleteSession(ctx context.Context, app core.App, chatID string) error {
	return nil
}
func (fakeAgentRuntime) Shutdown(ctx context.Context)                     {}
func (fakeAgentRuntime) CheckIdempotency(chatID, key string) (any, bool)  { return nil, false }
func (fakeAgentRuntime) RecordIdempotency(chatID, key string, result any) {}

func setConfigOptionHTTP(t *testing.T, app core.App, chatID, token, configID, value string) *httptest.ResponseRecorder {
	t.Helper()
	router, err := apis.NewRouter(app)
	if err != nil {
		t.Fatal(err)
	}
	e := &core.ServeEvent{App: app, Router: router}
	registry := operation.NewRegistry()
	if _, err := AddAgentOperations(app, registry, AgentDeps{Runtime: fakeAgentRuntime{}}); err != nil {
		t.Fatal(err)
	}
	operation.MountForTests(e, registry.Routes())

	body := `{"configId":"` + configID + `","value":"` + value + `"}`
	req := httptest.NewRequest(http.MethodPost, "/api/pocketcoder/v1/chats/"+chatID+"/session/set-config-option", strings.NewReader(body))
	req.Header.Set("Authorization", token)
	req.Header.Set("Content-Type", "application/json")
	mux, err := e.Router.BuildMux()
	if err != nil {
		t.Fatal(err)
	}
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)
	return rec
}

func TestSetChatConfigOptionHTTPPersistsModelSwap(t *testing.T) {
	app := testApp(t)

	user := testUser(t, app, "http-model-swap@example.com")
	harness, _ := seedTestHarnessAndInstance(t, app, "test-harness", true, user.Id)
	hm1, hm2 := seedTwoModels(t, app, harness)

	chat := createTestChat(t, app, map[string]any{"user": user.Id, "harness": harness.Id, "harness_model_override": hm1.Id})
	token, err := user.NewAuthToken()
	if err != nil {
		t.Fatal(err)
	}

	rec := setConfigOptionHTTP(t, app, chat.Id, token, "model", "claude-3-opus")
	if rec.Code != http.StatusAccepted {
		t.Fatalf("status = %d, want 202: %s", rec.Code, rec.Body.String())
	}

	reloaded, err := app.FindRecordById("chats", chat.Id)
	if err != nil {
		t.Fatal(err)
	}
	if override := reloaded.GetString("harness_model_override"); override != hm2.Id {
		t.Fatalf("harness_model_override = %q, want %q (hm2.Id) after live-config model swap", override, hm2.Id)
	}
}

func TestSetChatConfigOptionHTTPIgnoresNonModelConfig(t *testing.T) {
	app := testApp(t)

	user := testUser(t, app, "http-mode-only@example.com")
	harness, _ := seedTestHarnessAndInstance(t, app, "test-harness", true, user.Id)
	hm1, _ := seedTwoModels(t, app, harness)

	chat := createTestChat(t, app, map[string]any{"user": user.Id, "harness": harness.Id, "harness_model_override": hm1.Id})
	token, err := user.NewAuthToken()
	if err != nil {
		t.Fatal(err)
	}

	rec := setConfigOptionHTTP(t, app, chat.Id, token, "mode", "approve")
	if rec.Code != http.StatusAccepted {
		t.Fatalf("status = %d, want 202: %s", rec.Code, rec.Body.String())
	}

	reloaded, err := app.FindRecordById("chats", chat.Id)
	if err != nil {
		t.Fatal(err)
	}
	if override := reloaded.GetString("harness_model_override"); override != hm1.Id {
		t.Fatalf("harness_model_override changed to %q on a \"mode\" config change, want unchanged %q", override, hm1.Id)
	}
}
