package harnessvolume

import (
	"strings"
	"testing"
)

func TestResolveKeepsUserWorkspacesSeparateAndSharesAccountAuth(t *testing.T) {
	first, err := Resolve("pocketcoder_workspace", "user123456789", "codex", "account1234567")
	if err != nil {
		t.Fatal(err)
	}
	otherUser, err := Resolve("pocketcoder_workspace", "other987654321", "codex", "account1234567")
	if err != nil {
		t.Fatal(err)
	}
	if first.Workspace != "pocketcoder_user_user1234_workspace" {
		t.Fatalf("Workspace = %q", first.Workspace)
	}
	if first.Workspace == otherUser.Workspace {
		t.Fatal("PocketBase users must not share workspace volumes")
	}
	if first.Auth != otherUser.Auth {
		t.Fatal("members of one harness account must share its authentication volume")
	}
	if first.Auth != "pocketcoder_harness_codex_account_account1234567_auth_home" {
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

func TestResolveNoAccountUsesUserScopedAuthVolume(t *testing.T) {
	names, err := Resolve("pocketcoder_workspace", "userid", "codex", "")
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(names.Auth, "_user_userid_") {
		t.Fatalf("Auth = %q, want a user-scoped auth volume", names.Auth)
	}
}

func TestResolveRejectsBindSyntax(t *testing.T) {
	if _, err := Resolve("base", "user:bad", "codex", "account-one"); err == nil {
		t.Fatal("expected an invalid user id to be rejected")
	}
}

func TestResolveGitVolumeUsesFullUserID(t *testing.T) {
	first, _ := Resolve("base", "abcdefghijklmnop", "codex", "account")
	second, _ := Resolve("base", "abcdefghijklmnoq", "codex", "account")
	if first.GitSSH == second.GitSSH {
		t.Fatal("git volumes must not collide on truncated user IDs")
	}
	if first.GitSSH != "base_git_ssh_abcdefghijklmnop" {
		t.Fatalf("GitSSH = %q", first.GitSSH)
	}
}
