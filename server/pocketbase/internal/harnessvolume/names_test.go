package harnessvolume

import "testing"

func TestResolveKeepsUserWorkspacesSeparateAndSharesAccountAuth(t *testing.T) {
	first, err := Resolve("pocketcoder_goose_workspace", "user123456789", "codex", "account1234567")
	if err != nil {
		t.Fatal(err)
	}
	otherUser, err := Resolve("pocketcoder_goose_workspace", "other987654321", "codex", "account1234567")
	if err != nil {
		t.Fatal(err)
	}
	if first.Workspace != "pocketcoder_goose_workspace_user1234_workspace" {
		t.Fatalf("Workspace = %q", first.Workspace)
	}
	if first.Workspace == otherUser.Workspace {
		t.Fatal("PocketBase users must not share workspace volumes")
	}
	if first.Auth != otherUser.Auth {
		t.Fatal("members of one harness account must share its authentication volume")
	}
	if first.Auth != "pocketcoder_goose_workspace_harness_codex_account_account1234567_auth_home" {
		t.Fatalf("Auth = %q", first.Auth)
	}
}

func TestResolveSeparatesHarnessAuth(t *testing.T) {
	codex, _ := Resolve("base", "user-one", "codex", "account-one")
	claude, _ := Resolve("base", "user-one", "claude-code", "account-one")
	if codex.Auth == claude.Auth {
		t.Fatal("different harnesses must not share authentication volumes")
	}
}

func TestResolveSeparatesAccountsForOneHarness(t *testing.T) {
	shared, _ := Resolve("base", "user-one", "codex", "shared-account")
	personal, _ := Resolve("base", "user-one", "codex", "personal-account")
	if shared.Auth == personal.Auth {
		t.Fatal("different harness accounts must not share authentication volumes")
	}
}

func TestResolveRejectsBindSyntax(t *testing.T) {
	if _, err := Resolve("base", "user:bad", "codex", "account-one"); err == nil {
		t.Fatal("expected an invalid user id to be rejected")
	}
}
