package harnessaccount

import (
	"testing"

	"github.com/google/uuid"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	_ "github.com/qtpi-bonding-org/pocketcoder/backend/pb_migrations"
)

func TestDeploymentAccountCanBeSelectedByTwoUsers(t *testing.T) {
	app := testApp(t)
	harness := testHarness(t, app, "codex")
	first := testUser(t, app, "first@example.com")
	second := testUser(t, app, "second@example.com")

	shared, err := SelectOrCreate(app, first.Id, harness.Id, "", "Family Codex", VisibilityDeployment, ModeAccount)
	if err != nil {
		t.Fatal(err)
	}
	selected, err := SelectOrCreate(app, second.Id, harness.Id, "", "", VisibilityDeployment, ModeAccount)
	if err != nil {
		t.Fatal(err)
	}
	if selected.Id != shared.Id {
		t.Fatalf("second user selected account %q, want shared account %q", selected.Id, shared.Id)
	}
	for _, user := range []*core.Record{first, second} {
		resolved, err := Resolve(app, user.Id, harness.Id, "")
		if err != nil || resolved == nil || resolved.Id != shared.Id {
			t.Fatalf("Resolve(%s) = %v, %v; want shared account", user.Id, resolved, err)
		}
	}
}

func TestPersonalAccountsStaySeparate(t *testing.T) {
	app := testApp(t)
	harness := testHarness(t, app, "claude-code")
	first := testUser(t, app, "first-personal@example.com")
	second := testUser(t, app, "second-personal@example.com")

	a, err := SelectOrCreate(app, first.Id, harness.Id, "", "", VisibilityPersonal, ModeAccount)
	if err != nil {
		t.Fatal(err)
	}
	b, err := SelectOrCreate(app, second.Id, harness.Id, "", "", VisibilityPersonal, ModeAccount)
	if err != nil {
		t.Fatal(err)
	}
	if a.Id == b.Id {
		t.Fatal("personal harness accounts must not be reused across users")
	}
}

func TestSelectionsAreIndependentPerHarness(t *testing.T) {
	app := testApp(t)
	user := testUser(t, app, "defaults@example.com")
	codex := testHarness(t, app, "codex")
	claude := testHarness(t, app, "claude-code")

	for _, harness := range []*core.Record{codex, claude} {
		if _, err := EnsureDefaultPersonal(app, user.Id, harness.Id); err != nil {
			t.Fatal(err)
		}
	}
	selections, err := app.FindRecordsByFilter("harness_account_selections", "user = {:user}", "", 0, 0, map[string]any{"user": user.Id})
	if err != nil {
		t.Fatal(err)
	}
	if len(selections) != 2 {
		t.Fatalf("selections = %d, want one per harness", len(selections))
	}
}

func TestPersonalAccountCannotBeSelectedByAnotherUser(t *testing.T) {
	app := testApp(t)
	harness := testHarness(t, app, "codex-private")
	owner := testUser(t, app, "private-owner@example.com")
	other := testUser(t, app, "private-other@example.com")

	account, err := SelectOrCreate(app, owner.Id, harness.Id, "", "Private Codex", VisibilityPersonal, ModeAccount)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := SelectOrCreate(app, other.Id, harness.Id, account.Id, "", VisibilityPersonal, ModeAccount); err == nil {
		t.Fatal("expected another user to be denied access to a personal account")
	}
}

func TestSelectionReplacesPreviousAccountForHarness(t *testing.T) {
	app := testApp(t)
	harness := testHarness(t, app, "codex-selection")
	user := testUser(t, app, "selection@example.com")

	first, err := SelectOrCreate(app, user.Id, harness.Id, "", "First", VisibilityPersonal, ModeAccount)
	if err != nil {
		t.Fatal(err)
	}
	col, err := app.FindCollectionByNameOrId("harness_accounts")
	if err != nil {
		t.Fatal(err)
	}
	second := core.NewRecord(col)
	second.Set("harness", harness.Id)
	second.Set("owner", user.Id)
	second.Set("name", "Second")
	second.Set("visibility", VisibilityPersonal)
	second.Set("credential_mode", ModeAccount)
	second.Set("status", StatusDisconnected)
	if err := app.Save(second); err != nil {
		t.Fatal(err)
	}
	if err := SetSelection(app, user.Id, harness.Id, second); err != nil {
		t.Fatal(err)
	}

	resolved, err := Resolve(app, user.Id, harness.Id, "")
	if err != nil {
		t.Fatal(err)
	}
	if resolved == nil || resolved.Id != second.Id || resolved.Id == first.Id {
		t.Fatalf("resolved account = %v, want second account %s", resolved, second.Id)
	}
	selections, err := app.FindRecordsByFilter("harness_account_selections", "user = {:user} && harness = {:harness}", "", 0, 0, map[string]any{"user": user.Id, "harness": harness.Id})
	if err != nil {
		t.Fatal(err)
	}
	if len(selections) != 1 {
		t.Fatalf("selections = %d, want exactly one", len(selections))
	}
}

func TestSelectionHookRejectsMismatchedHarness(t *testing.T) {
	app := testApp(t)
	RegisterHooks(app)
	user := testUser(t, app, "hook-owner@example.com")
	codex := testHarness(t, app, "hook-codex")
	claude := testHarness(t, app, "hook-claude")
	account, err := SelectOrCreate(app, user.Id, codex.Id, "", "Codex", VisibilityPersonal, ModeAccount)
	if err != nil {
		t.Fatal(err)
	}

	col, err := app.FindCollectionByNameOrId("harness_account_selections")
	if err != nil {
		t.Fatal(err)
	}
	selection := core.NewRecord(col)
	selection.Set("user", user.Id)
	selection.Set("harness", claude.Id)
	selection.Set("account", account.Id)
	if err := app.Save(selection); err == nil {
		t.Fatal("expected selection hook to reject an account from another harness")
	}
}

func TestSelectionHookRejectsPersonalAccountForAnotherUser(t *testing.T) {
	app := testApp(t)
	RegisterHooks(app)
	owner := testUser(t, app, "hook-private-owner@example.com")
	other := testUser(t, app, "hook-private-other@example.com")
	harness := testHarness(t, app, "hook-private")
	account, err := SelectOrCreate(app, owner.Id, harness.Id, "", "Private", VisibilityPersonal, ModeAccount)
	if err != nil {
		t.Fatal(err)
	}

	col, err := app.FindCollectionByNameOrId("harness_account_selections")
	if err != nil {
		t.Fatal(err)
	}
	selection := core.NewRecord(col)
	selection.Set("user", other.Id)
	selection.Set("harness", harness.Id)
	selection.Set("account", account.Id)
	if err := app.Save(selection); err == nil {
		t.Fatal("expected selection hook to reject another user's personal account")
	}
}

func testApp(t *testing.T) core.App {
	t.Helper()
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(app.Cleanup)
	return app
}

func testUser(t *testing.T, app core.App, email string) *core.Record {
	t.Helper()
	col, err := app.FindCollectionByNameOrId("_pb_users_auth_")
	if err != nil {
		t.Fatal(err)
	}
	rec := core.NewRecord(col)
	rec.SetEmail(email)
	rec.SetPassword("password12345")
	if err := app.Save(rec); err != nil {
		t.Fatal(err)
	}
	return rec
}

func testHarness(t *testing.T, app core.App, cliID string) *core.Record {
	t.Helper()
	col, err := app.FindCollectionByNameOrId("harnesses")
	if err != nil {
		t.Fatal(err)
	}
	rec := core.NewRecord(col)
	rec.Set("name", cliID)
	rec.Set("cli_id", cliID+"-"+uuid.NewString()[:8])
	rec.Set("acp_transport", "websocket")
	if err := app.Save(rec); err != nil {
		t.Fatal(err)
	}
	return rec
}
