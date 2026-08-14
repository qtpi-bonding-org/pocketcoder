package releaseidentity

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/pocketbase/pocketbase/tests"
	_ "github.com/qtpi-bonding-org/pocketcoder/backend/pb_migrations"
)

const testCatalog = `{
  "schemaVersion": 1,
  "defaultHarness": "goose",
  "harnesses": [
    {"id":"goose","composeService":"goose-harness-image","imageRepository":"pocketcoder-harness-goose","upstreamVersion":"1.43.0"},
    {"id":"claude-code","composeService":"claude-code-harness-image","imageRepository":"pocketcoder-harness-claude-code","upstreamVersion":"2.1.221"},
    {"id":"codex","composeService":"codex-harness-image","imageRepository":"pocketcoder-harness-codex","upstreamVersion":"0.146.0"},
    {"id":"opencode","composeService":"opencode-harness-image","imageRepository":"pocketcoder-harness-opencode","upstreamVersion":"1.18.11"}
  ]
}`

func writeCatalog(t *testing.T, contents string) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "harnesses.json")
	if err := os.WriteFile(path, []byte(contents), 0o600); err != nil {
		t.Fatal(err)
	}
	return path
}

func TestSyncHarnessImagesUsesReleaseCommit(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(app.Cleanup)
	release := "0123456789abcdef0123456789abcdef01234567"
	if err := SyncHarnessImages(app, writeCatalog(t, testCatalog), release); err != nil {
		t.Fatal(err)
	}
	goose, err := app.FindFirstRecordByFilter("harnesses", "cli_id = 'goose'", nil)
	if err != nil {
		t.Fatal(err)
	}
	if got, want := goose.GetString("container_image"), "pocketcoder-harness-goose:"+release; got != want {
		t.Fatalf("container_image = %q, want %q", got, want)
	}
}

func TestSyncHarnessImagesRejectsInvalidRelease(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(app.Cleanup)
	if err := SyncHarnessImages(app, writeCatalog(t, testCatalog), "latest"); err == nil {
		t.Fatal("expected invalid release identity to fail")
	}
}

func TestLoadCatalogRejectsUnknownFields(t *testing.T) {
	path := writeCatalog(t, `{"schemaVersion":1,"defaultHarness":"goose","harnesses":[],"extra":true}`)
	if _, err := LoadCatalog(path); err == nil {
		t.Fatal("expected unknown catalog field to fail")
	}
}

func TestLoadCatalogRequiresHarnessUpstreamVersion(t *testing.T) {
	path := writeCatalog(t, `{"schemaVersion":1,"defaultHarness":"goose","harnesses":[{"id":"goose","composeService":"goose-harness-image","imageRepository":"pocketcoder-harness-goose"}]}`)
	if _, err := LoadCatalog(path); err == nil {
		t.Fatal("expected harness without upstreamVersion to fail")
	}
}
