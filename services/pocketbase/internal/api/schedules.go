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

// @pocketcoder-core: Scheduler API. Per-user CRUD over Goose's
// _goose/unstable/schedules/* — see
// docs/superpowers/specs/2026-07-23-scheduler-ui-design.md. Unlike
// skills.go (household-global, admin-only), these routes are per-user:
// every caller manages only the schedules attributed to them in
// schedule_owners, resolved via resolveOwnedSchedule.
package api

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/security"

	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/coordinator"
)

// recipeDto mirrors the subset of Goose's RecipeDto (acp-schema.json) this
// design ever sets — title/description (both required by Goose) and an
// optional prompt. Every other RecipeDto field (extensions, parameters,
// sub_recipes, etc.) is intentionally never populated — see this plan's
// Global Constraints.
type recipeDto struct {
	Title       string  `json:"title"`
	Description string  `json:"description"`
	Prompt      *string `json:"prompt,omitempty"`
}

// scheduledJobDto mirrors Goose's ScheduledJobDto (acp-schema.json).
type scheduledJobDto struct {
	ID               string  `json:"id"`
	Source           string  `json:"source"`
	Cron             string  `json:"cron"`
	LastRun          *string `json:"lastRun"`
	CurrentlyRunning bool    `json:"currentlyRunning"`
	Paused           bool    `json:"paused"`
	CurrentSessionID *string `json:"currentSessionId"`
	JobStartTime     *string `json:"jobStartTime"`
}

type createScheduleParams struct {
	ID     string    `json:"id"`
	Recipe recipeDto `json:"recipe"`
	Cron   string    `json:"cron"`
}
type createScheduleResponse struct {
	Job scheduledJobDto `json:"job"`
}
type updateScheduleParams struct {
	ScheduleID string `json:"scheduleId"`
	Cron       string `json:"cron"`
}
type updateScheduleResponse struct {
	Job scheduledJobDto `json:"job"`
}

// scheduleIDParams mirrors every schedules/* request that takes only
// {"scheduleId": "..."} — pause, unpause, delete, run-now.
type scheduleIDParams struct {
	ScheduleID string `json:"scheduleId"`
}
type listSchedulesResponse struct {
	Jobs []scheduledJobDto `json:"jobs"`
}

// scheduleResp is what the Flutter Scheduler screen actually consumes —
// the schedule_owners row merged with its matching ScheduledJobDto.
type scheduleResp struct {
	ID               string  `json:"id"`
	DisplayName      string  `json:"displayName"`
	Cron             string  `json:"cron"`
	Paused           bool    `json:"paused"`
	CurrentlyRunning bool    `json:"currentlyRunning"`
	LastRun          *string `json:"lastRun"`
}

// createScheduleRequest is the HTTP body shape for POST
// /api/pocketcoder/schedules/create.
type createScheduleRequest struct {
	DisplayName string `json:"displayName"`
	Cron        string `json:"cron"`
	Prompt      string `json:"prompt"`
}

// buildCreateScheduleParams maps a validated createScheduleRequest plus a
// caller-generated goose_schedule_id onto createScheduleParams. Recipe
// title and description are both set to displayName — Goose requires both,
// this design only exposes one name field to the user.
func buildCreateScheduleParams(gooseScheduleID string, in createScheduleRequest) createScheduleParams {
	prompt := in.Prompt
	return createScheduleParams{
		ID: gooseScheduleID,
		Recipe: recipeDto{
			Title:       in.DisplayName,
			Description: in.DisplayName,
			Prompt:      &prompt,
		},
		Cron: in.Cron,
	}
}

// resolveOwnedSchedule looks up the schedule_owners row with the given
// PocketBase record id, scoped to userID. Returns a plain error (not an
// already-written HTTP response) for a foreign or nonexistent id — the
// caller decides how to translate that into a response (404, never 403,
// so a foreign id doesn't leak existence).
func resolveOwnedSchedule(app core.App, userID, id string) (*core.Record, error) {
	rec, err := app.FindRecordById("schedule_owners", id)
	if err != nil {
		return nil, fmt.Errorf("schedule not found: %w", err)
	}
	if rec.GetString("user") != userID {
		return nil, fmt.Errorf("schedule not found")
	}
	return rec, nil
}

// listSchedulesForUser is list's testable core: fetch the caller's own
// schedule_owners rows, call schedules/list once (Goose has no filter
// param — ListSchedulesRequest_unstable is an empty object, confirmed
// against acp-schema.json), and merge by goose_schedule_id. A
// schedule_owners row with no matching Goose job (deleted goose-side out
// of band) is silently skipped rather than failing the whole list.
func listSchedulesForUser(ctx context.Context, app core.App, coord func() *coordinator.Coordinator, userID string) ([]scheduleResp, error) {
	owners, err := app.FindRecordsByFilter("schedule_owners", "user = {:userId}", "", 0, 0, map[string]any{"userId": userID})
	if err != nil {
		return nil, fmt.Errorf("query schedule_owners: %w", err)
	}
	if len(owners) == 0 {
		return []scheduleResp{}, nil
	}

	c := coord()
	if c == nil {
		return nil, fmt.Errorf("agent profile not configured")
	}
	conn, err := c.AdminConn(ctx)
	if err != nil {
		return nil, fmt.Errorf("AdminConn: %w", err)
	}
	defer conn.Close()

	raw, err := conn.CallExtension(ctx, "_goose/unstable/schedules/list", struct{}{})
	if err != nil {
		return nil, fmt.Errorf("schedules/list: %w", err)
	}
	var resp listSchedulesResponse
	if err := json.Unmarshal(raw, &resp); err != nil {
		return nil, fmt.Errorf("parse schedules/list response: %w", err)
	}
	jobsByID := make(map[string]scheduledJobDto, len(resp.Jobs))
	for _, j := range resp.Jobs {
		jobsByID[j.ID] = j
	}

	out := make([]scheduleResp, 0, len(owners))
	for _, owner := range owners {
		job, ok := jobsByID[owner.GetString("goose_schedule_id")]
		if !ok {
			continue
		}
		out = append(out, scheduleResp{
			ID:               owner.Id,
			DisplayName:      owner.GetString("display_name"),
			Cron:             job.Cron,
			Paused:           job.Paused,
			CurrentlyRunning: job.CurrentlyRunning,
			LastRun:          job.LastRun,
		})
	}
	return out, nil
}

// RegisterSchedulesApi registers the per-user schedule CRUD endpoints.
// run-now is registered separately by Task 4, once hooks.ImportSession
// exists for it to call.
func RegisterSchedulesApi(app *pocketbase.PocketBase, e *core.ServeEvent, coord func() *coordinator.Coordinator) {
	e.Router.POST("/api/pocketcoder/schedules/list", func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(401, map[string]string{"error": "Authentication required"})
		}
		schedules, err := listSchedulesForUser(re.Request.Context(), app, coord, re.Auth.Id)
		if err != nil {
			return re.JSON(502, map[string]string{"error": err.Error()})
		}
		return re.JSON(200, map[string]any{"schedules": schedules})
	}).Bind(apis.RequireAuth())

	e.Router.POST("/api/pocketcoder/schedules/create", func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(401, map[string]string{"error": "Authentication required"})
		}
		var input createScheduleRequest
		if err := re.BindBody(&input); err != nil {
			return re.JSON(400, map[string]string{"error": "Invalid request body"})
		}
		if input.DisplayName == "" || input.Cron == "" || input.Prompt == "" {
			return re.JSON(400, map[string]string{"error": "displayName, cron, and prompt are required"})
		}

		conn, err := dialAdmin(re, coord)
		if err != nil {
			return err
		}
		defer conn.Close()

		var job scheduledJobDto
		var gooseScheduleID string
		const maxAttempts = 3
		for attempt := 0; ; attempt++ {
			gooseScheduleID = security.RandomString(20)
			raw, callErr := conn.CallExtension(re.Request.Context(), "_goose/unstable/schedules/create", buildCreateScheduleParams(gooseScheduleID, input))
			if callErr == nil {
				var resp createScheduleResponse
				if err := json.Unmarshal(raw, &resp); err != nil {
					return re.JSON(502, map[string]string{"error": "failed to parse goose response"})
				}
				job = resp.Job
				break
			}
			if strings.Contains(callErr.Error(), "already exists") && attempt < maxAttempts-1 {
				continue
			}
			return re.JSON(502, map[string]string{"error": fmt.Sprintf("goose schedules/create failed: %v", callErr)})
		}

		ownersCol, err := app.FindCollectionByNameOrId("schedule_owners")
		if err != nil {
			return re.JSON(500, map[string]string{"error": "Internal error"})
		}
		ownerRec := core.NewRecord(ownersCol)
		ownerRec.Set("user", re.Auth.Id)
		ownerRec.Set("goose_schedule_id", gooseScheduleID)
		ownerRec.Set("display_name", input.DisplayName)
		if err := app.Save(ownerRec); err != nil {
			// Best-effort rollback so a save failure doesn't leave an
			// orphaned Goose-side schedule with no owner.
			_, _ = conn.CallExtension(re.Request.Context(), "_goose/unstable/schedules/delete", scheduleIDParams{ScheduleID: gooseScheduleID})
			return re.JSON(500, map[string]string{"error": "Failed to save schedule ownership"})
		}

		return re.JSON(200, scheduleResp{
			ID: ownerRec.Id, DisplayName: input.DisplayName, Cron: job.Cron,
			Paused: job.Paused, CurrentlyRunning: job.CurrentlyRunning, LastRun: job.LastRun,
		})
	}).Bind(apis.RequireAuth())

	e.Router.POST("/api/pocketcoder/schedules/rename", func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(401, map[string]string{"error": "Authentication required"})
		}
		var input struct {
			ID          string `json:"id"`
			DisplayName string `json:"displayName"`
		}
		if err := re.BindBody(&input); err != nil {
			return re.JSON(400, map[string]string{"error": "Invalid request body"})
		}
		if input.ID == "" || input.DisplayName == "" {
			return re.JSON(400, map[string]string{"error": "id and displayName are required"})
		}
		owner, err := resolveOwnedSchedule(app, re.Auth.Id, input.ID)
		if err != nil {
			return re.JSON(404, map[string]string{"error": "Schedule not found"})
		}
		owner.Set("display_name", input.DisplayName)
		if err := app.Save(owner); err != nil {
			return re.JSON(500, map[string]string{"error": "Failed to rename schedule"})
		}
		return re.JSON(200, map[string]string{"id": owner.Id, "displayName": input.DisplayName})
	}).Bind(apis.RequireAuth())

	e.Router.POST("/api/pocketcoder/schedules/update-cron", func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(401, map[string]string{"error": "Authentication required"})
		}
		var input struct {
			ID   string `json:"id"`
			Cron string `json:"cron"`
		}
		if err := re.BindBody(&input); err != nil {
			return re.JSON(400, map[string]string{"error": "Invalid request body"})
		}
		if input.ID == "" || input.Cron == "" {
			return re.JSON(400, map[string]string{"error": "id and cron are required"})
		}
		owner, err := resolveOwnedSchedule(app, re.Auth.Id, input.ID)
		if err != nil {
			return re.JSON(404, map[string]string{"error": "Schedule not found"})
		}

		conn, err := dialAdmin(re, coord)
		if err != nil {
			return err
		}
		defer conn.Close()

		raw, callErr := conn.CallExtension(re.Request.Context(), "_goose/unstable/schedules/update", updateScheduleParams{
			ScheduleID: owner.GetString("goose_schedule_id"), Cron: input.Cron,
		})
		if callErr != nil {
			return re.JSON(502, map[string]string{"error": fmt.Sprintf("goose schedules/update failed: %v", callErr)})
		}
		var resp updateScheduleResponse
		if err := json.Unmarshal(raw, &resp); err != nil {
			return re.JSON(502, map[string]string{"error": "failed to parse goose response"})
		}
		return re.JSON(200, scheduleResp{
			ID: owner.Id, DisplayName: owner.GetString("display_name"), Cron: resp.Job.Cron,
			Paused: resp.Job.Paused, CurrentlyRunning: resp.Job.CurrentlyRunning, LastRun: resp.Job.LastRun,
		})
	}).Bind(apis.RequireAuth())

	registerPauseToggleRoute(e, app, coord, "/api/pocketcoder/schedules/pause", "_goose/unstable/schedules/pause")
	registerPauseToggleRoute(e, app, coord, "/api/pocketcoder/schedules/unpause", "_goose/unstable/schedules/unpause")

	e.Router.POST("/api/pocketcoder/schedules/delete", func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(401, map[string]string{"error": "Authentication required"})
		}
		var input struct {
			ID string `json:"id"`
		}
		if err := re.BindBody(&input); err != nil {
			return re.JSON(400, map[string]string{"error": "Invalid request body"})
		}
		if input.ID == "" {
			return re.JSON(400, map[string]string{"error": "id is required"})
		}
		owner, err := resolveOwnedSchedule(app, re.Auth.Id, input.ID)
		if err != nil {
			return re.JSON(404, map[string]string{"error": "Schedule not found"})
		}

		conn, err := dialAdmin(re, coord)
		if err != nil {
			return err
		}
		defer conn.Close()

		if _, callErr := conn.CallExtension(re.Request.Context(), "_goose/unstable/schedules/delete", scheduleIDParams{ScheduleID: owner.GetString("goose_schedule_id")}); callErr != nil {
			return re.JSON(502, map[string]string{"error": fmt.Sprintf("goose schedules/delete failed: %v", callErr)})
		}
		if err := app.Delete(owner); err != nil {
			return re.JSON(500, map[string]string{"error": "Failed to delete schedule ownership"})
		}
		return re.JSON(200, map[string]bool{"deleted": true})
	}).Bind(apis.RequireAuth())
}

// registerPauseToggleRoute registers a route sharing pause/unpause's exact
// shape — {"id": "..."} in, resolve ownership, call the given Goose method
// with {"scheduleId": "..."}.
func registerPauseToggleRoute(e *core.ServeEvent, app *pocketbase.PocketBase, coord func() *coordinator.Coordinator, path, gooseMethod string) {
	e.Router.POST(path, func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(401, map[string]string{"error": "Authentication required"})
		}
		var input struct {
			ID string `json:"id"`
		}
		if err := re.BindBody(&input); err != nil {
			return re.JSON(400, map[string]string{"error": "Invalid request body"})
		}
		if input.ID == "" {
			return re.JSON(400, map[string]string{"error": "id is required"})
		}
		owner, err := resolveOwnedSchedule(app, re.Auth.Id, input.ID)
		if err != nil {
			return re.JSON(404, map[string]string{"error": "Schedule not found"})
		}

		conn, err := dialAdmin(re, coord)
		if err != nil {
			return err
		}
		defer conn.Close()

		if _, callErr := conn.CallExtension(re.Request.Context(), gooseMethod, scheduleIDParams{ScheduleID: owner.GetString("goose_schedule_id")}); callErr != nil {
			return re.JSON(502, map[string]string{"error": fmt.Sprintf("goose %s failed: %v", gooseMethod, callErr)})
		}
		return re.JSON(200, map[string]bool{"ok": true})
	}).Bind(apis.RequireAuth())
}
