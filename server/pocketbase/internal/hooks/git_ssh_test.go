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
