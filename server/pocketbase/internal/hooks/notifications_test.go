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
func withCapturingRelay(t *testing.T) (lastBody func() map[string]any, lastHeader func() http.Header) {
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
	lastBody, _ := withCapturingRelay(t)

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
	lastBody, _ := withCapturingRelay(t)

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

func TestSendPushNotificationSendsPerUserDerivedRelaySecret(t *testing.T) {
	t.Setenv("PN_RELAY_SECRET", "test-root-secret")
	app, err := newNotificationTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()
	lastBody, lastHeader := withCapturingRelay(t)

	user := notificationTestUser(t, app)
	liveActivityTestDevice(t, app, user.Id)

	if err := SendPushNotification(app, user.Id, "title", "body", "chat_reply", ""); err != nil {
		t.Fatalf("SendPushNotification returned error: %v", err)
	}

	if lastBody() == nil {
		t.Fatal("relay never received a request")
	}
	got := lastHeader().Get("X-Relay-Secret")
	want := relaySecretFor("test-root-secret", user.Id)
	if got != want {
		t.Fatalf("X-Relay-Secret = %q, want the per-user derived secret %q", got, want)
	}
	if got == "test-root-secret" {
		t.Fatal("X-Relay-Secret was sent as the raw root secret, not derived per user")
	}
}

// TestSendPushNotificationTwoUsersOnSameDeploymentGetDifferentSecrets proves
// the actual user-visible bug this plan fixes: two PocketBase accounts on
// the same deployment (same PN_RELAY_SECRET) must no longer collide on the
// same derived secret, which is what caused the second account's push
// requests to be permanently rejected by push-relay's tenant binding.
func TestSendPushNotificationTwoUsersOnSameDeploymentGetDifferentSecrets(t *testing.T) {
	t.Setenv("PN_RELAY_SECRET", "shared-deployment-secret")
	app, err := newNotificationTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()
	lastBody, lastHeader := withCapturingRelay(t)

	// Uses liveActivityTestUser (defined in live_activities_test.go, same
	// package) rather than notificationTestUser, since that helper takes
	// an explicit email and this test needs two distinct accounts --
	// notificationTestUser hardcodes one fixed email and creating a
	// second user with it would fail on a duplicate-email constraint.
	userA := liveActivityTestUser(t, app, "push-multi-a@example.com")
	liveActivityTestDevice(t, app, userA.Id)
	if err := SendPushNotification(app, userA.Id, "title", "body", "chat_reply", ""); err != nil {
		t.Fatalf("SendPushNotification for userA returned error: %v", err)
	}
	if lastBody() == nil {
		t.Fatal("relay never received a request for userA")
	}
	secretA := lastHeader().Get("X-Relay-Secret")

	userB := liveActivityTestUser(t, app, "push-multi-b@example.com")
	liveActivityTestDevice(t, app, userB.Id)
	if err := SendPushNotification(app, userB.Id, "title", "body", "chat_reply", ""); err != nil {
		t.Fatalf("SendPushNotification for userB returned error: %v", err)
	}
	if lastBody() == nil {
		t.Fatal("relay never received a request for userB")
	}
	secretB := lastHeader().Get("X-Relay-Secret")

	if secretA == secretB {
		t.Fatalf("userA and userB on the same deployment got the same X-Relay-Secret (%q) -- this is the bug this fix addresses", secretA)
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
