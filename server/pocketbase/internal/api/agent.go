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

// @pocketcoder-core: Agent API. The AG-UI SSE run, event replay, cancel, and approval routes for the mobile client.
package api

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/ag-ui-protocol/ag-ui/sdks/community/go/pkg/core/events"
	acpsdk "github.com/coder/acp-go-sdk"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/agent/coordinator"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/hooks"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/ollama"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/operation"
)

type AgentRuntime interface {
	StartPrompt(chatID, prompt string, resolve coordinator.ResolveSession, profileFn coordinator.ProfileFunc, created coordinator.OnSessionCreated, finished coordinator.OnRunFinished) (string, error)
	Attach(chatID string, cursor int) coordinator.Attachment
	NextSeq(chatID string) int
	StreamColdReplay(ctx context.Context, chatID, sessionID string, profileFn coordinator.ProfileFunc, emit func(seq int, ev events.Event) error) error
	Cancel(ctx context.Context, chatID string) error
	SetMode(ctx context.Context, chatID, modeID string) error
	SetConfigOption(ctx context.Context, chatID string, req acpsdk.SetSessionConfigOptionRequest) error
	Approve(ctx context.Context, chatID, requestID, optionID string) error
	DenyPermission(chatID, requestID string) error
	ResolveElicitation(chatID, id string, resp acpsdk.UnstableCreateElicitationResponse) error
	DeleteSession(ctx context.Context, app core.App, chatID string) error
	Shutdown(ctx context.Context)
}

type AgentDeps struct {
	Runtime AgentRuntime
	Dial    coordinator.DialFunc
}

func AddAgentOperations(app core.App, registry *operation.Registry, deps AgentDeps) (AgentRuntime, error) {
	workspace := os.Getenv("POCKETCODER_WORKSPACE")
	if workspace == "" {
		workspace = "/workspace"
	}
	ollamaBaseURL := ollama.ResolveBaseURL()
	var service AgentRuntime = deps.Runtime
	var configErr error
	if service == nil {
		concrete, err := coordinator.New(coordinator.Config{Workspace: workspace, PermissionTimeout: permissionTimeout(), Dial: deps.Dial})
		configErr = err
		if concrete != nil {
			service = concrete
		}
	}
	requireConfigured := func(action operation.Action) operation.Action {
		return func(re *core.RequestEvent) error {
			if configErr != nil {
				return apis.NewApiError(http.StatusServiceUnavailable, "Agent service is not configured", nil)
			}
			return action(re)
		}
	}
	if service != nil {
		app.OnTerminate().BindFunc(func(_ *core.TerminateEvent) error {
			ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer cancel()
			service.Shutdown(ctx)
			return nil
		})
	}

	registry.Add(operation.Route{OperationID: "promptChat", Method: http.MethodPost, Path: "/api/pocketcoder/v1/chats/{chatId}/session/prompt", Auth: true, Action: requireConfigured(func(re *core.RequestEvent) error {
		chatID := re.Request.PathValue("chatId")
		_, err := requireOwnedRecord(app, re, "chats", chatID)
		if err != nil {
			return err
		}
		var input acpsdk.PromptRequest
		if err := re.BindBody(&input); err != nil {
			return re.BadRequestError("Invalid run request", err)
		}
		prompt := ""
		for _, block := range input.Prompt {
			if block.Text != nil {
				prompt = strings.TrimSpace(block.Text.Text)
				break
			}
		}
		if prompt == "" {
			return re.BadRequestError("prompt must include a text content block", nil)
		}
		// buildSessionProfile is otherwise only invoked from inside
		// StartPrompt's detached run goroutine (via profileFn below), whose
		// errors are only ever surfaced as a RUN_ERROR hub event, never as
		// this handler's HTTP response — StartPrompt returns before that
		// goroutine runs. Resolve it once synchronously here too, but ONLY
		// short-circuit for the two new error conditions Task 7 introduces
		// (still provisioning / failed to start) — every other
		// buildSessionProfile error (e.g. a workspace-path rejection) must
		// keep falling through to StartPrompt unchanged, so it continues to
		// surface asynchronously via the existing RUN_ERROR SSE event exactly
		// as it did before this task, rather than becoming a new synchronous
		// 500 for error types this task didn't touch.
		if _, perr := buildSessionProfile(app, chatID, re.Request.Context(), ollamaBaseURL); perr != nil {
			if errors.Is(perr, ErrHarnessProvisioning) {
				return re.JSON(http.StatusAccepted, map[string]string{"status": "provisioning", "message": "Harness is starting; retry shortly"})
			}
			if errors.Is(perr, errHarnessFailed) {
				return apis.NewApiError(http.StatusBadGateway, "Harness failed to start", perr)
			}
		}
		runID, err := service.StartPrompt(chatID, prompt,
			func(context.Context) (string, error) { return agentSessionForChat(app, chatID, re.Auth.Id) },
			func(ctx context.Context) (coordinator.SessionProfile, error) {
				return buildSessionProfile(app, chatID, ctx, ollamaBaseURL)
			},
			func(ctx context.Context, sessionID string) error {
				profile, perr := buildSessionProfile(app, chatID, ctx, ollamaBaseURL)
				if perr != nil {
					return perr
				}
				err := saveAgentSession(ctx, app, chatID, re.Auth.Id, sessionID, profile.ResolvedInstanceID)
				if err == nil {
					app.Logger().Debug("Goose session mapping created", "chat_id", chatID)
				}
				return err
			},
			func(ctx context.Context, stopReason acpsdk.StopReason) error {
				go func() {
					if err := hooks.SendPushNotification(app, re.Auth.Id, "PocketCoder", "Your agent replied", "chat_reply", chatID); err != nil {
						log.Printf("[Push] chat reply: %v", err)
					}
				}()
				return nil
			})
		if err != nil {
			if errors.Is(err, coordinator.ErrRunInProgress) {
				return apis.NewApiError(http.StatusConflict, "A run is already active for this chat", nil)
			}
			return apis.NewApiError(http.StatusInternalServerError, "Unable to start agent run", err)
		}
		return re.JSON(http.StatusAccepted, map[string]string{"runId": runID})
	})})

	// GET stream is the durable subscription: it attaches to the chat's hub at
	// a caller-supplied cursor (?cursor= or Last-Event-ID), flushing the
	// active run's snapshot + backlog before tailing new live events. It never
	// Reserves — any number of subscribers can attach without stalling or
	// conflicting with an active run. A cursor whose history has been evicted
	// (ColdReplayNeeded) is first backfilled via a bounded Goose replay.
	registry.Add(operation.Route{OperationID: "streamChatEvents", Method: http.MethodGet, Path: "/api/pocketcoder/v1/chats/{chatId}/stream", Auth: true, Direct: true, Action: requireConfigured(func(re *core.RequestEvent) error {
		chatID := re.Request.PathValue("chatId")
		_, err := requireOwnedRecord(app, re, "chats", chatID)
		if err != nil {
			return err
		}
		cursor := parseCursor(re)
		att := service.Attach(chatID, cursor)
		defer att.Unsubscribe()

		re.Response.Header().Set("Content-Type", "text/event-stream")
		re.Response.Header().Set("Cache-Control", "no-cache")
		re.Response.Header().Set("Connection", "keep-alive")
		re.Response.WriteHeader(http.StatusOK)
		flusher, _ := re.Response.(http.Flusher)

		if att.ColdReplayNeeded {
			sessionID, err := agentSessionForChat(app, chatID, re.Auth.Id)
			if err != nil {
				_ = writeFlush(re.Response, flusher, service.NextSeq(chatID), events.NewRunErrorEvent("session mapping", events.WithErrorCode("goose_unavailable")))
			} else if err := service.StreamColdReplay(re.Request.Context(), chatID, sessionID,
				func(ctx context.Context) (coordinator.SessionProfile, error) {
					return buildSessionProfile(app, chatID, ctx, ollamaBaseURL)
				},
				func(seq int, ev events.Event) error {
					return writeFlush(re.Response, flusher, seq, ev)
				}); err != nil {
				// Response headers/status are already flushed by the time we
				// get here (SSE), so a distinct HTTP status is impossible —
				// the best we can do is a distinct SSE error code so the
				// client knows to retry shortly instead of treating this as
				// a hard replay failure.
				switch {
				case errors.Is(err, ErrHarnessProvisioning):
					_ = writeSeqFrame(re.Response, service.NextSeq(chatID), events.NewRunErrorEvent("harness starting", events.WithErrorCode("harness_provisioning")))
				case errors.Is(err, errHarnessFailed):
					_ = writeSeqFrame(re.Response, service.NextSeq(chatID), events.NewRunErrorEvent("harness failed to start", events.WithErrorCode("harness_failed")))
				default:
					_ = writeSeqFrame(re.Response, service.NextSeq(chatID), events.NewRunErrorEvent("replay failed", events.WithErrorCode("goose_replay_failed")))
				}
			}
		}
		for _, ev := range att.Snapshot {
			_ = writeFlush(re.Response, flusher, service.NextSeq(chatID), ev)
		}
		for _, e := range att.Buffered {
			_ = writeFlush(re.Response, flusher, e.Seq, e.Ev)
		}
		for {
			select {
			case <-re.Request.Context().Done():
				return nil
			case e, ok := <-att.Live:
				if !ok {
					return nil // dropped or run ended + unsubscribed
				}
				if err := writeFlush(re.Response, flusher, e.Seq, e.Ev); err != nil {
					return nil
				}
			}
		}
	})})

	registry.Add(operation.Route{OperationID: "cancelChatSession", Method: http.MethodPost, Path: "/api/pocketcoder/v1/chats/{chatId}/session/cancel", Auth: true, Action: requireConfigured(func(re *core.RequestEvent) error {
		chatID := re.Request.PathValue("chatId")
		_, err := requireOwnedRecord(app, re, "chats", chatID)
		if err != nil {
			return err
		}
		if err := service.Cancel(re.Request.Context(), chatID); err != nil {
			if errors.Is(err, coordinator.ErrNoActiveRun) {
				return re.BadRequestError("No active run to cancel", nil)
			}
			return apis.NewApiError(http.StatusBadGateway, "Unable to cancel agent run", err)
		}
		return re.NoContent(http.StatusAccepted)
	})})

	registry.Add(operation.Route{OperationID: "setChatMode", Method: http.MethodPost, Path: "/api/pocketcoder/v1/chats/{chatId}/session/set-mode", Auth: true, Action: requireConfigured(func(re *core.RequestEvent) error {
		chatID := re.Request.PathValue("chatId")
		_, err := requireOwnedRecord(app, re, "chats", chatID)
		if err != nil {
			return err
		}
		var input struct {
			ModeID string `json:"modeId"`
		}
		if err := re.BindBody(&input); err != nil || strings.TrimSpace(input.ModeID) == "" {
			return re.BadRequestError("modeId is required", err)
		}
		if err := service.SetMode(re.Request.Context(), chatID, input.ModeID); err != nil {
			if errors.Is(err, coordinator.ErrNoActiveRun) {
				return re.BadRequestError("No active run to set mode on", nil)
			}
			return apis.NewApiError(http.StatusBadGateway, "Unable to set mode", err)
		}
		return re.NoContent(http.StatusAccepted)
	})})

	registry.Add(operation.Route{OperationID: "setChatConfigOption", Method: http.MethodPost, Path: "/api/pocketcoder/v1/chats/{chatId}/session/set-config-option", Auth: true, Action: requireConfigured(func(re *core.RequestEvent) error {
		chatID := re.Request.PathValue("chatId")
		_, err := requireOwnedRecord(app, re, "chats", chatID)
		if err != nil {
			return err
		}
		var req acpsdk.SetSessionConfigOptionRequest
		if err := re.BindBody(&req); err != nil {
			return re.BadRequestError("Invalid config option request", err)
		}
		if req.Boolean == nil && req.ValueId == nil {
			return re.BadRequestError("a config option value is required", nil)
		}
		if err := service.SetConfigOption(re.Request.Context(), chatID, req); err != nil {
			if errors.Is(err, coordinator.ErrNoActiveRun) {
				return re.BadRequestError("No active run to set config on", nil)
			}
			return apis.NewApiError(http.StatusBadGateway, "Unable to set config option", err)
		}
		return re.NoContent(http.StatusAccepted)
	})})

	// Permission records are transient process state. The option is checked
	// against the exact set Goose offered before it is forwarded over ACP.
	registry.Add(operation.Route{OperationID: "respondToPermission", Method: http.MethodPost, Path: "/api/pocketcoder/v1/chats/{chatId}/session/request-permission/{id}", Auth: true, Action: requireConfigured(func(re *core.RequestEvent) error {
		chatID := re.Request.PathValue("chatId")
		_, err := requireOwnedRecord(app, re, "chats", chatID)
		if err != nil {
			return err
		}
		var input acpsdk.RequestPermissionResponse
		if err := re.BindBody(&input); err != nil {
			return re.BadRequestError("Invalid permission response", err)
		}
		requestID := re.Request.PathValue("id")
		switch {
		case input.Outcome.Selected != nil:
			optionID := strings.TrimSpace(string(input.Outcome.Selected.OptionId))
			if optionID == "" {
				return re.BadRequestError("optionId is required", nil)
			}
			err = service.Approve(re.Request.Context(), chatID, requestID, optionID)
		case input.Outcome.Cancelled != nil:
			err = service.DenyPermission(chatID, requestID)
		default:
			return re.BadRequestError("outcome must be selected or cancelled", nil)
		}
		if errors.Is(err, coordinator.ErrNoPendingPermission) {
			return re.NotFoundError("Pending permission not found", err)
		}
		if errors.Is(err, coordinator.ErrPermissionOptionNotOffered) {
			return re.BadRequestError("Permission option was not offered", err)
		}
		if err != nil {
			return apis.NewApiError(http.StatusBadGateway, "Unable to submit permission decision", err)
		}
		return re.NoContent(http.StatusAccepted)
	})})

	// Elicitation is a separate ACP side-channel from permission (spec N5):
	// its own id-space, its own resolution path.
	registry.Add(operation.Route{OperationID: "respondToElicitation", Method: http.MethodPost, Path: "/api/pocketcoder/v1/chats/{chatId}/session/elicitation/{id}", Auth: true, Action: requireConfigured(func(re *core.RequestEvent) error {
		chatID := re.Request.PathValue("chatId")
		_, err := requireOwnedRecord(app, re, "chats", chatID)
		if err != nil {
			return err
		}
		var input struct {
			Action  string         `json:"action"`
			Content map[string]any `json:"content,omitempty"`
		}
		if err := re.BindBody(&input); err != nil {
			return re.BadRequestError("Invalid elicitation response", err)
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
			return re.BadRequestError("action must be accept, decline, or cancel", nil)
		}
		err = service.ResolveElicitation(chatID, re.Request.PathValue("id"), resp)
		if errors.Is(err, coordinator.ErrNoPendingElicitation) {
			return re.NotFoundError("Pending elicitation not found", err)
		}
		if err != nil {
			return apis.NewApiError(http.StatusBadGateway, "Unable to submit elicitation response", err)
		}
		return re.NoContent(http.StatusAccepted)
	})})

	if service != nil {
		// Best-effort cleanup: a deleted chat's mapped Agent session is
		// deleted too, but a failure never blocks the record delete — the row
		// is left for a future reconcile sweep (v1 floor, documented).
		app.OnRecordAfterDeleteSuccess("chats").BindFunc(func(re *core.RecordEvent) error {
			chatID := re.Record.Id
			go func() {
				if err := service.DeleteSession(context.Background(), app, chatID); err != nil {
					app.Logger().Error("agent session delete failed; left for reconcile", "chat_id", chatID, "error", err)
				}
			}()
			return re.Next()
		})
	}

	return service, configErr
}

// parseCursor reads the resume cursor from ?cursor= or the Last-Event-ID
// header (falling back to 0, meaning "everything"). ?cursor= wins if both
// are present.
func parseCursor(re *core.RequestEvent) int {
	if raw := re.Request.URL.Query().Get("cursor"); raw != "" {
		if n, err := strconv.Atoi(raw); err == nil {
			return n
		}
	}
	if raw := re.Request.Header.Get("Last-Event-ID"); raw != "" {
		if n, err := strconv.Atoi(raw); err == nil {
			return n
		}
	}
	return 0
}

func writeFlush(w http.ResponseWriter, flusher http.Flusher, seq int, ev events.Event) error {
	if err := writeSeqFrame(w, seq, ev); err != nil {
		return err
	}
	if flusher != nil {
		flusher.Flush()
	}
	return nil
}

func permissionTimeout() time.Duration {
	value := strings.TrimSpace(os.Getenv("POCKETCODER_PERMISSION_TIMEOUT"))
	if value == "" {
		return 5 * time.Minute
	}
	duration, err := time.ParseDuration(value)
	if err != nil || duration <= 0 {
		return 5 * time.Minute
	}
	return duration
}

func agentSessionForChat(app core.App, chatID, userID string) (string, error) {
	record, err := app.FindFirstRecordByFilter("agent_sessions", "chat = {:chat} && user = {:user}", map[string]any{"chat": chatID, "user": userID})
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return "", nil
		}
		return "", err
	}
	return record.GetString("acp_session_id"), nil
}

func saveAgentSession(ctx context.Context, app core.App, chatID, userID, sessionID, harnessInstanceID string) error {
	collection, err := app.FindCollectionByNameOrId("agent_sessions")
	if err != nil {
		return err
	}
	record := core.NewRecord(collection)
	record.Set("chat", chatID)
	record.Set("user", userID)
	record.Set("acp_session_id", sessionID)
	record.Set("harness_instance", harnessInstanceID)
	if err := app.Save(record); err != nil {
		return fmt.Errorf("save Agent session: %w", err)
	}
	return nil
}
