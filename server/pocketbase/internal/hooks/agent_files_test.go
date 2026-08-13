package hooks

import (
	"archive/tar"
	"io"
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
