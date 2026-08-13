package api

import (
	"net/http"
	"os"
	"path/filepath"
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
)

func writeReleaseFixture(t *testing.T, name, body string) {
	t.Helper()
	if err := os.WriteFile(
		filepath.Join(os.Getenv("POCKETCODER_RELEASE_STATE_DIR"), name),
		[]byte(body),
		0o600,
	); err != nil {
		t.Fatal(err)
	}
}

func releaseTestUser(t testing.TB, app core.App) *core.Record {
	t.Helper()
	collection, err := app.FindCollectionByNameOrId("_pb_users_auth_")
	if err != nil {
		t.Fatal(err)
	}
	user := core.NewRecord(collection)
	user.SetEmail("release-status@example.com")
	user.SetPassword("password123")
	if err := app.Save(user); err != nil {
		t.Fatal(err)
	}
	return user
}

func TestReleaseCompatibilityExposesContractsWithoutIdentity(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("POCKETCODER_RELEASE_STATE_DIR", dir)
	writeReleaseFixture(t, "current.json", `{
		"releaseDigest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
		"sourceCommit":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
		"serverVersion":"1.2.3",
		"dataVersion":3,
		"deploymentContractVersion":2
	}`)

	scenario := tests.ApiScenario{
		Name:           "public compatibility contains only contracts",
		Method:         http.MethodGet,
		URL:            "/api/pocketcoder/compatibility",
		ExpectedStatus: 200,
		ExpectedContent: []string{
			`"serverApiVersion":1`,
			`"appContractVersion":1`,
			`"dataVersion":3`,
			`"deploymentContractVersion":2`,
		},
		NotExpectedContent: []string{"releaseDigest", "sourceCommit", "1.2.3"},
		BeforeTestFunc: func(_ testing.TB, _ *tests.TestApp, e *core.ServeEvent) {
			RegisterReleaseStatusApi(nil, e)
		},
	}
	scenario.Test(t)
}

func TestReleaseCapabilitiesRequiresAuth(t *testing.T) {
	t.Setenv("POCKETCODER_RELEASE_STATE_DIR", t.TempDir())
	scenario := tests.ApiScenario{
		Name:            "release capabilities requires auth",
		Method:          http.MethodGet,
		URL:             "/api/pocketcoder/capabilities",
		ExpectedStatus:  401,
		ExpectedContent: []string{"requires valid record authorization token"},
		BeforeTestFunc: func(_ testing.TB, _ *tests.TestApp, e *core.ServeEvent) {
			RegisterReleaseStatusApi(nil, e)
		},
	}
	scenario.Test(t)
}

func TestReleaseCapabilitiesCarriesCachedMetadataStatus(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("POCKETCODER_RELEASE_STATE_DIR", dir)
	writeReleaseFixture(t, "current.json", `{
		"releaseDigest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
		"sourceCommit":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
		"serverVersion":"1.0.0",
		"dataVersion":1,
		"deploymentContractVersion":1
	}`)
	writeReleaseFixture(t, "metadata-status.json", `{
		"schemaVersion":1,
		"status":"update-available",
		"checkedAt":"2026-08-12T20:00:00Z",
		"availableVersion":"1.1.0",
		"availableDataVersion":2,
		"downloadBytes":123,
		"requiredDiskBytes":456,
		"normalRollbackAvailableAfterSuccess":false
	}`)

	headers := map[string]string{}
	scenario := tests.ApiScenario{
		Name:           "authenticated capabilities includes cached release status",
		Method:         http.MethodGet,
		URL:            "/api/pocketcoder/capabilities",
		Headers:        headers,
		ExpectedStatus: 200,
		ExpectedContent: []string{
			`"releaseDigest":"aaaaaaaa`,
			`"status":"update-available"`,
			`"availableVersion":"1.1.0"`,
			`"requiredDiskBytes":456`,
		},
		BeforeTestFunc: func(t testing.TB, app *tests.TestApp, e *core.ServeEvent) {
			RegisterReleaseStatusApi(nil, e)
			user := releaseTestUser(t, app)
			token, err := user.NewAuthToken()
			if err != nil {
				t.Fatal(err)
			}
			headers["Authorization"] = token
		},
	}
	scenario.Test(t)
}
