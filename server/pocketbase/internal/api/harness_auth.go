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

// @pocketcoder-core: Harness auth API. Tracks selectable harness accounts and
// auth-helper attempts. No OAuth URLs, tokens, or device codes are persisted.
package api

import (
	"context"
	"errors"
	"log"
	"net/http"
	"strings"

	"github.com/pocketbase/pocketbase/core"

	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/harnessaccount"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/harnessauth"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/operation"
)

type harnessAuthRequest struct {
	Harness        string `json:"harness"`
	AccountID      string `json:"accountId"`
	AccountName    string `json:"accountName"`
	Visibility     string `json:"visibility"`
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
	AccountID      string                    `json:"accountId"`
	AccountName    string                    `json:"accountName"`
	Visibility     string                    `json:"visibility"`
	CredentialMode string                    `json:"credentialMode"`
	Status         string                    `json:"status"`
	LastError      string                    `json:"lastError,omitempty"`
	Attempt        *harnessAuthAttemptResp   `json:"attempt,omitempty"`
	Challenge      *harnessAuthChallengeResp `json:"challenge,omitempty"`
}

type harnessAuthRuntime interface {
	Start(context.Context, string, harnessauth.AttemptContext) (*harnessauth.AttemptState, error)
	Poll(context.Context, string, harnessauth.AttemptContext) (*harnessauth.AttemptState, error)
	Submit(context.Context, string, harnessauth.AttemptContext, string) (*harnessauth.AttemptState, error)
	Cancel(context.Context, string, harnessauth.AttemptContext) (*harnessauth.AttemptState, error)
	Disconnect(context.Context, string, harnessauth.AttemptContext) (*harnessauth.AttemptState, error)
}

type HarnessAuthDeps struct {
	Runtime harnessAuthRuntime
}

func AddHarnessAuthOperations(app core.App, registry *operation.Registry, deps HarnessAuthDeps) {
	runtime := deps.Runtime
	if runtime == nil {
		runtime = harnessauth.NewDefaultRuntime()
	}

	registry.Add(operation.Route{OperationID: "getHarnessAuthStatus", Method: http.MethodPost, Path: "/api/pocketcoder/v1/harness-auth/status", Auth: true, Action: func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return pocketCoderError(re, 401, "Authentication required")
		}
		var input harnessAuthRequest
		if err := re.BindBody(&input); err != nil {
			return pocketCoderError(re, 400, "Invalid request body")
		}
		if input.Harness == "" {
			return pocketCoderError(re, 400, "harness is required")
		}
		if _, err := app.FindRecordById("harnesses", input.Harness); err != nil {
			log.Printf("[HarnessAuth] find harness: %v", err)
			return pocketCoderError(re, 404, "Harness not found")
		}
		account, err := harnessaccount.Resolve(app, re.Auth.Id, input.Harness, input.AccountID)
		if err != nil {
			log.Printf("[HarnessAuth] resolve account: %v", err)
			return pocketCoderError(re, 500, "Internal error")
		}
		if account == nil {
			return re.JSON(200, harnessAuthStatusResp{
				Harness:        input.Harness,
				Status:         harnessauth.StatusDisconnected,
				CredentialMode: harnessauth.ModeNone,
			})
		}
		attempt, _ := harnessauth.ActiveAttempt(app, account.Id)
		return re.JSON(200, renderHarnessAuthStatus(app, account, attempt))
	}})

	registry.Add(operation.Route{OperationID: "startHarnessAuth", Method: http.MethodPost, Path: "/api/pocketcoder/v1/harness-auth/start", Auth: true, Action: func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return pocketCoderError(re, 401, "Authentication required")
		}
		var input harnessAuthRequest
		if err := re.BindBody(&input); err != nil {
			return pocketCoderError(re, 400, "Invalid request body")
		}
		if input.Harness == "" {
			return pocketCoderError(re, 400, "harness is required")
		}
		if _, err := app.FindRecordById("harnesses", input.Harness); err != nil {
			log.Printf("[HarnessAuth] find harness: %v", err)
			return pocketCoderError(re, 404, "Harness not found")
		}
		mode := strings.TrimSpace(input.CredentialMode)
		if mode == "" {
			mode = harnessauth.ModeAccount
		}
		if mode != harnessauth.ModeAccount && mode != harnessauth.ModeAPIKey && mode != harnessauth.ModeNone {
			return pocketCoderError(re, 400, "credentialMode must be one of account|api_key|none")
		}

		visibility := strings.TrimSpace(input.Visibility)
		if visibility == "" {
			visibility = harnessaccount.VisibilityPersonal
		}
		account, err := harnessaccount.SelectOrCreate(app, re.Auth.Id, input.Harness, input.AccountID, input.AccountName, visibility, mode)
		if err != nil {
			log.Printf("[HarnessAuth] select or create account: %v", err)
			return pocketCoderError(re, 500, "Internal error")
		}
		if account.GetString("owner") != re.Auth.Id {
			return pocketCoderError(re, 403, "Only the account owner can change harness credentials")
		}

		switch mode {
		case harnessauth.ModeNone:
			account.Set("credential_mode", harnessauth.ModeNone)
			account.Set("status", harnessauth.StatusDisconnected)
			account.Set("last_error", "")
			if err := app.Save(account); err != nil {
				log.Printf("[HarnessAuth] save account: %v", err)
				return pocketCoderError(re, 500, "Unable to save account")
			}
			return re.JSON(200, renderHarnessAuthStatus(app, account, nil))

		case harnessauth.ModeAPIKey:
			if input.ProviderKey != "" {
				if err := harnessauth.BindProviderKey(app, account, input.ProviderKey, re.Auth.Id); err != nil {
					return pocketCoderError(re, 400, err.Error())
				}
			}
			account.Set("credential_mode", harnessauth.ModeAPIKey)
			if pk := account.GetString("provider_key"); pk == "" {
				account.Set("status", harnessauth.StatusNeedsAPIKey)
			} else {
				account.Set("status", harnessauth.StatusConnected)
				account.Set("last_error", "")
			}
			if err := app.Save(account); err != nil {
				log.Printf("[HarnessAuth] save account: %v", err)
				return pocketCoderError(re, 500, "Unable to save account")
			}
			return re.JSON(200, renderHarnessAuthStatus(app, account, nil))

		case harnessauth.ModeAccount:
			provider := strings.TrimSpace(strings.ToLower(input.Provider))
			if provider == "" {
				return pocketCoderError(re, 400, "provider is required for account mode")
			}
			attempt, err := harnessauth.CreateAttempt(app, account.Id, provider)
			if err != nil {
				log.Printf("[HarnessAuth] create auth attempt: %v", err)
				account.Set("status", harnessauth.StatusError)
				account.Set("last_error", "Unable to create auth attempt")
				if saveErr := app.Save(account); saveErr != nil {
					log.Printf("[HarnessAuth] save account after create attempt failure: %v", saveErr)
				}
				return pocketCoderError(re, 500, "Unable to create auth attempt")
			}
			stateCtx, err := harnessauth.BuildAttemptContext(app, attempt, re.Auth.Id)
			if err != nil {
				log.Printf("[HarnessAuth] build attempt context: %v", err)
				account.Set("status", harnessauth.StatusError)
				account.Set("last_error", err.Error())
				if saveErr := app.Save(account); saveErr != nil {
					log.Printf("[HarnessAuth] save account after context failure: %v", saveErr)
				}
				return pocketCoderError(re, 500, err.Error())
			}
			state, err := runtime.Start(re.Request.Context(), provider, stateCtx)
			if err != nil {
				log.Printf("[HarnessAuth] start auth helper: %v", err)
				if updateErr := harnessauth.UpdateAttempt(app, attempt, harnessauth.AttemptStatusFailed, "Unable to initialize authenticator"); updateErr != nil {
					log.Printf("[HarnessAuth] update failed auth attempt: %v", updateErr)
				}
				account.Set("status", harnessauth.StatusError)
				account.Set("last_error", "Unable to initialize authenticator")
				if saveErr := app.Save(account); saveErr != nil {
					log.Printf("[HarnessAuth] save account after start failure: %v", saveErr)
				}
				return pocketCoderError(re, 502, "Unable to start auth helper")
			}
			if err := harnessauth.UpdateAttempt(app, attempt, state.Status, ""); err != nil {
				log.Printf("[HarnessAuth] update auth attempt: %v", err)
				return pocketCoderError(re, 500, "Unable to update auth attempt")
			}
			account.Set("credential_mode", harnessauth.ModeAccount)
			account.Set("status", harnessauth.StatusForAttempt(state.Status))
			account.Set("last_error", "")
			if err := app.Save(account); err != nil {
				log.Printf("[HarnessAuth] save account: %v", err)
				return pocketCoderError(re, 500, "Unable to save account")
			}
			response := renderHarnessAuthStatus(app, account, attempt)
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
	}})

	registry.Add(operation.Route{OperationID: "pollHarnessAuth", Method: http.MethodPost, Path: "/api/pocketcoder/v1/harness-auth/poll", Auth: true, Action: func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return pocketCoderError(re, 401, "Authentication required")
		}
		var input harnessAuthRequest
		if err := re.BindBody(&input); err != nil {
			return pocketCoderError(re, 400, "Invalid request body")
		}
		account, attempt, err := harnessauth.ResolveAccountAndAttempt(app, re.Auth.Id, input.Harness, input.AccountID, input.AttemptID)
		if err != nil {
			log.Printf("[HarnessAuth] resolve account and attempt: %v", err)
			return pocketCoderError(re, 400, err.Error())
		}
		if account.GetString("owner") != re.Auth.Id {
			return pocketCoderError(re, 403, "Only the account owner can manage harness authentication")
		}
		if attempt == nil {
			return pocketCoderError(re, 404, "No active auth attempt found")
		}

		stateCtx, err := harnessauth.BuildAttemptContext(app, attempt, re.Auth.Id)
		if err != nil {
			log.Printf("[HarnessAuth] build attempt context: %v", err)
			return pocketCoderError(re, 500, err.Error())
		}
		state, err := runtime.Poll(re.Request.Context(), attempt.GetString("provider"), stateCtx)
		if err != nil {
			if errors.Is(err, harnessauth.ErrAttemptExpired) {
				log.Printf("[HarnessAuth] poll auth helper: %v", err)
				attemptStatus := harnessauth.AttemptStatusFailed
				if updateErr := harnessauth.UpdateAttempt(app, attempt, attemptStatus, "Auth attempt expired"); updateErr != nil {
					log.Printf("[HarnessAuth] update expired auth attempt: %v", updateErr)
				}
				account.Set("status", harnessauth.StatusError)
				account.Set("last_error", "Auth attempt expired")
				if saveErr := app.Save(account); saveErr != nil {
					log.Printf("[HarnessAuth] save account: %v", saveErr)
				}
				return pocketCoderError(re, 410, "Auth attempt expired")
			}
			log.Printf("[HarnessAuth] poll auth helper: %v", err)
			return pocketCoderError(re, 502, "Auth helper poll failed")
		}
		if err := harnessauth.UpdateAttempt(app, attempt, state.Status, state.LastError); err != nil {
			log.Printf("[HarnessAuth] update auth attempt: %v", err)
			return pocketCoderError(re, 500, "Unable to update auth attempt")
		}
		account.Set("status", harnessauth.StatusForAttempt(state.Status))
		account.Set("last_error", state.LastError)
		if saveErr := app.Save(account); saveErr != nil {
			log.Printf("[HarnessAuth] save account: %v", saveErr)
		}
		response := renderHarnessAuthStatus(app, account, attempt)
		if state.Challenge != nil {
			response.Challenge = &harnessAuthChallengeResp{
				Type:    state.Challenge.Type,
				Text:    state.Challenge.Text,
				Target:  state.Challenge.Target,
				Details: state.Challenge.Details,
			}
		}
		return re.JSON(200, response)
	}})

	registry.Add(operation.Route{OperationID: "submitHarnessAuth", Method: http.MethodPost, Path: "/api/pocketcoder/v1/harness-auth/submit", Auth: true, Action: func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return pocketCoderError(re, 401, "Authentication required")
		}
		var input harnessAuthRequest
		if err := re.BindBody(&input); err != nil {
			return pocketCoderError(re, 400, "Invalid request body")
		}
		account, attempt, err := harnessauth.ResolveAccountAndAttempt(app, re.Auth.Id, input.Harness, input.AccountID, input.AttemptID)
		if err != nil {
			log.Printf("[HarnessAuth] resolve account and attempt: %v", err)
			return pocketCoderError(re, 400, err.Error())
		}
		if account.GetString("owner") != re.Auth.Id {
			return pocketCoderError(re, 403, "Only the account owner can manage harness authentication")
		}
		if attempt == nil {
			return pocketCoderError(re, 404, "No active auth attempt found")
		}
		code := strings.TrimSpace(input.Code)
		if code == "" {
			return pocketCoderError(re, 400, "code is required")
		}
		stateCtx, err := harnessauth.BuildAttemptContext(app, attempt, re.Auth.Id)
		if err != nil {
			log.Printf("[HarnessAuth] build attempt context: %v", err)
			return pocketCoderError(re, 500, err.Error())
		}
		state, err := runtime.Submit(re.Request.Context(), attempt.GetString("provider"), stateCtx, code)
		if err != nil {
			log.Printf("[HarnessAuth] submit auth helper: %v", err)
			account.Set("status", harnessauth.StatusError)
			account.Set("last_error", err.Error())
			if saveErr := app.Save(account); saveErr != nil {
				log.Printf("[HarnessAuth] save account: %v", saveErr)
			}
			return pocketCoderError(re, 502, err.Error())
		}
		if err := harnessauth.UpdateAttempt(app, attempt, state.Status, state.LastError); err != nil {
			log.Printf("[HarnessAuth] update auth attempt: %v", err)
			return pocketCoderError(re, 500, "Unable to update auth attempt")
		}
		account.Set("status", harnessauth.StatusForAttempt(state.Status))
		account.Set("last_error", state.LastError)
		if saveErr := app.Save(account); saveErr != nil {
			log.Printf("[HarnessAuth] save account: %v", saveErr)
		}
		return re.JSON(200, renderHarnessAuthStatus(app, account, attempt))
	}})

	registry.Add(operation.Route{OperationID: "cancelHarnessAuth", Method: http.MethodPost, Path: "/api/pocketcoder/v1/harness-auth/cancel", Auth: true, Action: func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return pocketCoderError(re, 401, "Authentication required")
		}
		var input harnessAuthRequest
		if err := re.BindBody(&input); err != nil {
			return pocketCoderError(re, 400, "Invalid request body")
		}
		account, attempt, err := harnessauth.ResolveAccountAndAttempt(app, re.Auth.Id, input.Harness, input.AccountID, input.AttemptID)
		if err != nil {
			log.Printf("[HarnessAuth] resolve account and attempt: %v", err)
			return pocketCoderError(re, 400, err.Error())
		}
		if account.GetString("owner") != re.Auth.Id {
			return pocketCoderError(re, 403, "Only the account owner can manage harness authentication")
		}
		if attempt == nil {
			return pocketCoderError(re, 404, "No active auth attempt found")
		}
		stateCtx, err := harnessauth.BuildAttemptContext(app, attempt, re.Auth.Id)
		if err != nil {
			log.Printf("[HarnessAuth] build attempt context: %v", err)
			return pocketCoderError(re, 500, err.Error())
		}
		state, err := runtime.Cancel(re.Request.Context(), attempt.GetString("provider"), stateCtx)
		if err != nil {
			log.Printf("[HarnessAuth] cancel auth helper: %v", err)
			return pocketCoderError(re, 502, "Auth helper cancel failed")
		}
		if err := harnessauth.UpdateAttempt(app, attempt, state.Status, state.LastError); err != nil {
			log.Printf("[HarnessAuth] update auth attempt: %v", err)
			return pocketCoderError(re, 500, "Unable to update auth attempt")
		}
		account.Set("status", harnessauth.StatusForAttempt(state.Status))
		account.Set("last_error", state.LastError)
		if saveErr := app.Save(account); saveErr != nil {
			log.Printf("[HarnessAuth] save account: %v", saveErr)
		}
		return re.JSON(200, renderHarnessAuthStatus(app, account, attempt))
	}})

	registry.Add(operation.Route{OperationID: "disconnectHarnessAuth", Method: http.MethodPost, Path: "/api/pocketcoder/v1/harness-auth/disconnect", Auth: true, Action: func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return pocketCoderError(re, 401, "Authentication required")
		}
		var input harnessAuthRequest
		if err := re.BindBody(&input); err != nil {
			return pocketCoderError(re, 400, "Invalid request body")
		}
		if input.Harness == "" {
			return pocketCoderError(re, 400, "harness is required")
		}
		account, err := harnessaccount.Resolve(app, re.Auth.Id, input.Harness, input.AccountID)
		if err != nil {
			log.Printf("[HarnessAuth] resolve account: %v", err)
			return pocketCoderError(re, 500, "Internal error")
		}
		if account == nil {
			return pocketCoderError(re, 404, "Account not found")
		}
		if account.GetString("owner") != re.Auth.Id {
			return pocketCoderError(re, 403, "Only the account owner can disconnect harness credentials")
		}
		attempt, err := harnessauth.LatestAttempt(app, account.Id)
		if err != nil {
			log.Printf("[HarnessAuth] latest auth attempt: %v", err)
			return pocketCoderError(re, 500, "Internal error")
		}
		if attempt != nil {
			stateCtx, ctxErr := harnessauth.BuildAttemptContext(app, attempt, re.Auth.Id)
			if ctxErr != nil {
				log.Printf("[HarnessAuth] build attempt context: %v", ctxErr)
				return pocketCoderError(re, 500, ctxErr.Error())
			}
			state, err := runtime.Disconnect(re.Request.Context(), attempt.GetString("provider"), stateCtx)
			if err == nil {
				if updateErr := harnessauth.UpdateAttempt(app, attempt, state.Status, state.LastError); updateErr != nil {
					log.Printf("[HarnessAuth] update disconnected auth attempt: %v", updateErr)
				}
			} else {
				log.Printf("[HarnessAuth] disconnect auth helper: %v", err)
			}
		}
		account.Set("status", harnessauth.StatusDisconnected)
		account.Set("last_error", "")
		if err := app.Save(account); err != nil {
			log.Printf("[HarnessAuth] save account: %v", err)
			return pocketCoderError(re, 500, "Unable to save account")
		}
		return re.JSON(200, renderHarnessAuthStatus(app, account, attempt))
	}})
}

func renderHarnessAuthStatus(app core.App, account *core.Record, attempt *core.Record) harnessAuthStatusResp {
	status := account.GetString("status")
	if status == "" {
		status = harnessauth.StatusDisconnected
	}
	response := harnessAuthStatusResp{
		Harness:        account.GetString("harness"),
		AccountID:      account.Id,
		AccountName:    account.GetString("name"),
		Visibility:     account.GetString("visibility"),
		CredentialMode: account.GetString("credential_mode"),
		Status:         status,
		LastError:      account.GetString("last_error"),
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
