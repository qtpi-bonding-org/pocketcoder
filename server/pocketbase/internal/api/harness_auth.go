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
	"fmt"
	"strings"
	"time"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"

	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/harnessaccount"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/harnessauth"
)

const (
	harnessAuthModeAccount = "account"
	harnessAuthModeAPIKey  = "api_key"
	harnessAuthModeNone    = "none"

	accountStatusDisconnected = "disconnected"
	accountStatusConnecting   = "connecting"
	accountStatusConnected    = "connected"
	accountStatusError        = "error"
	accountStatusNeedsAPIKey  = "needs_api_key"
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

// RegisterHarnessAuthApi registers the auth lifecycle routes for deployment or
// personal harness accounts. A deployment account is available to every local
// PocketBase user; a personal account is owner-only.
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
		if input.Harness == "" {
			return re.JSON(400, map[string]string{"error": "harness is required"})
		}
		if _, err := app.FindRecordById("harnesses", input.Harness); err != nil {
			return re.JSON(404, map[string]string{"error": "Harness not found"})
		}
		account, err := harnessaccount.Resolve(app, re.Auth.Id, input.Harness, input.AccountID)
		if err != nil {
			return re.JSON(500, map[string]string{"error": "Internal error"})
		}
		if account == nil {
			return re.JSON(200, harnessAuthStatusResp{
				Harness:        input.Harness,
				Status:         accountStatusDisconnected,
				CredentialMode: harnessAuthModeNone,
			})
		}
		attempt, _ := activeHarnessAuthAttempt(app, account.Id)
		return re.JSON(200, renderHarnessAuthStatus(app, account, attempt))
	}).Bind(apis.RequireAuth())

	e.Router.POST("/api/pocketcoder/harness_auth/start", func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(401, map[string]string{"error": "Authentication required"})
		}
		var input harnessAuthRequest
		if err := re.BindBody(&input); err != nil {
			return re.JSON(400, map[string]string{"error": "Invalid request body"})
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

		visibility := strings.TrimSpace(input.Visibility)
		if visibility == "" {
			visibility = harnessaccount.VisibilityPersonal
		}
		account, err := harnessaccount.SelectOrCreate(app, re.Auth.Id, input.Harness, input.AccountID, input.AccountName, visibility, mode)
		if err != nil {
			return re.JSON(500, map[string]string{"error": "Internal error"})
		}
		if account.GetString("owner") != re.Auth.Id {
			return re.JSON(403, map[string]string{"error": "Only the account owner can change harness credentials"})
		}

		switch mode {
		case harnessAuthModeNone:
			account.Set("credential_mode", harnessAuthModeNone)
			account.Set("status", accountStatusDisconnected)
			account.Set("last_error", "")
			if err := app.Save(account); err != nil {
				return re.JSON(500, map[string]string{"error": "Unable to save account"})
			}
			return re.JSON(200, renderHarnessAuthStatus(app, account, nil))

		case harnessAuthModeAPIKey:
			if input.ProviderKey != "" {
				if err := bindProviderKey(app, account, input.ProviderKey, re.Auth.Id); err != nil {
					return re.JSON(400, map[string]string{"error": err.Error()})
				}
			}
			account.Set("credential_mode", harnessAuthModeAPIKey)
			if pk := account.GetString("provider_key"); pk == "" {
				account.Set("status", accountStatusNeedsAPIKey)
			} else {
				account.Set("status", accountStatusConnected)
				account.Set("last_error", "")
			}
			if err := app.Save(account); err != nil {
				return re.JSON(500, map[string]string{"error": "Unable to save account"})
			}
			return re.JSON(200, renderHarnessAuthStatus(app, account, nil))

		case harnessAuthModeAccount:
			provider := strings.TrimSpace(strings.ToLower(input.Provider))
			if provider == "" {
				return re.JSON(400, map[string]string{"error": "provider is required for account mode"})
			}
			attempt, err := createHarnessAuthAttempt(app, account.Id, provider)
			if err != nil {
				account.Set("status", accountStatusError)
				account.Set("last_error", "Unable to create auth attempt")
				_ = app.Save(account)
				return re.JSON(500, map[string]string{"error": "Unable to create auth attempt"})
			}
			stateCtx, err := runtimeAttemptContext(app, attempt, re.Auth.Id)
			if err != nil {
				account.Set("status", accountStatusError)
				account.Set("last_error", err.Error())
				_ = app.Save(account)
				return re.JSON(500, map[string]string{"error": err.Error()})
			}
			state, err := runtime.Start(context.Background(), provider, stateCtx)
			if err != nil {
				_ = updateHarnessAuthAttempt(app, attempt, harnessauth.AttemptStatusFailed, "Unable to initialize authenticator")
				account.Set("status", accountStatusError)
				account.Set("last_error", "Unable to initialize authenticator")
				_ = app.Save(account)
				return re.JSON(502, map[string]string{"error": "Unable to start auth helper"})
			}
			if err := updateHarnessAuthAttempt(app, attempt, state.Status, ""); err != nil {
				return re.JSON(500, map[string]string{"error": "Unable to update auth attempt"})
			}
			account.Set("credential_mode", harnessAuthModeAccount)
			account.Set("status", statusForAttempt(state.Status))
			account.Set("last_error", "")
			if err := app.Save(account); err != nil {
				return re.JSON(500, map[string]string{"error": "Unable to save account"})
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
	}).Bind(apis.RequireAuth())

	e.Router.POST("/api/pocketcoder/harness_auth/poll", func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(401, map[string]string{"error": "Authentication required"})
		}
		var input harnessAuthRequest
		if err := re.BindBody(&input); err != nil {
			return re.JSON(400, map[string]string{"error": "Invalid request body"})
		}
		account, attempt, err := authAccountAndAttemptForRequest(app, re.Auth.Id, input)
		if err != nil {
			return re.JSON(400, map[string]string{"error": err.Error()})
		}
		if account.GetString("owner") != re.Auth.Id {
			return re.JSON(403, map[string]string{"error": "Only the account owner can manage harness authentication"})
		}
		if attempt == nil {
			return re.JSON(404, map[string]string{"error": "No active auth attempt found"})
		}

		stateCtx, err := runtimeAttemptContext(app, attempt, re.Auth.Id)
		if err != nil {
			return re.JSON(500, map[string]string{"error": err.Error()})
		}
		state, err := runtime.Poll(context.Background(), attempt.GetString("provider"), stateCtx)
		if err != nil {
			if errors.Is(err, harnessauth.ErrAttemptExpired) {
				attemptStatus := harnessauth.AttemptStatusFailed
				_ = updateHarnessAuthAttempt(app, attempt, attemptStatus, "Auth attempt expired")
				account.Set("status", accountStatusError)
				account.Set("last_error", "Auth attempt expired")
				_ = app.Save(account)
				return re.JSON(410, map[string]string{"error": "Auth attempt expired"})
			}
			return re.JSON(502, map[string]string{"error": "Auth helper poll failed"})
		}
		if err := updateHarnessAuthAttempt(app, attempt, state.Status, state.LastError); err != nil {
			return re.JSON(500, map[string]string{"error": "Unable to update auth attempt"})
		}
		account.Set("status", statusForAttempt(state.Status))
		account.Set("last_error", state.LastError)
		_ = app.Save(account)
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
	}).Bind(apis.RequireAuth())

	e.Router.POST("/api/pocketcoder/harness_auth/submit", func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(401, map[string]string{"error": "Authentication required"})
		}
		var input harnessAuthRequest
		if err := re.BindBody(&input); err != nil {
			return re.JSON(400, map[string]string{"error": "Invalid request body"})
		}
		account, attempt, err := authAccountAndAttemptForRequest(app, re.Auth.Id, input)
		if err != nil {
			return re.JSON(400, map[string]string{"error": err.Error()})
		}
		if account.GetString("owner") != re.Auth.Id {
			return re.JSON(403, map[string]string{"error": "Only the account owner can manage harness authentication"})
		}
		if attempt == nil {
			return re.JSON(404, map[string]string{"error": "No active auth attempt found"})
		}
		code := strings.TrimSpace(input.Code)
		if code == "" {
			return re.JSON(400, map[string]string{"error": "code is required"})
		}
		stateCtx, err := runtimeAttemptContext(app, attempt, re.Auth.Id)
		if err != nil {
			return re.JSON(500, map[string]string{"error": err.Error()})
		}
		state, err := runtime.Submit(context.Background(), attempt.GetString("provider"), stateCtx, code)
		if err != nil {
			account.Set("status", accountStatusError)
			account.Set("last_error", err.Error())
			_ = app.Save(account)
			return re.JSON(502, map[string]string{"error": err.Error()})
		}
		if err := updateHarnessAuthAttempt(app, attempt, state.Status, state.LastError); err != nil {
			return re.JSON(500, map[string]string{"error": "Unable to update auth attempt"})
		}
		account.Set("status", statusForAttempt(state.Status))
		account.Set("last_error", state.LastError)
		_ = app.Save(account)
		return re.JSON(200, renderHarnessAuthStatus(app, account, attempt))
	}).Bind(apis.RequireAuth())

	e.Router.POST("/api/pocketcoder/harness_auth/cancel", func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(401, map[string]string{"error": "Authentication required"})
		}
		var input harnessAuthRequest
		if err := re.BindBody(&input); err != nil {
			return re.JSON(400, map[string]string{"error": "Invalid request body"})
		}
		account, attempt, err := authAccountAndAttemptForRequest(app, re.Auth.Id, input)
		if err != nil {
			return re.JSON(400, map[string]string{"error": err.Error()})
		}
		if account.GetString("owner") != re.Auth.Id {
			return re.JSON(403, map[string]string{"error": "Only the account owner can manage harness authentication"})
		}
		if attempt == nil {
			return re.JSON(404, map[string]string{"error": "No active auth attempt found"})
		}
		stateCtx, err := runtimeAttemptContext(app, attempt, re.Auth.Id)
		if err != nil {
			return re.JSON(500, map[string]string{"error": err.Error()})
		}
		state, err := runtime.Cancel(context.Background(), attempt.GetString("provider"), stateCtx)
		if err != nil {
			return re.JSON(502, map[string]string{"error": "Auth helper cancel failed"})
		}
		if err := updateHarnessAuthAttempt(app, attempt, state.Status, state.LastError); err != nil {
			return re.JSON(500, map[string]string{"error": "Unable to update auth attempt"})
		}
		account.Set("status", statusForAttempt(state.Status))
		account.Set("last_error", state.LastError)
		_ = app.Save(account)
		return re.JSON(200, renderHarnessAuthStatus(app, account, attempt))
	}).Bind(apis.RequireAuth())

	e.Router.POST("/api/pocketcoder/harness_auth/disconnect", func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(401, map[string]string{"error": "Authentication required"})
		}
		var input harnessAuthRequest
		if err := re.BindBody(&input); err != nil {
			return re.JSON(400, map[string]string{"error": "Invalid request body"})
		}
		if input.Harness == "" {
			return re.JSON(400, map[string]string{"error": "harness is required"})
		}
		account, err := harnessaccount.Resolve(app, re.Auth.Id, input.Harness, input.AccountID)
		if err != nil {
			return re.JSON(500, map[string]string{"error": "Internal error"})
		}
		if account == nil {
			return re.JSON(404, map[string]string{"error": "Account not found"})
		}
		if account.GetString("owner") != re.Auth.Id {
			return re.JSON(403, map[string]string{"error": "Only the account owner can disconnect harness credentials"})
		}
		attempt, err := latestHarnessAuthAttempt(app, account.Id)
		if err != nil {
			return re.JSON(500, map[string]string{"error": "Internal error"})
		}
		if attempt != nil {
			stateCtx, ctxErr := runtimeAttemptContext(app, attempt, re.Auth.Id)
			if ctxErr != nil {
				return re.JSON(500, map[string]string{"error": ctxErr.Error()})
			}
			state, err := runtime.Disconnect(context.Background(), attempt.GetString("provider"), stateCtx)
			if err == nil {
				_ = updateHarnessAuthAttempt(app, attempt, state.Status, state.LastError)
			}
		}
		account.Set("status", accountStatusDisconnected)
		account.Set("last_error", "")
		if err := app.Save(account); err != nil {
			return re.JSON(500, map[string]string{"error": "Unable to save account"})
		}
		return re.JSON(200, renderHarnessAuthStatus(app, account, attempt))
	}).Bind(apis.RequireAuth())
}

func bindProviderKey(app core.App, account *core.Record, providerKeyID, actorUserID string) error {
	pk, err := app.FindRecordById("provider_keys", providerKeyID)
	if err != nil {
		return fmt.Errorf("providerKey not found")
	}
	if pk.GetString("user") != actorUserID {
		return fmt.Errorf("providerKey does not belong to the authenticated user")
	}
	harness, err := app.FindRecordById("harnesses", account.GetString("harness"))
	if err != nil {
		return fmt.Errorf("harness not found")
	}
	if harness.GetString("provider_scope") != "any" && pk.GetString("provider") != harness.GetString("cli_id") {
		return fmt.Errorf("providerKey does not match this harness")
	}
	account.Set("provider_key", providerKeyID)
	return nil
}

func createHarnessAuthAttempt(app core.App, accountID, provider string) (*core.Record, error) {
	col, err := app.FindCollectionByNameOrId("harness_auth_attempts")
	if err != nil {
		return nil, err
	}
	rec := core.NewRecord(col)
	rec.Set("account", accountID)
	rec.Set("provider", provider)
	rec.Set("status", harnessauth.AttemptStatusStarting)
	rec.Set("expires_at", time.Now().UTC().Add(15*time.Minute))
	return rec, app.Save(rec)
}

func latestHarnessAuthAttempt(app core.App, accountID string) (*core.Record, error) {
	recs, err := app.FindRecordsByFilter("harness_auth_attempts", "account = {:account}", "-created", 1, 0, map[string]any{"account": accountID})
	if err != nil {
		return nil, err
	}
	if len(recs) == 0 {
		return nil, nil
	}
	return recs[0], nil
}

func activeHarnessAuthAttempt(app core.App, accountID string) (*core.Record, error) {
	recs, err := app.FindRecordsByFilter(
		"harness_auth_attempts",
		"account = {:account} && (status = 'starting' || status = 'awaiting_input')",
		"-created",
		1,
		0,
		map[string]any{"account": accountID},
	)
	if err != nil {
		return nil, err
	}
	if len(recs) == 0 {
		return nil, nil
	}
	return recs[0], nil
}

func authAccountAndAttemptForRequest(app core.App, userID string, input harnessAuthRequest) (*core.Record, *core.Record, error) {
	if input.Harness == "" {
		return nil, nil, fmt.Errorf("harness is required")
	}
	account, err := harnessaccount.Resolve(app, userID, input.Harness, input.AccountID)
	if err != nil {
		return nil, nil, err
	}
	if account == nil {
		return nil, nil, fmt.Errorf("account not found")
	}
	var attempt *core.Record
	if input.AttemptID != "" {
		attempt, err = app.FindRecordById("harness_auth_attempts", input.AttemptID)
		if err != nil {
			return account, nil, fmt.Errorf("attempt not found")
		}
		if attempt.GetString("account") != account.Id {
			return account, nil, fmt.Errorf("attempt does not belong to this account")
		}
		return account, attempt, nil
	}
	attempt, err = activeHarnessAuthAttempt(app, account.Id)
	if err != nil {
		return account, nil, err
	}
	return account, attempt, nil
}

func runtimeAttemptContext(app core.App, attempt *core.Record, userID string) (harnessauth.AttemptContext, error) {
	accountID := attempt.GetString("account")
	if accountID == "" {
		return harnessauth.AttemptContext{}, fmt.Errorf("attempt is missing harness account")
	}
	account, err := app.FindRecordById("harness_accounts", accountID)
	if err != nil {
		return harnessauth.AttemptContext{}, fmt.Errorf("resolve harness account %s: %w", accountID, err)
	}
	harnessID := account.GetString("harness")
	harness, err := app.FindRecordById("harnesses", harnessID)
	if err != nil {
		return harnessauth.AttemptContext{}, fmt.Errorf("resolve harness %s: %w", harnessID, err)
	}
	image := strings.TrimSpace(harness.GetString("container_image"))
	if image == "" {
		return harnessauth.AttemptContext{}, fmt.Errorf("harness %s is missing container_image", harnessID)
	}
	return harnessauth.AttemptContext{
		AttemptID:    attempt.Id,
		UserID:       userID,
		AccountID:    accountID,
		HarnessCLI:   harness.GetString("cli_id"),
		HarnessImage: image,
	}, nil
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
		return accountStatusConnecting
	case harnessauth.AttemptStatusSucceeded:
		return accountStatusConnected
	case harnessauth.AttemptStatusCancelled:
		return accountStatusDisconnected
	case harnessauth.AttemptStatusExpired:
		return accountStatusError
	case harnessauth.AttemptStatusFailed:
		return accountStatusError
	default:
		return accountStatusError
	}
}

func renderHarnessAuthStatus(app core.App, account *core.Record, attempt *core.Record) harnessAuthStatusResp {
	status := account.GetString("status")
	if status == "" {
		status = accountStatusDisconnected
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
