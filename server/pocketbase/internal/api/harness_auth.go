/*
PocketCoder: An accessible, secure, and user-friendly open-source coding assistant platform.
Copyright (C) 2026 Qtpi Bonding LLC

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.
*/

package api

import (
	"context"
	"errors"
	"github.com/pocketbase/pocketbase/apis"
	"log"
	"net/http"
	"strings"

	"github.com/pocketbase/pocketbase/core"

	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/harnessaccount"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/harnessauth"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/operation"
)

type harnessAuthRequest struct {
	Harness     string `json:"harness"`
	Provider    string `json:"provider"` // pc_providers record id -- required on every operation now
	AccountID   string `json:"accountId"`
	AccountName string `json:"accountName"`
	Visibility  string `json:"visibility"`
	Mode        string `json:"mode"` // "oauth" | "none" -- "api_key" is gone; keys are plain provider_api_keys CRUD (Task 13)
	AttemptID   string `json:"attemptId"`
	Code        string `json:"code"`
}

type harnessAuthChallengeResp struct {
	Type    string `json:"type"`
	Text    string `json:"text"`
	Target  string `json:"target,omitempty"`
	Details string `json:"details,omitempty"`
}

type harnessAuthAttemptResp struct {
	ID        string `json:"id"`
	Status    string `json:"status"`
	LastError string `json:"lastError,omitempty"`
}

type harnessAuthStatusResp struct {
	Harness     string                    `json:"harness"`
	Provider    string                    `json:"provider"`
	AccountID   string                    `json:"accountId,omitempty"`
	AccountName string                    `json:"accountName,omitempty"`
	Visibility  string                    `json:"visibility,omitempty"`
	Mode        string                    `json:"mode"`
	Status      string                    `json:"status"`
	LastError   string                    `json:"lastError,omitempty"`
	Attempt     *harnessAuthAttemptResp   `json:"attempt,omitempty"`
	Challenge   *harnessAuthChallengeResp `json:"challenge,omitempty"`
}
type HarnessAuthStatusResponse = harnessAuthStatusResp

type harnessAuthRuntime interface {
	Start(context.Context, string, harnessauth.AttemptContext) (*harnessauth.AttemptState, error)
	Poll(context.Context, string, harnessauth.AttemptContext) (*harnessauth.AttemptState, error)
	Submit(context.Context, string, harnessauth.AttemptContext, string) (*harnessauth.AttemptState, error)
	Cancel(context.Context, string, harnessauth.AttemptContext) (*harnessauth.AttemptState, error)
	Disconnect(context.Context, string, harnessauth.AttemptContext) (*harnessauth.AttemptState, error)
}
type HarnessAuthRuntime = harnessAuthRuntime

type HarnessAuthDeps struct {
	Runtime harnessAuthRuntime
}

// resolveMode returns the user's currently selected credential_selections.mode
// for (harness, provider), or harnessauth.ModeNone if no selection exists yet.
func resolveMode(app core.App, userID, harnessID, providerID string) string {
	sel, err := app.FindFirstRecordByFilter(
		"credential_selections",
		"user = {:u} && harness = {:h} && provider = {:p}",
		map[string]any{"u": userID, "h": harnessID, "p": providerID},
	)
	if err != nil {
		return harnessauth.ModeNone
	}
	return sel.GetString("mode")
}

// clearSelectionToNone upserts a credential_selections row with mode=none
// for (harness, provider), clearing any oauth_account it may have carried
// (Task 5's OnRecordUpdate hook enforces the clear; this handles the
// create-a-fresh-"none"-row path where there's nothing to clear yet).
func clearSelectionToNone(app core.App, userID, harnessID, providerID string) error {
	sel, err := app.FindFirstRecordByFilter(
		"credential_selections",
		"user = {:u} && harness = {:h} && provider = {:p}",
		map[string]any{"u": userID, "h": harnessID, "p": providerID},
	)
	if err != nil {
		coll, collErr := app.FindCollectionByNameOrId("credential_selections")
		if collErr != nil {
			return collErr
		}
		sel = core.NewRecord(coll)
		sel.Set("user", userID)
		sel.Set("harness", harnessID)
		sel.Set("provider", providerID)
	}
	sel.Set("mode", "none")
	return app.Save(sel)
}

func GetHarnessAuthStatus(app core.App, re *core.RequestEvent) (harnessAuthStatusResp, error) {
	if re.Auth == nil {
		return harnessAuthStatusResp{}, re.UnauthorizedError("Authentication required", nil)
	}
	var input harnessAuthRequest
	if err := re.BindBody(&input); err != nil {
		return harnessAuthStatusResp{}, re.BadRequestError("Invalid request body", nil)
	}
	if input.Harness == "" || input.Provider == "" {
		return harnessAuthStatusResp{}, re.BadRequestError("harness and provider are required", nil)
	}
	if _, err := app.FindRecordById("harnesses", input.Harness); err != nil {
		return harnessAuthStatusResp{}, re.NotFoundError("Harness not found", nil)
	}
	account, err := harnessaccount.Resolve(app, re.Auth.Id, input.Harness, input.Provider, input.AccountID)
	if err != nil {
		log.Printf("[HarnessAuth] resolve account: %v", err)
		return harnessAuthStatusResp{}, re.InternalServerError("Internal error", nil)
	}
	mode := resolveMode(app, re.Auth.Id, input.Harness, input.Provider)
	if account == nil {
		return harnessAuthStatusResp{Harness: input.Harness, Provider: input.Provider, Status: harnessauth.StatusDisconnected, Mode: mode}, nil
	}
	attempt, _ := harnessauth.ActiveAttempt(app, account.Id)
	return renderHarnessAuthStatus(account, attempt, mode), nil
}

func StartHarnessAuth(app core.App, runtime harnessAuthRuntime, re *core.RequestEvent) (harnessAuthStatusResp, error) {
	if re.Auth == nil {
		return harnessAuthStatusResp{}, re.UnauthorizedError("Authentication required", nil)
	}
	var input harnessAuthRequest
	if err := re.BindBody(&input); err != nil {
		return harnessAuthStatusResp{}, re.BadRequestError("Invalid request body", nil)
	}
	if input.Harness == "" || input.Provider == "" {
		return harnessAuthStatusResp{}, re.BadRequestError("harness and provider are required", nil)
	}
	if _, err := app.FindRecordById("harnesses", input.Harness); err != nil {
		return harnessAuthStatusResp{}, re.NotFoundError("Harness not found", nil)
	}
	if _, err := app.FindRecordById("providers", input.Provider); err != nil {
		return harnessAuthStatusResp{}, re.NotFoundError("Provider not found", nil)
	}
	mode := strings.TrimSpace(input.Mode)
	if mode == "" {
		mode = "oauth"
	}
	if mode != "oauth" && mode != "none" {
		return harnessAuthStatusResp{}, re.BadRequestError("mode must be one of oauth|none", nil)
	}
	if mode == "none" {
		if err := clearSelectionToNone(app, re.Auth.Id, input.Harness, input.Provider); err != nil {
			return harnessAuthStatusResp{}, re.InternalServerError("Internal error", nil)
		}
		return harnessAuthStatusResp{Harness: input.Harness, Provider: input.Provider, Mode: "none", Status: harnessauth.StatusDisconnected}, nil
	}
	edge, err := app.FindFirstRecordByFilter("harness_providers", "harness = {:h} && provider = {:p}", map[string]any{"h": input.Harness, "p": input.Provider})
	if err != nil || !edge.GetBool("supports_oauth") {
		return harnessAuthStatusResp{}, re.BadRequestError("this provider does not support account login for this harness", nil)
	}
	visibility := strings.TrimSpace(input.Visibility)
	if visibility == "" {
		visibility = harnessaccount.VisibilityPersonal
	}
	account, err := harnessaccount.SelectOrCreate(app, re.Auth.Id, input.Harness, input.Provider, input.AccountID, input.AccountName, visibility)
	if err != nil {
		return harnessAuthStatusResp{}, re.InternalServerError("Internal error", nil)
	}
	if account.GetString("owner") != re.Auth.Id {
		return harnessAuthStatusResp{}, re.ForbiddenError("Only the account owner can change harness credentials", nil)
	}
	key, err := harnessauth.ResolveAuthenticatorKey(app, account)
	if err != nil {
		return harnessAuthStatusResp{}, re.BadRequestError(err.Error(), nil)
	}
	attempt, err := harnessauth.CreateAttempt(app, account.Id)
	if err != nil {
		return harnessAuthStatusResp{}, re.InternalServerError("Unable to create auth attempt", nil)
	}
	stateCtx, err := harnessauth.BuildAttemptContext(app, attempt, re.Auth.Id)
	if err != nil {
		return harnessAuthStatusResp{}, re.InternalServerError(err.Error(), nil)
	}
	state, err := runtime.Start(re.Request.Context(), key, stateCtx)
	if err != nil {
		return harnessAuthStatusResp{}, apis.NewApiError(502, "Unable to start auth helper", nil)
	}
	if err := harnessauth.UpdateAttempt(app, attempt, state.Status, ""); err != nil {
		return harnessAuthStatusResp{}, re.InternalServerError("Unable to update auth attempt", nil)
	}
	account.Set("status", harnessauth.StatusForAttempt(state.Status))
	account.Set("last_error", "")
	if err := app.Save(account); err != nil {
		return harnessAuthStatusResp{}, re.InternalServerError("Unable to save account", nil)
	}
	response := renderHarnessAuthStatus(account, attempt, "oauth")
	if state.Challenge != nil {
		response.Challenge = &harnessAuthChallengeResp{Type: state.Challenge.Type, Text: state.Challenge.Text, Target: state.Challenge.Target, Details: state.Challenge.Details}
	}
	return response, nil
}

func authRequest(app core.App, re *core.RequestEvent) (harnessAuthRequest, *core.Record, *core.Record, error) {
	var input harnessAuthRequest
	if err := re.BindBody(&input); err != nil {
		return input, nil, nil, re.BadRequestError("Invalid request body", nil)
	}
	if input.Provider == "" {
		return input, nil, nil, re.BadRequestError("provider is required", nil)
	}
	account, attempt, err := harnessauth.ResolveAccountAndAttempt(app, re.Auth.Id, input.Harness, input.Provider, input.AccountID, input.AttemptID)
	if err != nil {
		return input, nil, nil, re.BadRequestError(err.Error(), nil)
	}
	if account.GetString("owner") != re.Auth.Id {
		return input, nil, nil, re.ForbiddenError("Only the account owner can manage harness authentication", nil)
	}
	if attempt == nil {
		return input, account, nil, re.NotFoundError("No active auth attempt found", nil)
	}
	return input, account, attempt, nil
}

func PollHarnessAuth(app core.App, runtime harnessAuthRuntime, re *core.RequestEvent) (harnessAuthStatusResp, error) {
	if re.Auth == nil {
		return harnessAuthStatusResp{}, re.UnauthorizedError("Authentication required", nil)
	}
	input, account, attempt, err := authRequest(app, re)
	if err != nil {
		return harnessAuthStatusResp{}, err
	}
	key, err := harnessauth.ResolveAuthenticatorKey(app, account)
	if err != nil {
		return harnessAuthStatusResp{}, re.BadRequestError(err.Error(), nil)
	}
	ctx, err := harnessauth.BuildAttemptContext(app, attempt, re.Auth.Id)
	if err != nil {
		return harnessAuthStatusResp{}, re.InternalServerError(err.Error(), nil)
	}
	state, err := runtime.Poll(re.Request.Context(), key, ctx)
	if err != nil {
		return harnessAuthStatusResp{}, apis.NewApiError(502, "Auth helper poll failed", nil)
	}
	if err := harnessauth.UpdateAttempt(app, attempt, state.Status, state.LastError); err != nil {
		return harnessAuthStatusResp{}, re.InternalServerError("Unable to update auth attempt", nil)
	}
	account.Set("status", harnessauth.StatusForAttempt(state.Status))
	account.Set("last_error", state.LastError)
	if err := app.Save(account); err != nil {
		return harnessAuthStatusResp{}, re.InternalServerError("Unable to save account", nil)
	}
	response := renderHarnessAuthStatus(account, attempt, "oauth")
	if state.Challenge != nil {
		response.Challenge = &harnessAuthChallengeResp{Type: state.Challenge.Type, Text: state.Challenge.Text, Target: state.Challenge.Target, Details: state.Challenge.Details}
	}
	_ = input
	return response, nil
}

func SubmitHarnessAuth(app core.App, runtime harnessAuthRuntime, re *core.RequestEvent) (harnessAuthStatusResp, error) {
	if re.Auth == nil {
		return harnessAuthStatusResp{}, re.UnauthorizedError("Authentication required", nil)
	}
	input, account, attempt, err := authRequest(app, re)
	if err != nil {
		return harnessAuthStatusResp{}, err
	}
	code := strings.TrimSpace(input.Code)
	if code == "" {
		return harnessAuthStatusResp{}, re.BadRequestError("code is required", nil)
	}
	key, err := harnessauth.ResolveAuthenticatorKey(app, account)
	if err != nil {
		return harnessAuthStatusResp{}, re.BadRequestError(err.Error(), nil)
	}
	ctx, err := harnessauth.BuildAttemptContext(app, attempt, re.Auth.Id)
	if err != nil {
		return harnessAuthStatusResp{}, re.InternalServerError(err.Error(), nil)
	}
	state, err := runtime.Submit(re.Request.Context(), key, ctx, code)
	if err != nil {
		return harnessAuthStatusResp{}, apis.NewApiError(502, err.Error(), nil)
	}
	if err := harnessauth.UpdateAttempt(app, attempt, state.Status, state.LastError); err != nil {
		return harnessAuthStatusResp{}, re.InternalServerError("Unable to update auth attempt", nil)
	}
	account.Set("status", harnessauth.StatusForAttempt(state.Status))
	account.Set("last_error", state.LastError)
	if err := app.Save(account); err != nil {
		return harnessAuthStatusResp{}, re.InternalServerError("Unable to save account", nil)
	}
	return renderHarnessAuthStatus(account, attempt, "oauth"), nil
}

func CancelHarnessAuth(app core.App, runtime harnessAuthRuntime, re *core.RequestEvent) (harnessAuthStatusResp, error) {
	if re.Auth == nil {
		return harnessAuthStatusResp{}, re.UnauthorizedError("Authentication required", nil)
	}
	_, account, attempt, err := authRequest(app, re)
	if err != nil {
		return harnessAuthStatusResp{}, err
	}
	key, err := harnessauth.ResolveAuthenticatorKey(app, account)
	if err != nil {
		return harnessAuthStatusResp{}, re.BadRequestError(err.Error(), nil)
	}
	ctx, err := harnessauth.BuildAttemptContext(app, attempt, re.Auth.Id)
	if err != nil {
		return harnessAuthStatusResp{}, re.InternalServerError(err.Error(), nil)
	}
	state, err := runtime.Cancel(re.Request.Context(), key, ctx)
	if err != nil {
		return harnessAuthStatusResp{}, apis.NewApiError(502, "Auth helper cancel failed", nil)
	}
	if err := harnessauth.UpdateAttempt(app, attempt, state.Status, state.LastError); err != nil {
		return harnessAuthStatusResp{}, re.InternalServerError("Unable to update auth attempt", nil)
	}
	account.Set("status", harnessauth.StatusForAttempt(state.Status))
	account.Set("last_error", state.LastError)
	if err := app.Save(account); err != nil {
		return harnessAuthStatusResp{}, re.InternalServerError("Unable to save account", nil)
	}
	return renderHarnessAuthStatus(account, attempt, "oauth"), nil
}

func DisconnectHarnessAuth(app core.App, runtime harnessAuthRuntime, re *core.RequestEvent) (harnessAuthStatusResp, error) {
	if re.Auth == nil {
		return harnessAuthStatusResp{}, re.UnauthorizedError("Authentication required", nil)
	}
	var input harnessAuthRequest
	if err := re.BindBody(&input); err != nil {
		return harnessAuthStatusResp{}, re.BadRequestError("Invalid request body", nil)
	}
	if input.Harness == "" || input.Provider == "" {
		return harnessAuthStatusResp{}, re.BadRequestError("harness and provider are required", nil)
	}
	account, err := harnessaccount.Resolve(app, re.Auth.Id, input.Harness, input.Provider, input.AccountID)
	if err != nil {
		return harnessAuthStatusResp{}, re.InternalServerError("Internal error", nil)
	}
	if account == nil {
		return harnessAuthStatusResp{}, re.NotFoundError("Account not found", nil)
	}
	if account.GetString("owner") != re.Auth.Id {
		return harnessAuthStatusResp{}, re.ForbiddenError("Only the account owner can disconnect harness credentials", nil)
	}
	attempt, err := harnessauth.LatestAttempt(app, account.Id)
	if err != nil {
		return harnessAuthStatusResp{}, re.InternalServerError("Internal error", nil)
	}
	if attempt != nil {
		if key, keyErr := harnessauth.ResolveAuthenticatorKey(app, account); keyErr == nil {
			if ctx, ctxErr := harnessauth.BuildAttemptContext(app, attempt, re.Auth.Id); ctxErr == nil {
				if state, callErr := runtime.Disconnect(re.Request.Context(), key, ctx); callErr == nil {
					_ = harnessauth.UpdateAttempt(app, attempt, state.Status, state.LastError)
				}
			}
		}
	}
	account.Set("status", harnessauth.StatusDisconnected)
	account.Set("last_error", "")
	if err := app.Save(account); err != nil {
		return harnessAuthStatusResp{}, re.InternalServerError("Unable to save account", nil)
	}
	return renderHarnessAuthStatus(account, attempt, "oauth"), nil
}

func AddHarnessAuthOperations(app core.App, registry *operation.Registry, deps HarnessAuthDeps) harnessAuthRuntime {
	runtime := deps.Runtime
	if runtime == nil {
		runtime = harnessauth.NewDefaultRuntime()
	}

	registry.Add(operation.Route{OperationID: "getHarnessAuthStatus", Method: http.MethodPost, Path: "/api/pocketcoder/v1/harness-auth/status", Auth: true, Action: func(re *core.RequestEvent) error {
		response, err := GetHarnessAuthStatus(app, re)
		if err != nil {
			return err
		}
		return re.JSON(200, response)
	}})

	registry.Add(operation.Route{OperationID: "startHarnessAuth", Method: http.MethodPost, Path: "/api/pocketcoder/v1/harness-auth/start", Auth: true, Action: func(re *core.RequestEvent) error {
		response, err := StartHarnessAuth(app, runtime, re)
		if err != nil {
			return err
		}
		return re.JSON(200, response)
	}})
	registry.Add(operation.Route{OperationID: "pollHarnessAuth", Method: http.MethodPost, Path: "/api/pocketcoder/v1/harness-auth/poll", Auth: true, Action: func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.UnauthorizedError("Authentication required", nil)
		}
		var input harnessAuthRequest
		if err := re.BindBody(&input); err != nil {
			return re.BadRequestError("Invalid request body", nil)
		}
		if input.Provider == "" {
			return re.BadRequestError("provider is required", nil)
		}
		account, attempt, err := harnessauth.ResolveAccountAndAttempt(app, re.Auth.Id, input.Harness, input.Provider, input.AccountID, input.AttemptID)
		if err != nil {
			return re.BadRequestError(err.Error(), nil)
		}
		if account.GetString("owner") != re.Auth.Id {
			return re.ForbiddenError("Only the account owner can manage harness authentication", nil)
		}
		if attempt == nil {
			return re.NotFoundError("No active auth attempt found", nil)
		}
		authenticatorKey, err := harnessauth.ResolveAuthenticatorKey(app, account)
		if err != nil {
			return re.BadRequestError(err.Error(), nil)
		}
		stateCtx, err := harnessauth.BuildAttemptContext(app, attempt, re.Auth.Id)
		if err != nil {
			return re.InternalServerError(err.Error(), nil)
		}
		state, err := runtime.Poll(re.Request.Context(), authenticatorKey, stateCtx)
		if err != nil {
			if errors.Is(err, harnessauth.ErrAttemptExpired) {
				if updateErr := harnessauth.UpdateAttempt(app, attempt, harnessauth.AttemptStatusFailed, "Auth attempt expired"); updateErr != nil {
					log.Printf("[HarnessAuth] update expired auth attempt: %v", updateErr)
				}
				account.Set("status", harnessauth.StatusError)
				account.Set("last_error", "Auth attempt expired")
				if saveErr := app.Save(account); saveErr != nil {
					log.Printf("[HarnessAuth] save account: %v", saveErr)
				}
				return apis.NewApiError(410, "Auth attempt expired", nil)
			}
			return apis.NewApiError(502, "Auth helper poll failed", nil)
		}
		if err := harnessauth.UpdateAttempt(app, attempt, state.Status, state.LastError); err != nil {
			return re.InternalServerError("Unable to update auth attempt", nil)
		}
		account.Set("status", harnessauth.StatusForAttempt(state.Status))
		account.Set("last_error", state.LastError)
		if saveErr := app.Save(account); saveErr != nil {
			log.Printf("[HarnessAuth] save account: %v", saveErr)
		}
		response := renderHarnessAuthStatus(account, attempt, "oauth")
		if state.Challenge != nil {
			response.Challenge = &harnessAuthChallengeResp{Type: state.Challenge.Type, Text: state.Challenge.Text, Target: state.Challenge.Target, Details: state.Challenge.Details}
		}
		return re.JSON(200, response)
	}})

	registry.Add(operation.Route{OperationID: "submitHarnessAuth", Method: http.MethodPost, Path: "/api/pocketcoder/v1/harness-auth/submit", Auth: true, Action: func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.UnauthorizedError("Authentication required", nil)
		}
		var input harnessAuthRequest
		if err := re.BindBody(&input); err != nil {
			return re.BadRequestError("Invalid request body", nil)
		}
		if input.Provider == "" {
			return re.BadRequestError("provider is required", nil)
		}
		account, attempt, err := harnessauth.ResolveAccountAndAttempt(app, re.Auth.Id, input.Harness, input.Provider, input.AccountID, input.AttemptID)
		if err != nil {
			return re.BadRequestError(err.Error(), nil)
		}
		if account.GetString("owner") != re.Auth.Id {
			return re.ForbiddenError("Only the account owner can manage harness authentication", nil)
		}
		if attempt == nil {
			return re.NotFoundError("No active auth attempt found", nil)
		}
		code := strings.TrimSpace(input.Code)
		if code == "" {
			return re.BadRequestError("code is required", nil)
		}
		authenticatorKey, err := harnessauth.ResolveAuthenticatorKey(app, account)
		if err != nil {
			return re.BadRequestError(err.Error(), nil)
		}
		stateCtx, err := harnessauth.BuildAttemptContext(app, attempt, re.Auth.Id)
		if err != nil {
			return re.InternalServerError(err.Error(), nil)
		}
		state, err := runtime.Submit(re.Request.Context(), authenticatorKey, stateCtx, code)
		if err != nil {
			account.Set("status", harnessauth.StatusError)
			account.Set("last_error", err.Error())
			if saveErr := app.Save(account); saveErr != nil {
				log.Printf("[HarnessAuth] save account: %v", saveErr)
			}
			return apis.NewApiError(502, err.Error(), nil)
		}
		if err := harnessauth.UpdateAttempt(app, attempt, state.Status, state.LastError); err != nil {
			return re.InternalServerError("Unable to update auth attempt", nil)
		}
		account.Set("status", harnessauth.StatusForAttempt(state.Status))
		account.Set("last_error", state.LastError)
		if saveErr := app.Save(account); saveErr != nil {
			log.Printf("[HarnessAuth] save account: %v", saveErr)
		}
		return re.JSON(200, renderHarnessAuthStatus(account, attempt, "oauth"))
	}})

	registry.Add(operation.Route{OperationID: "cancelHarnessAuth", Method: http.MethodPost, Path: "/api/pocketcoder/v1/harness-auth/cancel", Auth: true, Action: func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.UnauthorizedError("Authentication required", nil)
		}
		var input harnessAuthRequest
		if err := re.BindBody(&input); err != nil {
			return re.BadRequestError("Invalid request body", nil)
		}
		if input.Provider == "" {
			return re.BadRequestError("provider is required", nil)
		}
		account, attempt, err := harnessauth.ResolveAccountAndAttempt(app, re.Auth.Id, input.Harness, input.Provider, input.AccountID, input.AttemptID)
		if err != nil {
			return re.BadRequestError(err.Error(), nil)
		}
		if account.GetString("owner") != re.Auth.Id {
			return re.ForbiddenError("Only the account owner can manage harness authentication", nil)
		}
		if attempt == nil {
			return re.NotFoundError("No active auth attempt found", nil)
		}
		authenticatorKey, err := harnessauth.ResolveAuthenticatorKey(app, account)
		if err != nil {
			return re.BadRequestError(err.Error(), nil)
		}
		stateCtx, err := harnessauth.BuildAttemptContext(app, attempt, re.Auth.Id)
		if err != nil {
			return re.InternalServerError(err.Error(), nil)
		}
		state, err := runtime.Cancel(re.Request.Context(), authenticatorKey, stateCtx)
		if err != nil {
			return apis.NewApiError(502, "Auth helper cancel failed", nil)
		}
		if err := harnessauth.UpdateAttempt(app, attempt, state.Status, state.LastError); err != nil {
			return re.InternalServerError("Unable to update auth attempt", nil)
		}
		account.Set("status", harnessauth.StatusForAttempt(state.Status))
		account.Set("last_error", state.LastError)
		if saveErr := app.Save(account); saveErr != nil {
			log.Printf("[HarnessAuth] save account: %v", saveErr)
		}
		return re.JSON(200, renderHarnessAuthStatus(account, attempt, "oauth"))
	}})

	registry.Add(operation.Route{OperationID: "disconnectHarnessAuth", Method: http.MethodPost, Path: "/api/pocketcoder/v1/harness-auth/disconnect", Auth: true, Action: func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.UnauthorizedError("Authentication required", nil)
		}
		var input harnessAuthRequest
		if err := re.BindBody(&input); err != nil {
			return re.BadRequestError("Invalid request body", nil)
		}
		if input.Harness == "" || input.Provider == "" {
			return re.BadRequestError("harness and provider are required", nil)
		}
		account, err := harnessaccount.Resolve(app, re.Auth.Id, input.Harness, input.Provider, input.AccountID)
		if err != nil {
			log.Printf("[HarnessAuth] resolve account: %v", err)
			return re.InternalServerError("Internal error", nil)
		}
		if account == nil {
			return re.NotFoundError("Account not found", nil)
		}
		if account.GetString("owner") != re.Auth.Id {
			return re.ForbiddenError("Only the account owner can disconnect harness credentials", nil)
		}
		attempt, err := harnessauth.LatestAttempt(app, account.Id)
		if err != nil {
			return re.InternalServerError("Internal error", nil)
		}
		if attempt != nil {
			authenticatorKey, keyErr := harnessauth.ResolveAuthenticatorKey(app, account)
			if keyErr == nil {
				stateCtx, ctxErr := harnessauth.BuildAttemptContext(app, attempt, re.Auth.Id)
				if ctxErr != nil {
					return re.InternalServerError(ctxErr.Error(), nil)
				}
				state, err := runtime.Disconnect(re.Request.Context(), authenticatorKey, stateCtx)
				if err == nil {
					if updateErr := harnessauth.UpdateAttempt(app, attempt, state.Status, state.LastError); updateErr != nil {
						log.Printf("[HarnessAuth] update disconnected auth attempt: %v", updateErr)
					}
				} else {
					log.Printf("[HarnessAuth] disconnect auth helper: %v", err)
				}
			}
		}
		account.Set("status", harnessauth.StatusDisconnected)
		account.Set("last_error", "")
		if err := app.Save(account); err != nil {
			return re.InternalServerError("Unable to save account", nil)
		}
		return re.JSON(200, renderHarnessAuthStatus(account, attempt, "oauth"))
	}})
	return runtime
}

func renderHarnessAuthStatus(account *core.Record, attempt *core.Record, mode string) harnessAuthStatusResp {
	status := account.GetString("status")
	if status == "" {
		status = harnessauth.StatusDisconnected
	}
	response := harnessAuthStatusResp{
		Harness:     account.GetString("harness"),
		Provider:    account.GetString("provider"),
		AccountID:   account.Id,
		AccountName: account.GetString("name"),
		Visibility:  account.GetString("visibility"),
		Mode:        mode,
		Status:      status,
		LastError:   account.GetString("last_error"),
	}
	if attempt != nil {
		response.Attempt = &harnessAuthAttemptResp{ID: attempt.Id, Status: attempt.GetString("status"), LastError: attempt.GetString("last_error")}
	}
	return response
}
