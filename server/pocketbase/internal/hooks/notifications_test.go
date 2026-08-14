package hooks

import (
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	_ "github.com/qtpi-bonding-org/pocketcoder/backend/pb_migrations"
)

func notificationRule(t *testing.T, app core.App, userID string, rules map[string]bool) {
	t.Helper()
	coll, err := app.FindCollectionByNameOrId("notification_rules")
	if err != nil {
		t.Fatal(err)
	}
	r := core.NewRecord(coll)
	r.Set("user", userID)
	r.Set("rules", rules)
	if err := app.Save(r); err != nil {
		t.Fatal(err)
	}
}

func TestSendPushNotificationDisabledTypeIsNoOp(t *testing.T) {
	app, err := newNotificationTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()
	user := notificationTestUser(t, app)
	notificationRule(t, app, user.Id, map[string]bool{"schedule": false})
	if err := SendPushNotification(app, user.Id, "title", "body", "schedule", ""); err != nil {
		t.Fatalf("disabled notification returned error: %v", err)
	}
}

func TestSendPushNotificationNoRulesNoDevicesIsNoOp(t *testing.T) {
	app, err := newNotificationTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()
	user := notificationTestUser(t, app)
	if err := SendPushNotification(app, user.Id, "title", "body", "other", ""); err != nil {
		t.Fatalf("no-device notification returned error: %v", err)
	}
}

func newNotificationTestApp() (*tests.TestApp, error) {
	// Kept local so this package's tests don't depend on helpers in another package.
	return tests.NewTestApp()
}

func notificationTestUser(t *testing.T, app core.App) *core.Record {
	t.Helper()
	coll, err := app.FindCollectionByNameOrId("_pb_users_auth_")
	if err != nil {
		t.Fatal(err)
	}
	u := core.NewRecord(coll)
	u.SetEmail("notifications-test@example.com")
	u.SetPassword("password123")
	if err := app.Save(u); err != nil {
		t.Fatal(err)
	}
	return u
}
