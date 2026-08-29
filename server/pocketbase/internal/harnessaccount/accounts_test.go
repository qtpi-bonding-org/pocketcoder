package harnessaccount_test

import (
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/harnessaccount"
	_ "github.com/qtpi-bonding-org/pocketcoder/backend/pb_migrations"
)

func TestResolveIsScopedByProviderNotJustHarness(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	users, _ := app.FindCollectionByNameOrId("_pb_users_auth_")
	user := core.NewRecord(users)
	user.SetEmail("resolve-scope@example.com")
	user.SetPassword("password12345")
	if err := app.Save(user); err != nil {
		t.Fatal(err)
	}
	goose, err := app.FindFirstRecordByFilter("harnesses", "cli_id = 'goose'", nil)
	if err != nil {
		t.Fatal(err)
	}
	anthropic, err := app.FindFirstRecordByFilter("providers", "provider_id = 'anthropic'", nil)
	if err != nil {
		t.Fatal(err)
	}
	openai, err := app.FindFirstRecordByFilter("providers", "provider_id = 'openai'", nil)
	if err != nil {
		t.Fatal(err)
	}

	anthropicAccount, err := harnessaccount.SelectOrCreate(app, user.Id, goose.Id, anthropic.Id, "", "Anthropic via Goose", harnessaccount.VisibilityPersonal)
	if err != nil {
		t.Fatal(err)
	}
	openaiAccount, err := harnessaccount.SelectOrCreate(app, user.Id, goose.Id, openai.Id, "", "OpenAI via Goose", harnessaccount.VisibilityPersonal)
	if err != nil {
		t.Fatal(err)
	}
	if anthropicAccount.Id == openaiAccount.Id {
		t.Fatal("expected two distinct accounts for the same harness under two different providers")
	}

	resolvedAnthropic, err := harnessaccount.Resolve(app, user.Id, goose.Id, anthropic.Id, "")
	if err != nil {
		t.Fatal(err)
	}
	if resolvedAnthropic == nil || resolvedAnthropic.Id != anthropicAccount.Id {
		t.Errorf("Resolve for (goose, anthropic) = %v, want %s", resolvedAnthropic, anthropicAccount.Id)
	}
	resolvedOpenAI, err := harnessaccount.Resolve(app, user.Id, goose.Id, openai.Id, "")
	if err != nil {
		t.Fatal(err)
	}
	if resolvedOpenAI == nil || resolvedOpenAI.Id != openaiAccount.Id {
		t.Errorf("Resolve for (goose, openai) = %v, want %s", resolvedOpenAI, openaiAccount.Id)
	}
}

func TestHarnessOAuthAccountCreateRejectsUnsupportedProviderPair(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()
	harnessaccount.RegisterHooks(app) // OnRecordCreate (non-request) hooks fire without going through the API layer

	users, _ := app.FindCollectionByNameOrId("_pb_users_auth_")
	user := core.NewRecord(users)
	user.SetEmail("oauth-gate@example.com")
	user.SetPassword("password12345")
	if err := app.Save(user); err != nil {
		t.Fatal(err)
	}
	goose, err := app.FindFirstRecordByFilter("harnesses", "cli_id = 'goose'", nil) // provider_fanout harness -- never gets a supports_oauth edge
	if err != nil {
		t.Fatal(err)
	}
	anthropic, err := app.FindFirstRecordByFilter("providers", "provider_id = 'anthropic'", nil)
	if err != nil {
		t.Fatal(err)
	}

	coll, err := app.FindCollectionByNameOrId("harness_oauth_accounts")
	if err != nil {
		t.Fatal(err)
	}
	rec := core.NewRecord(coll)
	rec.Set("harness", goose.Id)
	rec.Set("provider", anthropic.Id)
	rec.Set("owner", user.Id)
	rec.Set("name", "should be rejected")
	rec.Set("visibility", harnessaccount.VisibilityPersonal)
	if err := app.Save(rec); err == nil {
		t.Fatal("expected Save to fail: goose/anthropic has no supports_oauth harness_providers edge")
	}
}

func TestSetSelectionClearsOAuthAccountWhenModeIsNotOAuth(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()
	harnessaccount.RegisterHooks(app)

	users, _ := app.FindCollectionByNameOrId("_pb_users_auth_")
	user := core.NewRecord(users)
	user.SetEmail("clear-oauth@example.com")
	user.SetPassword("password12345")
	if err := app.Save(user); err != nil {
		t.Fatal(err)
	}
	codex, err := app.FindFirstRecordByFilter("harnesses", "cli_id = 'codex'", nil)
	if err != nil {
		t.Fatal(err)
	}
	openai, err := app.FindFirstRecordByFilter("providers", "provider_id = 'openai'", nil)
	if err != nil {
		t.Fatal(err)
	}
	account, err := harnessaccount.SelectOrCreate(app, user.Id, codex.Id, openai.Id, "", "", harnessaccount.VisibilityPersonal)
	if err != nil {
		t.Fatal(err)
	}

	selColl, err := app.FindCollectionByNameOrId("credential_selections")
	if err != nil {
		t.Fatal(err)
	}
	sel, err := app.FindFirstRecordByFilter("credential_selections", "user = {:u} && harness = {:h} && provider = {:p}", map[string]any{"u": user.Id, "h": codex.Id, "p": openai.Id})
	if err != nil {
		t.Fatal(err)
	}
	if sel.GetString("oauth_account") != account.Id {
		t.Fatalf("expected the selection created by SelectOrCreate to already reference %s, got %q", account.Id, sel.GetString("oauth_account"))
	}
	sel.Set("mode", "api_key")
	if err := app.Save(sel); err != nil {
		t.Fatal(err)
	}
	reloaded, err := app.FindRecordById(selColl.Id, sel.Id)
	if err != nil {
		t.Fatal(err)
	}
	if got := reloaded.GetString("oauth_account"); got != "" {
		t.Errorf("oauth_account = %q after switching to mode=api_key, want empty", got)
	}
}
