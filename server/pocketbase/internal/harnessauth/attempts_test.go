package harnessauth

import (
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	_ "github.com/qtpi-bonding-org/pocketcoder/backend/pb_migrations"
)

func TestAttemptStatusMapping(t *testing.T) {
	tests := map[string]string{
		AttemptStatusStarting:  StatusConnecting,
		AttemptStatusAwaiting:  StatusConnecting,
		AttemptStatusSucceeded: StatusConnected,
		AttemptStatusCancelled: StatusDisconnected,
		AttemptStatusFailed:    StatusError,
		AttemptStatusExpired:   StatusError,
	}
	for attempt, want := range tests {
		if got := StatusForAttempt(attempt); got != want {
			t.Errorf("StatusForAttempt(%q) = %q, want %q", attempt, got, want)
		}
	}
}

func TestResolveAuthenticatorKey(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	harness, err := app.FindFirstRecordByFilter("harnesses", "cli_id = 'codex'", nil)
	if err != nil {
		t.Fatal(err)
	}
	provider, err := app.FindFirstRecordByFilter("providers", "provider_id = 'openai'", nil)
	if err != nil {
		t.Fatal(err)
	}
	account := core.NewRecord(mustCollection(t, app, "harness_oauth_accounts"))
	account.Set("harness", harness.Id)
	account.Set("provider", provider.Id)

	t.Run("supported pair", func(t *testing.T) {
		key, err := ResolveAuthenticatorKey(app, account)
		if err != nil {
			t.Fatal(err)
		}
		if key != ProviderCodex {
			t.Fatalf("key = %q, want %q", key, ProviderCodex)
		}
	})

	t.Run("unsupported pair", func(t *testing.T) {
		edges := mustCollection(t, app, "harness_providers")
		edge := core.NewRecord(edges)
		edge.Set("harness", harness.Id)
		// Use a second seeded provider so this edge does not collide with the
		// supported seeded Codex/OpenAI edge.
		other, err := app.FindFirstRecordByFilter("providers", "provider_id = 'anthropic'", nil)
		if err != nil {
			t.Fatal(err)
		}
		edge.Set("provider", other.Id)
		edge.Set("supports_oauth", false)
		if err := app.Save(edge); err != nil {
			t.Fatal(err)
		}
		account.Set("provider", other.Id)
		if _, err := ResolveAuthenticatorKey(app, account); err == nil {
			t.Fatal("expected unsupported pair to return an error")
		}
	})

	t.Run("missing edge", func(t *testing.T) {
		account.Set("harness", "missing-harness")
		account.Set("provider", "missing-provider")
		if _, err := ResolveAuthenticatorKey(app, account); err == nil {
			t.Fatal("expected missing edge to return an error")
		}
	})
}

func mustCollection(t *testing.T, app core.App, name string) *core.Collection {
	t.Helper()
	collection, err := app.FindCollectionByNameOrId(name)
	if err != nil {
		t.Fatal(err)
	}
	return collection
}
