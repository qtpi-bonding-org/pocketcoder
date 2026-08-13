package api

import (
	"fmt"
	"net/http"
	"strings"
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	_ "github.com/qtpi-bonding-org/pocketcoder/backend/pb_migrations"
)

func TestSkillsCreateAllowsAuthenticatedNonAdminAndKeepsGlobalUserOwned(t *testing.T) {
	headers := map[string]string{"Content-Type": "application/json"}
	userID := ""
	scenario := tests.ApiScenario{
		Name:   "authenticated user creates a user-global skill",
		Method: http.MethodPost,
		URL:    "/api/pocketcoder/skills/create",
		Body: strings.NewReader(`{
			"name":"review-code",
			"description":"Review code",
			"content":"Check the change.",
			"scope":{"scope":"global"}
		}`),
		Headers:        headers,
		ExpectedStatus: http.StatusOK,
		ExpectedContent: []string{
			`"global":true`,
			`"system":false`,
		},
		BeforeTestFunc: func(t testing.TB, app *tests.TestApp, e *core.ServeEvent) {
			RegisterSkillsApi(app, e, nil)
			user := newSkillTestUser(t, app, "skill-user@example.com", "user")
			userID = user.Id
			token, err := user.NewAuthToken()
			if err != nil {
				t.Fatal(err)
			}
			headers["Authorization"] = token
		},
		AfterTestFunc: func(t testing.TB, app *tests.TestApp, _ *http.Response) {
			record, err := app.FindFirstRecordByFilter("skills", "name = 'review-code'", nil)
			if err != nil {
				t.Fatal(err)
			}
			if record.GetString("user") != userID || record.GetBool("is_system") {
				t.Fatalf("skill owner/system = %q/%v, want %q/false", record.GetString("user"), record.GetBool("is_system"), userID)
			}
		},
	}
	scenario.Test(t)
}

func TestSkillResponseDistinguishesProjectAndSystemSkills(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()
	collection, err := app.FindCollectionByNameOrId("skills")
	if err != nil {
		t.Fatal(err)
	}

	project := core.NewRecord(collection)
	project.Set("metadata", map[string]any{"projectDir": "/workspace/project"})
	projectResponse := skillResponse(project)
	if projectResponse["global"] != false || projectResponse["system"] != false {
		t.Fatalf("project response = %#v", projectResponse)
	}

	system := core.NewRecord(collection)
	system.Set("is_system", true)
	systemResponse := skillResponse(system)
	if systemResponse["global"] != true || systemResponse["system"] != true {
		t.Fatalf("system response = %#v", systemResponse)
	}
}

func TestSkillsUpdateRejectsAnotherUsersSkill(t *testing.T) {
	headers := map[string]string{"Content-Type": "application/json"}
	var scenario tests.ApiScenario
	scenario = tests.ApiScenario{
		Name:           "user cannot update another user's skill",
		Method:         http.MethodPost,
		URL:            "/api/pocketcoder/skills/update",
		Headers:        headers,
		ExpectedStatus: http.StatusNotFound,
		ExpectedContent: []string{
			`"error":"skill not found"`,
		},
		BeforeTestFunc: func(t testing.TB, app *tests.TestApp, e *core.ServeEvent) {
			RegisterSkillsApi(app, e, nil)
			owner := newSkillTestUser(t, app, "skill-owner@example.com", "user")
			requester := newSkillTestUser(t, app, "skill-requester@example.com", "user")
			collection, err := app.FindCollectionByNameOrId("skills")
			if err != nil {
				t.Fatal(err)
			}
			record := core.NewRecord(collection)
			record.Set("user", owner.Id)
			record.Set("name", "owned-skill")
			record.Set("description", "original")
			record.Set("content", "original")
			record.Set("active", true)
			if err := app.Save(record); err != nil {
				t.Fatal(err)
			}
			scenario.Body = strings.NewReader(fmt.Sprintf(`{"path":%q,"name":"owned-skill","description":"changed","content":"changed"}`, record.Id))
			token, err := requester.NewAuthToken()
			if err != nil {
				t.Fatal(err)
			}
			headers["Authorization"] = token
		},
		AfterTestFunc: func(t testing.TB, app *tests.TestApp, _ *http.Response) {
			record, err := app.FindFirstRecordByFilter("skills", "name = 'owned-skill'", nil)
			if err != nil {
				t.Fatal(err)
			}
			if record.GetString("description") != "original" || record.GetString("content") != "original" {
				t.Fatal("another user's skill was modified")
			}
		},
	}
	scenario.Test(t)
}

func newSkillTestUser(t testing.TB, app core.App, email, role string) *core.Record {
	t.Helper()
	collection, err := app.FindCollectionByNameOrId("_pb_users_auth_")
	if err != nil {
		t.Fatal(err)
	}
	user := core.NewRecord(collection)
	user.SetEmail(email)
	user.SetPassword("password12345")
	user.Set("role", role)
	if err := app.Save(user); err != nil {
		t.Fatal(err)
	}
	return user
}
