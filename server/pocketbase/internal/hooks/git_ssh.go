package hooks

import (
	"fmt"
	"strings"

	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/gitssh"
)

// RegisterGitSSHHooks enforces the non-secret invariants at the collection
// boundary. Secret generation/materialization is deliberately asynchronous;
// these hooks only establish safe desired state and prevent client forgery.
func RegisterGitSSHHooks(app core.App) {
	protectRequest := func(e *core.RecordRequestEvent) error {
		name := e.Record.Collection().Name
		if name != "git_ssh_credentials" && name != "git_repository_access" {
			return e.Next()
		}
		if e.Auth == nil || e.Auth.Id == "" || e.Record.GetString("user") != e.Auth.Id {
			return fmt.Errorf("record must belong to the authenticated user")
		}
		if name == "git_ssh_credentials" {
			for _, field := range []string{"user", "source", "algorithm", "public_key", "fingerprint", "status", "last_error", "materialized_generation"} {
				if e.Record.Original() != nil {
					e.Record.Set(field, e.Record.Original().Get(field))
				}
			}
		} else {
			for _, field := range []string{"user", "credential", "status", "last_error"} {
				if e.Record.Original() != nil {
					e.Record.Set(field, e.Record.Original().Get(field))
				}
			}
		}
		return e.Next()
	}
	app.OnRecordUpdateRequest().BindFunc(protectRequest)
	app.OnRecordCreateRequest().BindFunc(func(e *core.RecordRequestEvent) error {
		if e.Record.Collection().Name != "git_ssh_credentials" && e.Record.Collection().Name != "git_repository_access" {
			return e.Next()
		}
		if e.Auth == nil || e.Auth.Id == "" {
			return fmt.Errorf("authentication required")
		}
		e.Record.Set("user", e.Auth.Id)
		return e.Next()
	})
	app.OnRecordCreate("git_ssh_credentials").BindFunc(func(e *core.RecordEvent) error {
		if err := requireOwner(e.Record); err != nil {
			return err
		}
		if e.Record.GetString("source") == "" {
			e.Record.Set("source", "generated")
		}
		if e.Record.GetString("algorithm") == "" {
			e.Record.Set("algorithm", "ed25519")
		}
		if e.Record.GetString("status") == "" {
			e.Record.Set("status", "pending")
		}
		for _, field := range []string{"public_key", "fingerprint", "last_error", "materialized_generation"} {
			e.Record.Set(field, "")
		}
		return e.Next()
	})
	app.OnRecordUpdate("git_ssh_credentials").BindFunc(func(e *core.RecordEvent) error {
		if err := requireOwner(e.Record); err != nil {
			return err
		}
		return e.Next()
	})
	app.OnRecordCreate("git_repository_access").BindFunc(func(e *core.RecordEvent) error {
		if err := requireOwner(e.Record); err != nil {
			return err
		}
		provider := strings.ToLower(strings.TrimSpace(e.Record.GetString("provider")))
		repo, err := gitssh.CanonicalRepository(provider, e.Record.GetString("repository"))
		if err != nil {
			return err
		}
		e.Record.Set("provider", provider)
		e.Record.Set("repository", repo)
		if mode := e.Record.GetString("credential_mode"); mode == "existing_account" {
			id := e.Record.GetString("credential")
			if id == "" {
				return fmt.Errorf("existing_account requires a credential")
			}
			cred, err := e.App.FindRecordById("git_ssh_credentials", id)
			if err != nil || cred.GetString("user") != e.Record.GetString("user") || cred.GetString("kind") != "account" {
				return fmt.Errorf("credential must be an owned account key")
			}
		} else if mode != "generated_deploy" {
			return fmt.Errorf("unsupported credential mode %q", mode)
		} else if e.Record.GetString("credential") != "" {
			return fmt.Errorf("generated deploy access cannot select a credential")
		}
		if e.Record.GetString("status") == "" {
			e.Record.Set("status", "pending")
		}
		if e.Record.GetString("registration_status") == "" {
			e.Record.Set("registration_status", "needs_registration")
		}
		return e.Next()
	})
	app.OnRecordUpdate("git_repository_access").BindFunc(func(e *core.RecordEvent) error {
		if err := requireOwner(e.Record); err != nil {
			return err
		}
		return e.Next()
	})
}

func requireOwner(rec *core.Record) error {
	if rec.GetString("user") == "" {
		return fmt.Errorf("record owner is required")
	}
	return nil
}
