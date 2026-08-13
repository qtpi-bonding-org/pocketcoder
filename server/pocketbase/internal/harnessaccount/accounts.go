// Package harnessaccount owns harness credential identities and each user's
// selected identity per harness. PocketBase users own workspaces; harness
// accounts own login state and may be personal or deployment-visible.
package harnessaccount

import (
	"fmt"
	"strings"

	"github.com/pocketbase/pocketbase/core"
)

const (
	ModeAccount = "account"
	ModeAPIKey  = "api_key"
	ModeNone    = "none"

	StatusDisconnected = "disconnected"

	VisibilityPersonal   = "personal"
	VisibilityDeployment = "deployment"
)

// RegisterHooks enforces the cross-collection selection invariants that the
// schema's relation fields and unique index cannot express on their own.
func RegisterHooks(app core.App) {
	app.OnRecordCreateRequest("harness_accounts").BindFunc(func(e *core.RecordRequestEvent) error {
		if e.Auth == nil || e.Auth.Id == "" {
			return fmt.Errorf("authentication required")
		}
		e.Record.Set("owner", e.Auth.Id)
		e.Record.Set("provider_key", "")
		e.Record.Set("status", StatusDisconnected)
		e.Record.Set("last_error", "")
		return e.Next()
	})
	app.OnRecordUpdateRequest("harness_accounts").BindFunc(func(e *core.RecordRequestEvent) error {
		original := e.Record.Original()
		if e.Auth == nil || e.Auth.Id == "" || original == nil || original.GetString("owner") != e.Auth.Id {
			return fmt.Errorf("harness account must belong to the authenticated user")
		}
		for _, field := range []string{"owner", "harness", "provider_key", "status", "last_error"} {
			e.Record.Set(field, original.Get(field))
		}
		return e.Next()
	})
	app.OnRecordCreateRequest("harness_account_selections").BindFunc(func(e *core.RecordRequestEvent) error {
		if e.Auth == nil || e.Auth.Id == "" {
			return fmt.Errorf("authentication required")
		}
		e.Record.Set("user", e.Auth.Id)
		return e.Next()
	})
	app.OnRecordUpdateRequest("harness_account_selections").BindFunc(func(e *core.RecordRequestEvent) error {
		original := e.Record.Original()
		if e.Auth == nil || e.Auth.Id == "" || original == nil || original.GetString("user") != e.Auth.Id {
			return fmt.Errorf("harness account selection must belong to the authenticated user")
		}
		e.Record.Set("user", original.Get("user"))
		e.Record.Set("harness", original.Get("harness"))
		return e.Next()
	})

	validate := func(e *core.RecordEvent) error {
		account, err := app.FindRecordById("harness_accounts", e.Record.GetString("account"))
		if err != nil {
			return fmt.Errorf("selected harness account not found")
		}
		if account.GetString("harness") != e.Record.GetString("harness") {
			return fmt.Errorf("selected account does not belong to harness")
		}
		if !CanAccess(account, e.Record.GetString("user")) {
			return fmt.Errorf("selected account is not available to user")
		}
		return e.Next()
	}
	app.OnRecordCreate("harness_account_selections").BindFunc(validate)
	app.OnRecordUpdate("harness_account_selections").BindFunc(validate)
}

// Resolve returns either an explicitly requested accessible account or the
// user's selected account for the harness. A missing selection is not an error.
func Resolve(app core.App, userID, harnessID, accountID string) (*core.Record, error) {
	if accountID != "" {
		account, err := app.FindRecordById("harness_accounts", accountID)
		if err != nil || account.GetString("harness") != harnessID {
			return nil, fmt.Errorf("account not found")
		}
		if !CanAccess(account, userID) {
			return nil, fmt.Errorf("account is not available to this user")
		}
		return account, nil
	}

	selections, err := app.FindRecordsByFilter(
		"harness_account_selections",
		"user = {:user} && harness = {:harness}",
		"",
		1,
		0,
		map[string]any{"user": userID, "harness": harnessID},
	)
	if err != nil {
		return nil, err
	}
	if len(selections) == 0 {
		return nil, nil
	}
	account, err := app.FindRecordById("harness_accounts", selections[0].GetString("account"))
	if err != nil || account.GetString("harness") != harnessID || !CanAccess(account, userID) {
		return nil, nil
	}
	return account, nil
}

// SelectOrCreate selects an existing account or creates the conventional
// deployment/personal account for this harness, then records the user's
// selection. visibility must be personal or deployment.
func SelectOrCreate(app core.App, userID, harnessID, accountID, accountName, visibility, credentialMode string) (*core.Record, error) {
	if accountID != "" {
		account, err := Resolve(app, userID, harnessID, accountID)
		if err != nil {
			return nil, err
		}
		if err := SetSelection(app, userID, harnessID, account); err != nil {
			return nil, err
		}
		return account, nil
	}

	if visibility != VisibilityPersonal && visibility != VisibilityDeployment {
		return nil, fmt.Errorf("visibility must be personal or deployment")
	}

	filter := "harness = {:harness} && owner = {:owner} && visibility = 'personal'"
	params := map[string]any{"harness": harnessID, "owner": userID}
	if visibility == VisibilityDeployment {
		filter = "harness = {:harness} && visibility = 'deployment'"
		params = map[string]any{"harness": harnessID}
	}
	accounts, err := app.FindRecordsByFilter("harness_accounts", filter, "created", 1, 0, params)
	if err != nil {
		return nil, err
	}
	var account *core.Record
	if len(accounts) > 0 {
		account = accounts[0]
	} else {
		col, err := app.FindCollectionByNameOrId("harness_accounts")
		if err != nil {
			return nil, err
		}
		account = core.NewRecord(col)
		account.Set("harness", harnessID)
		account.Set("owner", userID)
		account.Set("visibility", visibility)
		account.Set("credential_mode", credentialMode)
		account.Set("status", StatusDisconnected)
		name := strings.TrimSpace(accountName)
		if name == "" {
			prefix := "Personal"
			if visibility == VisibilityDeployment {
				prefix = "Shared"
			}
			name = prefix + " harness account"
			if harness, harnessErr := app.FindRecordById("harnesses", harnessID); harnessErr == nil {
				name = prefix + " " + harness.GetString("name")
			}
		}
		account.Set("name", name)
		if err := app.Save(account); err != nil {
			return nil, err
		}
	}
	if err := SetSelection(app, userID, harnessID, account); err != nil {
		return nil, err
	}
	return account, nil
}

// EnsureDefaultPersonal supplies a deterministic fallback for harnesses that
// need to start before the user visits the auth screen.
func EnsureDefaultPersonal(app core.App, userID, harnessID string) (*core.Record, error) {
	account, err := Resolve(app, userID, harnessID, "")
	if err != nil || account != nil {
		return account, err
	}
	return SelectOrCreate(app, userID, harnessID, "", "", VisibilityPersonal, ModeNone)
}

// CanAccess reports whether a PocketBase user may use an account. Personal
// accounts are owner-only; deployment accounts are available to every
// authenticated user of this single-owner deployment.
func CanAccess(account *core.Record, userID string) bool {
	return account.GetString("owner") == userID || account.GetString("visibility") == VisibilityDeployment
}

// SetSelection records one selected account for a user and harness. The
// collection's unique(user, harness) index enforces the cardinality invariant.
func SetSelection(app core.App, userID, harnessID string, account *core.Record) error {
	if account.GetString("harness") != harnessID {
		return fmt.Errorf("account does not belong to harness")
	}
	if !CanAccess(account, userID) {
		return fmt.Errorf("account is not available to this user")
	}
	selections, err := app.FindRecordsByFilter(
		"harness_account_selections",
		"user = {:user} && harness = {:harness}",
		"",
		1,
		0,
		map[string]any{"user": userID, "harness": harnessID},
	)
	if err != nil {
		return err
	}
	var selection *core.Record
	if len(selections) == 0 {
		col, err := app.FindCollectionByNameOrId("harness_account_selections")
		if err != nil {
			return err
		}
		selection = core.NewRecord(col)
		selection.Set("user", userID)
		selection.Set("harness", harnessID)
	} else {
		selection = selections[0]
	}
	selection.Set("account", account.Id)
	return app.Save(selection)
}
