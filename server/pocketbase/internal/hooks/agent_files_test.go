package hooks

import (
	"archive/tar"
	"io"
	"strings"
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
)

func TestTarArchiveContainsMaterializedFiles(t *testing.T) {
	r, err := tarArchive(map[string]string{
		"AGENTS.md":                      "follow these rules",
		".agents/skills/review/SKILL.md": "---\nname: review\n---\nReview code.",
		".claude/skills/review/SKILL.md": "---\nname: review\n---\nReview code.",
	})
	if err != nil {
		t.Fatal(err)
	}
	trr := tar.NewReader(r)
	seen := map[string]string{}
	for {
		h, err := trr.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			t.Fatal(err)
		}
		body, err := io.ReadAll(trr)
		if err != nil {
			t.Fatal(err)
		}
		seen[h.Name] = string(body)
	}
	if seen["AGENTS.md"] != "follow these rules" || seen[".agents/skills/review/SKILL.md"] == "" || seen[".claude/skills/review/SKILL.md"] == "" {
		t.Fatalf("unexpected archive contents: %#v", seen)
	}
}

func TestTarArchiveRejectsTraversal(t *testing.T) {
	if _, err := tarArchive(map[string]string{"../AGENTS.md": "unsafe"}); err == nil {
		t.Fatal("expected traversal path to be rejected")
	}
}

func TestValidSkillName(t *testing.T) {
	for _, name := range []string{"review", "code-review-2"} {
		if !validSkillName(name) {
			t.Errorf("validSkillName(%q) = false", name)
		}
	}
	for _, name := range []string{"", "Review", "bad_name", "../bad", "a--b", "-bad"} {
		if validSkillName(name) {
			t.Errorf("validSkillName(%q) = true", name)
		}
	}
}

func TestSkillMaterializationRootUsesWorkspaceRelativeProjectPath(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()
	collection, err := app.FindCollectionByNameOrId("skills")
	if err != nil {
		t.Fatal(err)
	}
	skill := core.NewRecord(collection)
	skill.Set("name", "review")
	skill.Set("metadata", map[string]any{"projectDir": "/workspace/projects/app"})

	root, err := skillMaterializationRoot(skill)
	if err != nil {
		t.Fatal(err)
	}
	if root != "projects/app" {
		t.Fatalf("root = %q, want projects/app", root)
	}

	skill.Set("metadata", map[string]any{"projectDir": "/tmp/outside"})
	if _, err := skillMaterializationRoot(skill); err == nil {
		t.Fatal("expected out-of-workspace projectDir to fail")
	}
}

func TestGitRemotesDocOnlyIncludesThisUsersReadyAccess(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	usersColl, err := app.FindCollectionByNameOrId("users")
	if err != nil {
		t.Fatal(err)
	}
	newUser := func(email string) *core.Record {
		u := core.NewRecord(usersColl)
		u.SetEmail(email)
		u.SetPassword("password1234")
		if err := app.Save(u); err != nil {
			t.Fatal(err)
		}
		return u
	}
	user := newUser("remotes-doc@example.com")
	otherUser := newUser("other-user@example.com")

	accessColl, err := app.FindCollectionByNameOrId("git_repository_access")
	if err != nil {
		t.Fatal(err)
	}
	newAccess := func(owner *core.Record, repo, status string) {
		a := core.NewRecord(accessColl)
		a.Set("user", owner.Id)
		a.Set("provider", "github")
		a.Set("repository", repo)
		a.Set("purpose", "test")
		a.Set("credential_mode", "generated_deploy")
		a.Set("requested_access", "read_only")
		a.Set("registration_status", "needs_registration")
		a.Set("status", status)
		if err := app.Save(a); err != nil {
			t.Fatal(err)
		}
	}
	newAccess(user, "octo/ready-repo", "ready")
	newAccess(user, "octo/pending-repo", "pending")
	newAccess(otherUser, "octo/someone-elses-repo", "ready")

	doc, err := gitRemotesDoc(app, user.Id)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(doc, "octo/ready-repo") {
		t.Fatalf("expected the ready access to be included: %s", doc)
	}
	if strings.Contains(doc, "pending-repo") {
		t.Fatalf("expected the pending access to be excluded: %s", doc)
	}
	if strings.Contains(doc, "someone-elses-repo") {
		t.Fatalf("expected another user's access to be excluded: %s", doc)
	}
}

func TestGitRemotesDocIsEmptyWithNoReadyAccess(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()
	usersColl, err := app.FindCollectionByNameOrId("users")
	if err != nil {
		t.Fatal(err)
	}
	u := core.NewRecord(usersColl)
	u.SetEmail("no-remotes@example.com")
	u.SetPassword("password1234")
	if err := app.Save(u); err != nil {
		t.Fatal(err)
	}

	doc, err := gitRemotesDoc(app, u.Id)
	if err != nil {
		t.Fatal(err)
	}
	if doc != "" {
		t.Fatalf("expected an empty doc for a user with no access, got %q", doc)
	}
}
