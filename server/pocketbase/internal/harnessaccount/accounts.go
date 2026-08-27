// Package harnessaccount resolves and selects the OAuth-account side of a
// user's harness credentials -- see harness_oauth_accounts and
// credential_selections in schema.json. API keys (provider_api_keys) are
// plain PocketBase record CRUD with no bespoke resolution logic; they don't
// go through this package at all (see internal/api/harness_auth.go).
package harnessaccount

import (
	"fmt"
	"strings"

	"github.com/pocketbase/pocketbase/core"
)

const (
	StatusDisconnected = "disconnected"

	VisibilityPersonal   = "personal"
	VisibilityDeployment = "deployment"
)

func RegisterHooks(app core.App) {
	app.OnRecordCreateRequest("harness_oauth_accounts").BindFunc(func(e *core.RecordRequestEvent) error {
		if e.Auth == nil || e.Auth.Id == "" {
			return fmt.Errorf("authentication required")
		}
		e.Record.Set("owner", e.Auth.Id)
		e.Record.Set("status", StatusDisconnected)
		e.Record.Set("last_error", "")
		return e.Next()
	})
	// Spec §4.7: creating an OAuth account for a (harness, provider) pair
	// that doesn't advertise OAuth support must be rejected here, at the
	// schema/hook layer -- not only in the bespoke auth endpoint (Task 9),
	// since harness_oauth_accounts remains directly client-creatable via
	// the standard PocketBase REST API and its own create rule
	// (`@request.auth.id != ''`) does not check this on its own.
	app.OnRecordCreate("harness_oauth_accounts").BindFunc(func(e *core.RecordEvent) error {
		edge, err := app.FindFirstRecordByFilter(
			"harness_providers",
			"harness = {:h} && provider = {:p}",
			map[string]any{"h": e.Record.GetString("harness"), "p": e.Record.GetString("provider")},
		)
		if err != nil || !edge.GetBool("supports_oauth") {
			return fmt.Errorf("this harness/provider pair does not support OAuth login")
		}
		return e.Next()
	})
	app.OnRecordUpdateRequest("harness_oauth_accounts").BindFunc(func(e *core.RecordRequestEvent) error {
		original := e.Record.Original()
		if e.Auth == nil || e.Auth.Id == "" || original == nil || original.GetString("owner") != e.Auth.Id {
			return fmt.Errorf("harness account must belong to the authenticated user")
		}
		for _, field := range []string{"owner", "harness", "provider", "status", "last_error"} {
			e.Record.Set(field, original.Get(field))
		}
		return e.Next()
	})
	app.OnRecordCreateRequest("credential_selections").BindFunc(func(e *core.RecordRequestEvent) error {
		if e.Auth == nil || e.Auth.Id == "" {
			return fmt.Errorf("authentication required")
		}
		e.Record.Set("user", e.Auth.Id)
		return e.Next()
	})
	app.OnRecordUpdateRequest("credential_selections").BindFunc(func(e *core.RecordRequestEvent) error {
		original := e.Record.Original()
		if e.Auth == nil || e.Auth.Id == "" || original == nil || original.GetString("user") != e.Auth.Id {
			return fmt.Errorf("credential selection must belong to the authenticated user")
		}
		e.Record.Set("user", original.Get("user"))
		e.Record.Set("harness", original.Get("harness"))
		e.Record.Set("provider", original.Get("provider"))
		return e.Next()
	})

	validate := func(e *core.RecordEvent) error {
		if e.Record.GetString("mode") != "oauth" {
			e.Record.Set("oauth_account", "")
			return e.Next()
		}
		account, err := app.FindRecordById("harness_oauth_accounts", e.Record.GetString("oauth_account"))
		if err != nil {
			return fmt.Errorf("selected oauth account not found")
		}
		if account.GetString("harness") != e.Record.GetString("harness") || account.GetString("provider") != e.Record.GetString("provider") {
			return fmt.Errorf("selected account does not match this harness/provider")
		}
		if !CanAccess(account, e.Record.GetString("user")) {
			return fmt.Errorf("selected account is not available to user")
		}
		return e.Next()
	}
	app.OnRecordCreate("credential_selections").BindFunc(validate)
	app.OnRecordUpdate("credential_selections").BindFunc(validate)
}

// Resolve returns either an explicitly requested accessible account or the
// user's selected OAuth account for (harness, provider). A missing
// selection, or a selection whose mode isn't "oauth", is not an error --
// both return (nil, nil).
func Resolve(app core.App, userID, harnessID, providerID, accountID string) (*core.Record, error) {
	if accountID != "" {
		account, err := app.FindRecordById("harness_oauth_accounts", accountID)
		if err != nil || account.GetString("harness") != harnessID || account.GetString("provider") != providerID {
			return nil, fmt.Errorf("account not found")
		}
		if !CanAccess(account, userID) {
			return nil, fmt.Errorf("account is not available to this user")
		}
		return account, nil
	}

	selections, err := app.FindRecordsByFilter(
		"credential_selections",
		"user = {:user} && harness = {:harness} && provider = {:provider}",
		"", 1, 0,
		map[string]any{"user": userID, "harness": harnessID, "provider": providerID},
	)
	if err != nil {
		return nil, err
	}
	if len(selections) == 0 || selections[0].GetString("mode") != "oauth" {
		return nil, nil
	}
	account, err := app.FindRecordById("harness_oauth_accounts", selections[0].GetString("oauth_account"))
	if err != nil || account.GetString("harness") != harnessID || account.GetString("provider") != providerID || !CanAccess(account, userID) {
		return nil, nil
	}
	return account, nil
}

// SelectOrCreate selects an existing account or creates the conventional
// deployment/personal account for this (harness, provider) pair, then
// records the user's selection as mode=oauth. visibility must be personal
// or deployment.
func SelectOrCreate(app core.App, userID, harnessID, providerID, accountID, accountName, visibility string) (*core.Record, error) {
	if accountID != "" {
		account, err := Resolve(app, userID, harnessID, providerID, accountID)
		if err != nil {
			return nil, err
		}
		if err := SetSelection(app, userID, harnessID, providerID, account); err != nil {
			return nil, err
		}
		return account, nil
	}

	if visibility != VisibilityPersonal && visibility != VisibilityDeployment {
		return nil, fmt.Errorf("visibility must be personal or deployment")
	}

	filter := "harness = {:harness} && provider = {:provider} && owner = {:owner} && visibility = 'personal'"
	params := map[string]any{"harness": harnessID, "provider": providerID, "owner": userID}
	if visibility == VisibilityDeployment {
		filter = "harness = {:harness} && provider = {:provider} && visibility = 'deployment'"
		params = map[string]any{"harness": harnessID, "provider": providerID}
	}
	accounts, err := app.FindRecordsByFilter("harness_oauth_accounts", filter, "created", 1, 0, params)
	if err != nil {
		return nil, err
	}
	var account *core.Record
	if len(accounts) > 0 {
		account = accounts[0]
	} else {
		col, err := app.FindCollectionByNameOrId("harness_oauth_accounts")
		if err != nil {
			return nil, err
		}
		account = core.NewRecord(col)
		account.Set("harness", harnessID)
		account.Set("provider", providerID)
		account.Set("owner", userID)
		account.Set("visibility", visibility)
		account.Set("status", StatusDisconnected)
		name := strings.TrimSpace(accountName)
		if name == "" {
			prefix := "Personal"
			if visibility == VisibilityDeployment {
				prefix = "Shared"
			}
			name = prefix + " account"
			if harness, harnessErr := app.FindRecordById("harnesses", harnessID); harnessErr == nil {
				name = prefix + " " + harness.GetString("name")
			}
		}
		account.Set("name", name)
		if err := app.Save(account); err != nil {
			return nil, err
		}
	}
	if err := SetSelection(app, userID, harnessID, providerID, account); err != nil {
		return nil, err
	}
	return account, nil
}

// CanAccess reports whether a PocketBase user may use an account. Personal
// accounts are owner-only; deployment accounts are available to every
// authenticated user of this single-owner deployment.
func CanAccess(account *core.Record, userID string) bool {
	return account.GetString("owner") == userID || account.GetString("visibility") == VisibilityDeployment
}

// SetSelection records mode=oauth with this account for (user, harness,
// provider). The collection's unique(user, harness, provider) index
// enforces the cardinality invariant.
func SetSelection(app core.App, userID, harnessID, providerID string, account *core.Record) error {
	if account.GetString("harness") != harnessID || account.GetString("provider") != providerID {
		return fmt.Errorf("account does not belong to this harness/provider")
	}
	if !CanAccess(account, userID) {
		return fmt.Errorf("account is not available to this user")
	}
	selections, err := app.FindRecordsByFilter(
		"credential_selections",
		"user = {:user} && harness = {:harness} && provider = {:provider}",
		"", 1, 0,
		map[string]any{"user": userID, "harness": harnessID, "provider": providerID},
	)
	if err != nil {
		return err
	}
	var selection *core.Record
	if len(selections) == 0 {
		col, err := app.FindCollectionByNameOrId("credential_selections")
		if err != nil {
			return err
		}
		selection = core.NewRecord(col)
		selection.Set("user", userID)
		selection.Set("harness", harnessID)
		selection.Set("provider", providerID)
	} else {
		selection = selections[0]
	}
	selection.Set("mode", "oauth")
	selection.Set("oauth_account", account.Id)
	return app.Save(selection)
}
