package hooks

import (
	"net/http"
	"os"
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

// withCapturingRelay reuses live_activities_test.go's withFakeRelayCapturing
// (same package) for the PN_URL/body-capture plumbing, adding the PN_PROVIDER
// gate that dispatchToDevices checks before selecting FcmRelayProvider --
// withFakeRelayCapturing's own callers (dispatchLiveActivityUpdate) call
// SendLiveActivityUpdate directly and never go through that gate, so it has
// no reason to set PN_PROVIDER itself.
func withCapturingRelay(t *testing.T) (lastBody func() map[string]any) {
	t.Helper()
	prevMode, hadMode := os.LookupEnv("PN_PROVIDER")
	os.Setenv("PN_PROVIDER", "FCM")
	t.Cleanup(func() {
		if hadMode {
			os.Setenv("PN_PROVIDER", prevMode)
		} else {
			os.Unsetenv("PN_PROVIDER")
		}
	})
	return withFakeRelayCapturing(t, http.StatusOK)
}

func TestSendPushNotificationWithExtraIncludesExtraFields(t *testing.T) {
	app, err := newNotificationTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()
	lastBody := withCapturingRelay(t)

	user := notificationTestUser(t, app)
	liveActivityTestDevice(t, app, user.Id)

	if err := SendPushNotificationWithExtra(app, user.Id, "Signature required", "Run `rm -rf node_modules`?", "permission", "", map[string]string{
		"request_id": "req-123",
		"permission": `{"requestId":"req-123","status":"pending","options":[{"optionId":"allow_once","name":"Allow","kind":"allow_once"}]}`,
	}); err != nil {
		t.Fatalf("SendPushNotificationWithExtra returned error: %v", err)
	}

	body := lastBody()
	if body == nil {
		t.Fatal("relay never received a request")
	}
	if body["request_id"] != "req-123" {
		t.Fatalf("request_id = %v, want %q", body["request_id"], "req-123")
	}
	if body["permission"] == nil {
		t.Fatal("permission field was not forwarded")
	}
}

func TestSendPushNotificationHasNoExtraFields(t *testing.T) {
	app, err := newNotificationTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()
	lastBody := withCapturingRelay(t)

	user := notificationTestUser(t, app)
	liveActivityTestDevice(t, app, user.Id)

	if err := SendPushNotification(app, user.Id, "Hi", "hello", "chat_reply", ""); err != nil {
		t.Fatalf("SendPushNotification returned error: %v", err)
	}

	body := lastBody()
	if body == nil {
		t.Fatal("relay never received a request")
	}
	if _, present := body["request_id"]; present {
		t.Fatalf("request_id present on a plain SendPushNotification call: %v", body["request_id"])
	}
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
