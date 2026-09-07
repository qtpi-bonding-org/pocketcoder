package gitssh

import (
	"context"
	"strings"
	"sync"
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"

	_ "github.com/qtpi-bonding-org/pocketcoder/backend/pb_migrations"
)

func testApp(t *testing.T) core.App {
	t.Helper()
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(app.Cleanup)
	return app
}

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

type fakeMaterializer struct {
	mu    sync.Mutex
	calls []Manifest
	err   error
}

func (f *fakeMaterializer) Materialize(_ context.Context, _ string, m Manifest) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.err != nil {
		return f.err
	}
	f.calls = append(f.calls, m)
	return nil
}

func TestQueueCoalescesUserWrites(t *testing.T) {
	q := NewQueue()
	q.Enqueue("u1")
	q.Enqueue("u1")
	q.Enqueue("u2")
	if got := len(q.Drain()); got != 2 {
		t.Fatalf("drained %d users", got)
	}
	if got := q.Drain(); len(got) != 0 {
		t.Fatalf("queue not empty: %v", got)
	}
}

func TestReconcileGeneratesAKeyForAPendingAccountCredential(t *testing.T) {
	app := testApp(t)
	user := seedUser(t, app, "acct@example.com")

	credColl, err := app.FindCollectionByNameOrId("git_ssh_credentials")
	if err != nil {
		t.Fatal(err)
	}
	cred := core.NewRecord(credColl)
	cred.Set("user", user.Id)
	cred.Set("label", "my account key")
	cred.Set("kind", "account")
	cred.Set("source", "generated")
	cred.Set("algorithm", "ed25519")
	cred.Set("status", "pending")
	if err := app.Save(cred); err != nil {
		t.Fatal(err)
	}

	mat := &fakeMaterializer{}
	r := &Reconciler{Materializer: mat}
	if err := r.ReconcileUser(context.Background(), app, user.Id); err != nil {
		t.Fatal(err)
	}

	got, err := app.FindRecordById("git_ssh_credentials", cred.Id)
	if err != nil {
		t.Fatal(err)
	}
	if got.GetString("status") != "ready" {
		t.Fatalf("status = %q, want ready", got.GetString("status"))
	}
	if got.GetString("public_key") == "" || got.GetString("fingerprint") == "" {
		t.Fatal("expected public_key/fingerprint to be populated")
	}
	if got.GetString("materialized_generation") == "" {
		t.Fatal("expected materialized_generation to be stamped")
	}
	if len(mat.calls) == 0 {
		t.Fatal("expected the materializer to be called")
	}
	if _, ok := mat.calls[0].Keys[cred.Id]; !ok {
		t.Fatal("expected the newly generated private key in the manifest")
	}
}

func TestReconcileAutoCreatesAndLinksADeployCredentialForGeneratedDeployAccess(t *testing.T) {
	app := testApp(t)
	user := seedUser(t, app, "deploy@example.com")

	accessColl, err := app.FindCollectionByNameOrId("git_repository_access")
	if err != nil {
		t.Fatal(err)
	}
	access := core.NewRecord(accessColl)
	access.Set("user", user.Id)
	access.Set("provider", "github")
	access.Set("repository", "octo/hello")
	access.Set("purpose", "let the agent push")
	access.Set("credential_mode", "generated_deploy")
	access.Set("requested_access", "read_write")
	access.Set("registration_status", "needs_registration")
	access.Set("status", "pending")
	if err := app.Save(access); err != nil {
		t.Fatal(err)
	}

	mat := &fakeMaterializer{}
	r := &Reconciler{Materializer: mat}
	if err := r.ReconcileUser(context.Background(), app, user.Id); err != nil {
		t.Fatal(err)
	}

	gotAccess, err := app.FindRecordById("git_repository_access", access.Id)
	if err != nil {
		t.Fatal(err)
	}
	credID := gotAccess.GetString("credential")
	if credID == "" {
		t.Fatal("expected a credential to be linked")
	}
	if gotAccess.GetString("status") != "ready" {
		t.Fatalf("access status = %q, want ready", gotAccess.GetString("status"))
	}

	cred, err := app.FindRecordById("git_ssh_credentials", credID)
	if err != nil {
		t.Fatal(err)
	}
	if cred.GetString("kind") != "deploy" || cred.GetString("status") != "ready" {
		t.Fatalf("unexpected credential state: kind=%q status=%q", cred.GetString("kind"), cred.GetString("status"))
	}

	if len(mat.calls) == 0 {
		t.Fatal("expected the materializer to be called")
	}
	last := mat.calls[len(mat.calls)-1]
	if !strings.Contains(string(last.Config), "Host pcgit-"+access.Id) {
		t.Fatalf("rendered config missing the access host block: %s", last.Config)
	}
	if !strings.Contains(string(last.KnownHosts), "github.com") {
		t.Fatalf("known_hosts missing github.com: %s", last.KnownHosts)
	}
}

func TestReconcileLeavesAccessPendingUntilItsCredentialIsReady(t *testing.T) {
	app := testApp(t)
	user := seedUser(t, app, "pending@example.com")

	credColl, _ := app.FindCollectionByNameOrId("git_ssh_credentials")
	cred := core.NewRecord(credColl)
	cred.Set("user", user.Id)
	cred.Set("label", "acct")
	cred.Set("kind", "account")
	cred.Set("source", "imported") // reconciler marks imported credentials as error, not ready
	cred.Set("algorithm", "ed25519")
	cred.Set("status", "pending")
	if err := app.Save(cred); err != nil {
		t.Fatal(err)
	}

	accessColl, _ := app.FindCollectionByNameOrId("git_repository_access")
	access := core.NewRecord(accessColl)
	access.Set("user", user.Id)
	access.Set("provider", "gitlab")
	access.Set("repository", "octo/hello")
	access.Set("purpose", "read the repo")
	access.Set("credential_mode", "existing_account")
	access.Set("credential", cred.Id)
	access.Set("requested_access", "read_only")
	access.Set("registration_status", "needs_registration")
	access.Set("status", "pending")
	if err := app.Save(access); err != nil {
		t.Fatal(err)
	}

	mat := &fakeMaterializer{}
	r := &Reconciler{Materializer: mat}
	if err := r.ReconcileUser(context.Background(), app, user.Id); err != nil {
		t.Fatal(err)
	}

	gotAccess, err := app.FindRecordById("git_repository_access", access.Id)
	if err != nil {
		t.Fatal(err)
	}
	if gotAccess.GetString("status") != "pending" {
		t.Fatalf("access status = %q, want pending (credential never became ready)", gotAccess.GetString("status"))
	}

	gotCred, err := app.FindRecordById("git_ssh_credentials", cred.Id)
	if err != nil {
		t.Fatal(err)
	}
	if gotCred.GetString("status") != "error" {
		t.Fatalf("credential status = %q, want error", gotCred.GetString("status"))
	}
}

func TestReconcileIsANoopWhenNothingIsPending(t *testing.T) {
	app := testApp(t)
	user := seedUser(t, app, "noop@example.com")

	mat := &fakeMaterializer{}
	r := &Reconciler{Materializer: mat}
	if err := r.ReconcileUser(context.Background(), app, user.Id); err != nil {
		t.Fatal(err)
	}
	if len(mat.calls) != 0 {
		t.Fatalf("expected no materializer calls, got %d", len(mat.calls))
	}
}
