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

// @pocketcoder-core: Harness auth API. Tracks scoped auth mode and auth-helper
// attempt lifecycle for user-owned harness bindings. No OAuth URLs, tokens,
// or device codes are persisted in PocketBase.
package api

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"

	"github.com/qtpi-automaton/pocketcoder/backend/internal/harnessauth"
)

const (
	harnessAuthModeAccount = "account"
	harnessAuthModeAPIKey  = "api_key"
	harnessAuthModeNone    = "none"

	bindingStatusDisconnected = "disconnected"
	bindingStatusConnecting   = "connecting"
	bindingStatusConnected    = "connected"
	bindingStatusError        = "error"
	bindingStatusNeedsAPIKey  = "needs_api_key"

	scopeKindUser = "user"
)

type harnessAuthRequest struct {
	Harness        string `json:"harness"`
	ScopeKind      string `json:"scopeKind"`
	ScopeID        string `json:"scopeId"`
	CredentialMode string `json:"credentialMode"`
	Provider       string `json:"provider"`
	ProviderKey    string `json:"providerKey"`
	AttemptID      string `json:"attemptId"`
	Code           string `json:"code"`
}

type harnessAuthChallengeResp struct {
	Type    string `json:"type"`
	Text    string `json:"text"`
	Target  string `json:"target,omitempty"`
	Details string `json:"details,omitempty"`
}

type harnessAuthAttemptResp struct {
	ID        string `json:"id"`
	Provider  string `json:"provider"`
	Status    string `json:"status"`
	LastError string `json:"lastError,omitempty"`
}

type harnessAuthStatusResp struct {
	Harness        string                    `json:"harness"`
	ScopeKind      string                    `json:"scopeKind"`
	ScopeID        string                    `json:"scopeId"`
	BindingID      string                    `json:"bindingId"`
	CredentialMode string                    `json:"credentialMode"`
	Status         string                    `json:"status"`
	LastError      string                    `json:"lastError,omitempty"`
	Attempt        *harnessAuthAttemptResp   `json:"attempt,omitempty"`
	Challenge      *harnessAuthChallengeResp `json:"challenge,omitempty"`
}

// RegisterHarnessAuthApi registers the auth lifecycle routes for per-user
// harness credential orchestration.
func RegisterHarnessAuthApi(app *pocketbase.PocketBase, e *core.ServeEvent) {
	runtime := harnessauth.NewDefaultRuntime()

	e.Router.POST("/api/pocketcoder/harness_auth/status", func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(401, map[string]string{"error": "Authentication required"})
		}
		var input harnessAuthRequest
		if err := re.BindBody(&input); err != nil {
			return re.JSON(400, map[string]string{"error": "Invalid request body"})
		}
		scopeKind, scopeID, err := resolveHarnessAuthScope(re, input.ScopeKind, input.ScopeID)
		if err != nil {
			return re.JSON(403, map[string]string{"error": err.Error()})
		}
		if input.Harness == "" {
			return re.JSON(400, map[string]string{"error": "harness is required"})
		}
		if _, err := app.FindRecordById("harnesses", input.Harness); err != nil {
			return re.JSON(404, map[string]string{"error": "Harness not found"})
		}
		binding, err := findHarnessAuthBinding(app, scopeKind, scopeID, input.Harness)
		if err != nil {
			return re.JSON(500, map[string]string{"error": "Internal error"})
		}
		if binding == nil {
			return re.JSON(200, harnessAuthStatusResp{
				Harness:        input.Harness,
				ScopeKind:      scopeKind,
				ScopeID:        scopeID,
				Status:         bindingStatusDisconnected,
				CredentialMode: harnessAuthModeNone,
			})
		}
		attempt, _ := activeHarnessAuthAttempt(app, binding.Id)
		return re.JSON(200, renderHarnessAuthStatus(app, binding, attempt, scopeKind, scopeID))
	}).Bind(apis.RequireAuth())

	e.Router.POST("/api/pocketcoder/harness_auth/start", func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(401, map[string]string{"error": "Authentication required"})
		}
		var input harnessAuthRequest
		if err := re.BindBody(&input); err != nil {
			return re.JSON(400, map[string]string{"error": "Invalid request body"})
		}
		scopeKind, scopeID, err := resolveHarnessAuthScope(re, input.ScopeKind, input.ScopeID)
		if err != nil {
			return re.JSON(403, map[string]string{"error": err.Error()})
		}
		if input.Harness == "" {
			return re.JSON(400, map[string]string{"error": "harness is required"})
		}
		if _, err := app.FindRecordById("harnesses", input.Harness); err != nil {
			return re.JSON(404, map[string]string{"error": "Harness not found"})
		}
		mode := strings.TrimSpace(input.CredentialMode)
		if mode == "" {
			mode = harnessAuthModeAccount
		}
		if mode != harnessAuthModeAccount && mode != harnessAuthModeAPIKey && mode != harnessAuthModeNone {
			return re.JSON(400, map[string]string{"error": "credentialMode must be one of account|api_key|none"})
		}

		binding, err := getOrCreateHarnessAuthBinding(app, scopeKind, scopeID, input.Harness, mode)
		if err != nil {
			return re.JSON(500, map[string]string{"error": "Internal error"})
		}

		switch mode {
		case harnessAuthModeNone:
			binding.Set("credential_mode", harnessAuthModeNone)
			binding.Set("status", bindingStatusDisconnected)
			binding.Set("last_error", "")
			if err := app.Save(binding); err != nil {
				return re.JSON(500, map[string]string{"error": "Unable to save binding"})
			}
			return re.JSON(200, renderHarnessAuthStatus(app, binding, nil, scopeKind, scopeID))

		case harnessAuthModeAPIKey:
			if input.ProviderKey != "" {
				if err := bindProviderKey(app, binding, input.ProviderKey, scopeID); err != nil {
					return re.JSON(400, map[string]string{"error": err.Error()})
				}
			}
			binding.Set("credential_mode", harnessAuthModeAPIKey)
			if pk := binding.GetString("provider_key"); pk == "" {
				binding.Set("status", bindingStatusNeedsAPIKey)
			} else {
				binding.Set("status", bindingStatusConnected)
				binding.Set("last_error", "")
			}
			if err := app.Save(binding); err != nil {
				return re.JSON(500, map[string]string{"error": "Unable to save binding"})
			}
			return re.JSON(200, renderHarnessAuthStatus(app, binding, nil, scopeKind, scopeID))

		case harnessAuthModeAccount:
			provider := strings.TrimSpace(strings.ToLower(input.Provider))
			if provider == "" {
				return re.JSON(400, map[string]string{"error": "provider is required for account mode"})
			}
			attempt, err := createHarnessAuthAttempt(app, scopeKind, scopeID, input.Harness, binding.Id, provider)
			if err != nil {
				binding.Set("status", bindingStatusError)
				binding.Set("last_error", "Unable to create auth attempt")
				_ = app.Save(binding)
				return re.JSON(500, map[string]string{"error": "Unable to create auth attempt"})
			}
			state, err := runtime.Start(context.Background(), provider, attempt.Id)
			if err != nil {
				_ = updateHarnessAuthAttempt(app, attempt, harnessauth.AttemptStatusFailed, "Unable to initialize authenticator")
				binding.Set("status", bindingStatusError)
				binding.Set("last_error", "Unable to initialize authenticator")
				_ = app.Save(binding)
				return re.JSON(502, map[string]string{"error": "Unable to start auth helper"})
			}
			if err := updateHarnessAuthAttempt(app, attempt, state.Status, ""); err != nil {
				return re.JSON(500, map[string]string{"error": "Unable to update auth attempt"})
			}
			binding.Set("credential_mode", harnessAuthModeAccount)
			binding.Set("status", statusForAttempt(state.Status))
			binding.Set("last_error", "")
			if err := app.Save(binding); err != nil {
				return re.JSON(500, map[string]string{"error": "Unable to save binding"})
			}
			response := renderHarnessAuthStatus(app, binding, attempt, scopeKind, scopeID)
			if state.Challenge != nil {
				response.Challenge = &harnessAuthChallengeResp{
					Type:    state.Challenge.Type,
					Text:    state.Challenge.Text,
					Target:  state.Challenge.Target,
					Details: state.Challenge.Details,
				}
			}
			return re.JSON(200, response)
		}

		return re.NoContent(500)
	}).Bind(apis.RequireAuth())

	e.Router.POST("/api/pocketcoder/harness_auth/poll", func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(401, map[string]string{"error": "Authentication required"})
		}
		var input harnessAuthRequest
		if err := re.BindBody(&input); err != nil {
			return re.JSON(400, map[string]string{"error": "Invalid request body"})
		}
		scopeKind, scopeID, err := resolveHarnessAuthScope(re, input.ScopeKind, input.ScopeID)
		if err != nil {
			return re.JSON(403, map[string]string{"error": err.Error()})
		}
		binding, attempt, err := authBindingAndAttemptForRequest(app, scopeKind, scopeID, input)
		if err != nil {
			return re.JSON(400, map[string]string{"error": err.Error()})
		}
		if attempt == nil {
			return re.JSON(404, map[string]string{"error": "No active auth attempt found"})
		}

		state, err := runtime.Poll(context.Background(), attempt.GetString("provider"), attempt.Id)
		if err != nil {
			if errors.Is(err, harnessauth.ErrAttemptExpired) {
				attemptStatus := harnessauth.AttemptStatusFailed
				_ = updateHarnessAuthAttempt(app, attempt, attemptStatus, "Auth attempt expired")
				binding.Set("status", bindingStatusError)
				binding.Set("last_error", "Auth attempt expired")
				_ = app.Save(binding)
				return re.JSON(410, map[string]string{"error": "Auth attempt expired"})
			}
			return re.JSON(502, map[string]string{"error": "Auth helper poll failed"})
		}
		if err := updateHarnessAuthAttempt(app, attempt, state.Status, state.LastError); err != nil {
			return re.JSON(500, map[string]string{"error": "Unable to update auth attempt"})
		}
		binding.Set("status", statusForAttempt(state.Status))
		binding.Set("last_error", state.LastError)
		_ = app.Save(binding)
		response := renderHarnessAuthStatus(app, binding, attempt, scopeKind, scopeID)
		return re.JSON(200, response)
	}).Bind(apis.RequireAuth())

	e.Router.POST("/api/pocketcoder/harness_auth/submit", func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(401, map[string]string{"error": "Authentication required"})
		}
		var input harnessAuthRequest
		if err := re.BindBody(&input); err != nil {
			return re.JSON(400, map[string]string{"error": "Invalid request body"})
		}
		scopeKind, scopeID, err := resolveHarnessAuthScope(re, input.ScopeKind, input.ScopeID)
		if err != nil {
			return re.JSON(403, map[string]string{"error": err.Error()})
		}
		binding, attempt, err := authBindingAndAttemptForRequest(app, scopeKind, scopeID, input)
		if err != nil {
			return re.JSON(400, map[string]string{"error": err.Error()})
		}
		if attempt == nil {
			return re.JSON(404, map[string]string{"error": "No active auth attempt found"})
		}
		code := strings.TrimSpace(input.Code)
		if code == "" {
			return re.JSON(400, map[string]string{"error": "code is required"})
		}
		state, err := runtime.Submit(context.Background(), attempt.GetString("provider"), attempt.Id, code)
		if err != nil {
			binding.Set("status", bindingStatusError)
			binding.Set("last_error", err.Error())
			_ = app.Save(binding)
			return re.JSON(502, map[string]string{"error": err.Error()})
		}
		if err := updateHarnessAuthAttempt(app, attempt, state.Status, state.LastError); err != nil {
			return re.JSON(500, map[string]string{"error": "Unable to update auth attempt"})
		}
		binding.Set("status", statusForAttempt(state.Status))
		binding.Set("last_error", state.LastError)
		_ = app.Save(binding)
		return re.JSON(200, renderHarnessAuthStatus(app, binding, attempt, scopeKind, scopeID))
	}).Bind(apis.RequireAuth())

	e.Router.POST("/api/pocketcoder/harness_auth/cancel", func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(401, map[string]string{"error": "Authentication required"})
		}
		var input harnessAuthRequest
		if err := re.BindBody(&input); err != nil {
			return re.JSON(400, map[string]string{"error": "Invalid request body"})
		}
		scopeKind, scopeID, err := resolveHarnessAuthScope(re, input.ScopeKind, input.ScopeID)
		if err != nil {
			return re.JSON(403, map[string]string{"error": err.Error()})
		}
		binding, attempt, err := authBindingAndAttemptForRequest(app, scopeKind, scopeID, input)
		if err != nil {
			return re.JSON(400, map[string]string{"error": err.Error()})
		}
		if attempt == nil {
			return re.JSON(404, map[string]string{"error": "No active auth attempt found"})
		}
		state, err := runtime.Cancel(context.Background(), attempt.GetString("provider"), attempt.Id)
		if err != nil {
			return re.JSON(502, map[string]string{"error": "Auth helper cancel failed"})
		}
		if err := updateHarnessAuthAttempt(app, attempt, state.Status, state.LastError); err != nil {
			return re.JSON(500, map[string]string{"error": "Unable to update auth attempt"})
		}
		binding.Set("status", statusForAttempt(state.Status))
		binding.Set("last_error", state.LastError)
		_ = app.Save(binding)
		return re.JSON(200, renderHarnessAuthStatus(app, binding, attempt, scopeKind, scopeID))
	}).Bind(apis.RequireAuth())

	e.Router.POST("/api/pocketcoder/harness_auth/disconnect", func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(401, map[string]string{"error": "Authentication required"})
		}
		var input harnessAuthRequest
		if err := re.BindBody(&input); err != nil {
			return re.JSON(400, map[string]string{"error": "Invalid request body"})
		}
		scopeKind, scopeID, err := resolveHarnessAuthScope(re, input.ScopeKind, input.ScopeID)
		if err != nil {
			return re.JSON(403, map[string]string{"error": err.Error()})
		}
		if input.Harness == "" {
			return re.JSON(400, map[string]string{"error": "harness is required"})
		}
		binding, err := findHarnessAuthBinding(app, scopeKind, scopeID, input.Harness)
		if err != nil {
			return re.JSON(500, map[string]string{"error": "Internal error"})
		}
		if binding == nil {
			return re.JSON(404, map[string]string{"error": "Binding not found"})
		}
		attempt, err := latestHarnessAuthAttempt(app, binding.Id)
		if err != nil {
			return re.JSON(500, map[string]string{"error": "Internal error"})
		}
		if attempt != nil {
			state, err := runtime.Disconnect(context.Background(), attempt.GetString("provider"), attempt.Id)
			if err == nil {
				_ = updateHarnessAuthAttempt(app, attempt, state.Status, state.LastError)
			}
		}
		binding.Set("status", bindingStatusDisconnected)
		binding.Set("last_error", "")
		if err := app.Save(binding); err != nil {
			return re.JSON(500, map[string]string{"error": "Unable to save binding"})
		}
		return re.JSON(200, renderHarnessAuthStatus(app, binding, attempt, scopeKind, scopeID))
	}).Bind(apis.RequireAuth())
}

func resolveHarnessAuthScope(re *core.RequestEvent, scopeKind, scopeID string) (resolvedKind, resolvedID string, err error) {
	if scopeKind == "" {
		scopeKind = scopeKindUser
	}
	switch scopeKind {
	case scopeKindUser:
		if scopeID == "" {
			return scopeKind, re.Auth.Id, nil
		}
		if scopeID != re.Auth.Id {
			return "", "", fmt.Errorf("scopeId mismatch")
		}
		return scopeKind, scopeID, nil
	default:
		return "", "", fmt.Errorf("unsupported scopeKind %q", scopeKind)
	}
}

func findHarnessAuthBinding(app core.App, scopeKind, scopeID, harnessID string) (*core.Record, error) {
	recs, err := app.FindRecordsByFilter(
		"harness_auth_bindings",
		"scope_kind = {:kind} && scope_id = {:scope} && harness = {:harness}",
		"-created",
		1,
		0,
		map[string]any{
			"kind":    scopeKind,
			"scope":   scopeID,
			"harness": harnessID,
		},
	)
	if err != nil {
		return nil, err
	}
	if len(recs) == 0 {
		return nil, nil
	}
	return recs[0], nil
}

func getOrCreateHarnessAuthBinding(app core.App, scopeKind, scopeID, harnessID, credentialMode string) (*core.Record, error) {
	binding, err := findHarnessAuthBinding(app, scopeKind, scopeID, harnessID)
	if err != nil {
		return nil, err
	}
	if binding != nil {
		return binding, nil
	}
	col, err := app.FindCollectionByNameOrId("harness_auth_bindings")
	if err != nil {
		return nil, err
	}
	rec := core.NewRecord(col)
	rec.Set("scope_kind", scopeKind)
	rec.Set("scope_id", scopeID)
	rec.Set("harness", harnessID)
	rec.Set("credential_mode", credentialMode)
	rec.Set("status", bindingStatusDisconnected)
	return rec, nil
}

func bindProviderKey(app core.App, binding *core.Record, providerKeyID, scopeID string) error {
	pk, err := app.FindRecordById("provider_keys", providerKeyID)
	if err != nil {
		return fmt.Errorf("providerKey not found")
	}
	if pk.GetString("user") != scopeID {
		return fmt.Errorf("providerKey does not belong to this scope")
	}
	binding.Set("provider_key", providerKeyID)
	return nil
}

func createHarnessAuthAttempt(app core.App, scopeKind, scopeID, harnessID, bindingID, provider string) (*core.Record, error) {
	col, err := app.FindCollectionByNameOrId("harness_auth_attempts")
	if err != nil {
		return nil, err
	}
	rec := core.NewRecord(col)
	rec.Set("scope_kind", scopeKind)
	rec.Set("scope_id", scopeID)
	rec.Set("harness", harnessID)
	rec.Set("binding", bindingID)
	rec.Set("provider", provider)
	rec.Set("status", harnessauth.AttemptStatusStarting)
	rec.Set("expires_at", time.Now().UTC().Add(15*time.Minute))
	return rec, app.Save(rec)
}

func latestHarnessAuthAttempt(app core.App, bindingID string) (*core.Record, error) {
	recs, err := app.FindRecordsByFilter("harness_auth_attempts", "binding = {:binding}", "-created", 1, 0, map[string]any{"binding": bindingID})
	if err != nil {
		return nil, err
	}
	if len(recs) == 0 {
		return nil, nil
	}
	return recs[0], nil
}

func activeHarnessAuthAttempt(app core.App, bindingID string) (*core.Record, error) {
	recs, err := app.FindRecordsByFilter(
		"harness_auth_attempts",
		"binding = {:binding} && (status = 'starting' || status = 'awaiting_input')",
		"-created",
		1,
		0,
		map[string]any{"binding": bindingID},
	)
	if err != nil {
		return nil, err
	}
	if len(recs) == 0 {
		return nil, nil
	}
	return recs[0], nil
}

func authBindingAndAttemptForRequest(app core.App, scopeKind, scopeID string, input harnessAuthRequest) (*core.Record, *core.Record, error) {
	if input.Harness == "" {
		return nil, nil, fmt.Errorf("harness is required")
	}
	binding, err := findHarnessAuthBinding(app, scopeKind, scopeID, input.Harness)
	if err != nil {
		return nil, nil, err
	}
	if binding == nil {
		return nil, nil, fmt.Errorf("binding not found")
	}
	var attempt *core.Record
	if input.AttemptID != "" {
		attempt, err = app.FindRecordById("harness_auth_attempts", input.AttemptID)
		if err != nil {
			return binding, nil, fmt.Errorf("attempt not found")
		}
		if attempt.GetString("binding") != binding.Id {
			return binding, nil, fmt.Errorf("attempt does not belong to this binding")
		}
		return binding, attempt, nil
	}
	attempt, err = activeHarnessAuthAttempt(app, binding.Id)
	if err != nil {
		return binding, nil, err
	}
	return binding, attempt, nil
}

func updateHarnessAuthAttempt(app core.App, attempt *core.Record, status, errorText string) error {
	attempt.Set("status", status)
	if errorText != "" {
		attempt.Set("last_error", errorText)
	} else {
		attempt.Set("last_error", nil)
	}
	if status == harnessauth.AttemptStatusFailed && errorText == "" {
		attempt.Set("last_error", "auth flow failed")
	}
	return app.Save(attempt)
}

func statusForAttempt(attemptStatus string) string {
	switch attemptStatus {
	case harnessauth.AttemptStatusStarting, harnessauth.AttemptStatusAwaiting:
		return bindingStatusConnecting
	case harnessauth.AttemptStatusSucceeded:
		return bindingStatusConnected
	case harnessauth.AttemptStatusCancelled:
		return bindingStatusDisconnected
	case harnessauth.AttemptStatusExpired:
		return bindingStatusError
	case harnessauth.AttemptStatusFailed:
		return bindingStatusError
	default:
		return bindingStatusError
	}
}

func renderHarnessAuthStatus(app core.App, binding *core.Record, attempt *core.Record, scopeKind, scopeID string) harnessAuthStatusResp {
	status := binding.GetString("status")
	if status == "" {
		status = bindingStatusDisconnected
	}
	response := harnessAuthStatusResp{
		Harness:        binding.GetString("harness"),
		ScopeKind:      scopeKind,
		ScopeID:        scopeID,
		BindingID:      binding.Id,
		CredentialMode: binding.GetString("credential_mode"),
		Status:         status,
		LastError:      binding.GetString("last_error"),
	}
	if attempt != nil {
		response.Attempt = &harnessAuthAttemptResp{
			ID:        attempt.Id,
			Provider:  attempt.GetString("provider"),
			Status:    attempt.GetString("status"),
			LastError: attempt.GetString("last_error"),
		}
	}
	return response
}
