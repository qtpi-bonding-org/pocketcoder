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

package harnessauth

import (
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/harnessaccount"
)

// Sentinel errors ResolveAccountAndAttempt returns for the two genuinely
// "not found" cases, so callers can return a real 404 instead of blanket-
// converting every error from this function into a 400. Live-confirmed
// 2026-08-27: internal/api/harness_auth.go's poll/submit/cancel/authRequest
// all did `return re.BadRequestError(err.Error(), nil)` unconditionally,
// so a caller with no account at all got a 400 "account not found" instead
// of the 404 that both the wording and REST convention call for.
var (
	ErrAccountNotFound = errors.New("account not found")
	ErrAttemptNotFound = errors.New("attempt not found")
)

const (
	ModeAccount        = "account"
	ModeAPIKey         = "api_key"
	ModeNone           = "none"
	StatusDisconnected = "disconnected"
	StatusConnecting   = "connecting"
	StatusConnected    = "connected"
	StatusError        = "error"
	StatusNeedsAPIKey  = "needs_api_key"
)

func CreateAttempt(app core.App, accountID string) (*core.Record, error) {
	col, err := app.FindCollectionByNameOrId("harness_oauth_attempts")
	if err != nil {
		return nil, err
	}
	rec := core.NewRecord(col)
	rec.Set("account", accountID)
	rec.Set("status", AttemptStatusStarting)
	rec.Set("expires_at", time.Now().UTC().Add(15*time.Minute))
	return rec, app.Save(rec)
}

func LatestAttempt(app core.App, accountID string) (*core.Record, error) {
	recs, err := app.FindRecordsByFilter("harness_oauth_attempts", "account = {:account}", "-created", 1, 0, map[string]any{"account": accountID})
	if err != nil {
		return nil, err
	}
	if len(recs) == 0 {
		return nil, nil
	}
	return recs[0], nil
}

func ActiveAttempt(app core.App, accountID string) (*core.Record, error) {
	recs, err := app.FindRecordsByFilter(
		"harness_oauth_attempts",
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

func ResolveAccountAndAttempt(app core.App, userID, harness, provider, accountID, attemptID string) (*core.Record, *core.Record, error) {
	if harness == "" {
		return nil, nil, fmt.Errorf("harness is required")
	}
	if provider == "" {
		return nil, nil, fmt.Errorf("provider is required")
	}
	account, err := harnessaccount.Resolve(app, userID, harness, provider, accountID)
	if err != nil {
		return nil, nil, err
	}
	if account == nil {
		return nil, nil, ErrAccountNotFound
	}
	var attempt *core.Record
	if attemptID != "" {
		attempt, err = app.FindRecordById("harness_oauth_attempts", attemptID)
		if err != nil {
			return account, nil, ErrAttemptNotFound
		}
		if attempt.GetString("account") != account.Id {
			return account, nil, fmt.Errorf("attempt does not belong to this account")
		}
		return account, attempt, nil
	}
	attempt, err = ActiveAttempt(app, account.Id)
	if err != nil {
		return account, nil, err
	}
	return account, attempt, nil
}

func BuildAttemptContext(app core.App, attempt *core.Record, userID string) (AttemptContext, error) {
	accountID := attempt.GetString("account")
	if accountID == "" {
		return AttemptContext{}, fmt.Errorf("attempt is missing harness account")
	}
	account, err := app.FindRecordById("harness_oauth_accounts", accountID)
	if err != nil {
		return AttemptContext{}, fmt.Errorf("resolve harness account %s: %w", accountID, err)
	}
	harnessID := account.GetString("harness")
	harness, err := app.FindRecordById("harnesses", harnessID)
	if err != nil {
		return AttemptContext{}, fmt.Errorf("resolve harness %s: %w", harnessID, err)
	}
	image := strings.TrimSpace(harness.GetString("container_image"))
	if image == "" {
		return AttemptContext{}, fmt.Errorf("harness %s is missing container_image", harnessID)
	}
	return AttemptContext{
		AttemptID:    attempt.Id,
		UserID:       userID,
		AccountID:    accountID,
		HarnessCLI:   harness.GetString("cli_id"),
		HarnessImage: image,
	}, nil
}

func ResolveAuthenticatorKey(app core.App, account *core.Record) (string, error) {
	edge, err := app.FindFirstRecordByFilter(
		"harness_providers",
		"harness = {:h} && provider = {:p}",
		map[string]any{"h": account.GetString("harness"), "p": account.GetString("provider")},
	)
	if err != nil {
		return "", fmt.Errorf("no harness_providers edge for this account's (harness, provider): %w", err)
	}
	if !edge.GetBool("supports_oauth") {
		return "", fmt.Errorf("this harness/provider pair does not support OAuth login")
	}
	key := edge.GetString("oauth_authenticator")
	if key == "" {
		return "", fmt.Errorf("harness_providers edge has supports_oauth=true but no oauth_authenticator set")
	}
	return key, nil
}

func UpdateAttempt(app core.App, attempt *core.Record, status, errorText string) error {
	attempt.Set("status", status)
	if errorText != "" {
		attempt.Set("last_error", errorText)
	} else {
		attempt.Set("last_error", nil)
	}
	if status == AttemptStatusFailed && errorText == "" {
		attempt.Set("last_error", "auth flow failed")
	}
	return app.Save(attempt)
}

func StatusForAttempt(attemptStatus string) string {
	switch attemptStatus {
	case AttemptStatusStarting, AttemptStatusAwaiting:
		return StatusConnecting
	case AttemptStatusSucceeded:
		return StatusConnected
	case AttemptStatusCancelled:
		return StatusDisconnected
	case AttemptStatusExpired:
		return StatusError
	case AttemptStatusFailed:
		return StatusError
	default:
		return StatusError
	}
}
