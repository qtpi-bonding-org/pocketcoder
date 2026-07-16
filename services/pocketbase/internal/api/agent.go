package api

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"net/http"
	"os"
	"strings"

	"github.com/ag-ui-protocol/ag-ui/sdks/community/go/pkg/core/events"
	"github.com/ag-ui-protocol/ag-ui/sdks/community/go/pkg/encoding/sse"
	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/coordinator"
)

// RegisterAgentApi registers PocketBase-owned routes. AG-UI is the response
// format, not a second public service and never exposes Goose credentials.
func RegisterAgentApi(app *pocketbase.PocketBase, e *core.ServeEvent) {
	service, configErr := coordinator.New(coordinator.Config{
		GooseURL:    os.Getenv("GOOSE_ACP_URL"),
		GooseSecret: os.Getenv("GOOSE_SERVER__SECRET_KEY"),
		Workspace:   os.Getenv("GOOSE_WORKSPACE"),
	})

	e.Router.POST("/api/pocketcoder/chats/{chatId}/runs", func(re *core.RequestEvent) error {
		if configErr != nil {
			return apis.NewApiError(http.StatusServiceUnavailable, "Agent service is not configured", nil)
		}
		chatID := re.Request.PathValue("chatId")
		chat, err := app.FindRecordById("chats", chatID)
		if err != nil || chat.GetString("user") != re.Auth.Id {
			return re.NotFoundError("Chat not found", err)
		}
		var input struct {
			Prompt string `json:"prompt"`
		}
		if err := re.BindBody(&input); err != nil {
			return re.BadRequestError("Invalid run request", err)
		}
		input.Prompt = strings.TrimSpace(input.Prompt)
		if input.Prompt == "" {
			return re.BadRequestError("prompt is required", nil)
		}

		re.Response.Header().Set("Content-Type", "text/event-stream")
		re.Response.Header().Set("Cache-Control", "no-cache")
		re.Response.Header().Set("Connection", "keep-alive")
		re.Response.WriteHeader(http.StatusOK)
		writer := sse.NewSSEWriter()
		emit := func(event events.Event) error { return writer.WriteEvent(re.Request.Context(), re.Response, event) }
		err = service.Run(re.Request.Context(), coordinator.RunRequest{
			ChatID: chatID, Prompt: input.Prompt,
		}, emit, func(ctx context.Context) (string, error) {
			return gooseSessionForChat(app, chatID, re.Auth.Id)
		}, func(ctx context.Context, sessionID string) error {
			return saveGooseSession(ctx, app, chatID, re.Auth.Id, sessionID)
		})
		if err != nil && !errors.Is(err, context.Canceled) {
			_ = emit(events.NewRunErrorEvent("Agent run failed", events.WithErrorCode("goose_unavailable")))
		}
		return nil
	}).Bind(apis.RequireAuth())

	e.Router.POST("/api/pocketcoder/chats/{chatId}/cancel", func(re *core.RequestEvent) error {
		if configErr != nil {
			return apis.NewApiError(http.StatusServiceUnavailable, "Agent service is not configured", nil)
		}
		chatID := re.Request.PathValue("chatId")
		chat, err := app.FindRecordById("chats", chatID)
		if err != nil || chat.GetString("user") != re.Auth.Id {
			return re.NotFoundError("Chat not found", err)
		}
		if err := service.Cancel(re.Request.Context(), chatID); err != nil {
			if errors.Is(err, coordinator.ErrNoActiveRun) {
				return re.BadRequestError("No active run to cancel", nil)
			}
			return apis.NewApiError(http.StatusBadGateway, "Unable to cancel agent run", err)
		}
		return re.NoContent(http.StatusAccepted)
	}).Bind(apis.RequireAuth())
}

func gooseSessionForChat(app core.App, chatID, userID string) (string, error) {
	record, err := app.FindFirstRecordByFilter("goose_sessions", "chat = {:chat} && user = {:user}", map[string]any{"chat": chatID, "user": userID})
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return "", nil
		}
		return "", err
	}
	return record.GetString("goose_session_id"), nil
}

func saveGooseSession(ctx context.Context, app core.App, chatID, userID, sessionID string) error {
	collection, err := app.FindCollectionByNameOrId("goose_sessions")
	if err != nil {
		return err
	}
	record := core.NewRecord(collection)
	record.Set("chat", chatID)
	record.Set("user", userID)
	record.Set("goose_session_id", sessionID)
	if err := app.Save(record); err != nil {
		return fmt.Errorf("save Goose session: %w", err)
	}
	return nil
}
