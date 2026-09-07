package hooks

import (
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/gitssh"
)

func seedUser(t *testing.T, app core.App, email string) *core.Record {
	t.Helper()
	coll, err := app.FindCollectionByNameOrId("users")
	if err != nil {
		t.Fatal(err)
	}
	u := core.NewRecord(coll)
	u.SetEmail(email)
	u.SetPassword("password1234")
	if err := app.Save(u); err != nil {
		t.Fatal(err)
	}
	return u
}

func TestGitSSHHooksEnqueueTheOwningUserOnCredentialCreate(t *testing.T) {
	app := testApp(t)
	user := seedUser(t, app, "enqueue-cred@example.com")
	queue := gitssh.NewQueue()
	RegisterGitSSHHooks(app, queue)

	coll, err := app.FindCollectionByNameOrId("git_ssh_credentials")
	if err != nil {
		t.Fatal(err)
	}
	cred := core.NewRecord(coll)
	cred.Set("user", user.Id)
	cred.Set("label", "my key")
	cred.Set("kind", "account")
	if err := app.Save(cred); err != nil {
		t.Fatal(err)
	}

	if got := queue.Drain(); len(got) != 1 || got[0] != user.Id {
		t.Fatalf("drained %v, want [%s]", got, user.Id)
	}
}

func newAccessRecord(t *testing.T, app core.App, userID string, set map[string]any) *core.Record {
	t.Helper()
	coll, err := app.FindCollectionByNameOrId("git_repository_access")
	if err != nil {
		t.Fatal(err)
	}
	access := core.NewRecord(coll)
	access.Set("user", userID)
	access.Set("purpose", "let the agent push")
	access.Set("credential_mode", "generated_deploy")
	access.Set("requested_access", "read_write")
	for k, v := range set {
		access.Set(k, v)
	}
	return access
}

func TestGitSSHRepositoryAccessRejectsACustomProviderWithNoHost(t *testing.T) {
	app := testApp(t)
	user := seedUser(t, app, "custom-nohost@example.com")
	RegisterGitSSHHooks(app, gitssh.NewQueue())

	access := newAccessRecord(t, app, user.Id, map[string]any{
		"provider":   "custom",
		"repository": "org/repo",
	})
	if err := app.Save(access); err == nil {
		t.Fatal("expected an error for a custom provider with no host")
	}
}

func TestGitSSHRepositoryAccessRejectsAHostContainingControlCharacters(t *testing.T) {
	app := testApp(t)
	user := seedUser(t, app, "custom-badhost@example.com")
	RegisterGitSSHHooks(app, gitssh.NewQueue())

	access := newAccessRecord(t, app, user.Id, map[string]any{
		"provider":   "custom",
		"repository": "org/repo",
		"host":       "evil.com\n    ProxyCommand /bin/sh -c 'echo pwned'",
	})
	if err := app.Save(access); err == nil {
		t.Fatal("expected an error for a host containing control characters")
	}
}

func TestGitSSHRepositoryAccessAcceptsAValidCustomHost(t *testing.T) {
	app := testApp(t)
	user := seedUser(t, app, "custom-goodhost@example.com")
	RegisterGitSSHHooks(app, gitssh.NewQueue())

	access := newAccessRecord(t, app, user.Id, map[string]any{
		"provider":       "custom",
		"repository":     "org/repo",
		"host":           "git.example.com",
		"port":           2222,
		"known_host_key": "attacker-supplied line",
	})
	if err := app.Save(access); err != nil {
		t.Fatal(err)
	}
	if access.GetString("known_host_key") != "" {
		t.Fatalf("known_host_key = %q, want cleared on create (only the pinning probe may set it)",
			access.GetString("known_host_key"))
	}
}

func TestGitSSHRepositoryAccessClearsHostForABuiltinProvider(t *testing.T) {
	app := testApp(t)
	user := seedUser(t, app, "builtin-host@example.com")
	RegisterGitSSHHooks(app, gitssh.NewQueue())

	access := newAccessRecord(t, app, user.Id, map[string]any{
		"provider":       "github",
		"repository":     "octo/hello",
		"host":           "attacker.example.com",
		"port":           2222,
		"known_host_key": "attacker-supplied line",
	})
	if err := app.Save(access); err != nil {
		t.Fatal(err)
	}
	if access.GetString("host") != "" || access.GetInt("port") != 0 ||
		access.GetString("known_host_key") != "" {
		t.Fatalf("host/port/known_host_key not cleared for a built-in provider: %q/%d/%q",
			access.GetString("host"), access.GetInt("port"), access.GetString("known_host_key"))
	}
}

func TestGitSSHHooksEnqueueTheOwningUserOnRepositoryAccessCreate(t *testing.T) {
	app := testApp(t)
	user := seedUser(t, app, "enqueue-access@example.com")
	queue := gitssh.NewQueue()
	RegisterGitSSHHooks(app, queue)

	coll, err := app.FindCollectionByNameOrId("git_repository_access")
	if err != nil {
		t.Fatal(err)
	}
	access := core.NewRecord(coll)
	access.Set("user", user.Id)
	access.Set("provider", "github")
	access.Set("repository", "octo/hello")
	access.Set("purpose", "let the agent push")
	access.Set("credential_mode", "generated_deploy")
	access.Set("requested_access", "read_write")
	if err := app.Save(access); err != nil {
		t.Fatal(err)
	}

	if got := queue.Drain(); len(got) != 1 || got[0] != user.Id {
		t.Fatalf("drained %v, want [%s]", got, user.Id)
	}
}
