package hooks

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"sync"
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	_ "github.com/qtpi-bonding-org/pocketcoder/backend/pb_migrations"
)

// withFakeRelay points PN_URL at a local httptest.Server for the duration of
// the test, restoring the previous value afterward, and returns the number
// of POSTs it received (as a func, since the count keeps growing).
func withFakeRelay(t *testing.T, status int) (count func() int) {
	t.Helper()
	var mu sync.Mutex
	var n int
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		n++
		mu.Unlock()
		w.WriteHeader(status)
	}))
	t.Cleanup(srv.Close)
	prev, hadPrev := os.LookupEnv("PN_URL")
	os.Setenv("PN_URL", srv.URL)
	t.Cleanup(func() {
		if hadPrev {
			os.Setenv("PN_URL", prev)
		} else {
			os.Unsetenv("PN_URL")
		}
	})
	return func() int {
		mu.Lock()
		defer mu.Unlock()
		return n
	}
}

// withFakeRelayCapturing is like withFakeRelay but hands back the JSON body
// of the most recent POST, so tests can assert on payload shape (user_id,
// fcm_token) rather than just delivery/no-delivery.
func withFakeRelayCapturing(t *testing.T, status int) (lastBody func() map[string]any) {
	t.Helper()
	var mu sync.Mutex
	var body map[string]any
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		b, _ := io.ReadAll(r.Body)
		var parsed map[string]any
		_ = json.Unmarshal(b, &parsed)
		mu.Lock()
		body = parsed
		mu.Unlock()
		w.WriteHeader(status)
	}))
	t.Cleanup(srv.Close)
	prev, hadPrev := os.LookupEnv("PN_URL")
	os.Setenv("PN_URL", srv.URL)
	t.Cleanup(func() {
		if hadPrev {
			os.Setenv("PN_URL", prev)
		} else {
			os.Unsetenv("PN_URL")
		}
	})
	return func() map[string]any {
		mu.Lock()
		defer mu.Unlock()
		return body
	}
}

func liveActivityTestUser(t *testing.T, app core.App, email string) *core.Record {
	t.Helper()
	coll, err := app.FindCollectionByNameOrId("_pb_users_auth_")
	if err != nil {
		t.Fatal(err)
	}
	u := core.NewRecord(coll)
	u.SetEmail(email)
	u.SetPassword("password123")
	if err := app.Save(u); err != nil {
		t.Fatal(err)
	}
	return u
}

func liveActivityTestDevice(t *testing.T, app core.App, userID string) *core.Record {
	t.Helper()
	coll, err := app.FindCollectionByNameOrId("devices")
	if err != nil {
		t.Fatal(err)
	}
	d := core.NewRecord(coll)
	d.Set("user", userID)
	d.Set("name", "test device")
	d.Set("push_token", "test-token")
	d.Set("push_service", "fcm")
	d.Set("is_active", true)
	if err := app.Save(d); err != nil {
		t.Fatal(err)
	}
	return d
}

func liveActivityTestChat(t *testing.T, app core.App, userID string) *core.Record {
	t.Helper()
	coll, err := app.FindCollectionByNameOrId("chats")
	if err != nil {
		t.Fatal(err)
	}
	c := core.NewRecord(coll)
	c.Set("user", userID)
	c.Set("title", "Test Chat")
	if err := app.Save(c); err != nil {
		t.Fatal(err)
	}
	return c
}

func liveActivityTestRow(t *testing.T, app core.App, userID, deviceID, chatID, status string) *core.Record {
	t.Helper()
	coll, err := app.FindCollectionByNameOrId("live_activities")
	if err != nil {
		t.Fatal(err)
	}
	r := core.NewRecord(coll)
	r.Set("user", userID)
	r.Set("device", deviceID)
	r.Set("chat", chatID)
	r.Set("platform", "ios")
	r.Set("status", status)
	r.Set("activity_push_token", "activity-token")
	r.Set("content_state_version", 1)
	if err := app.Save(r); err != nil {
		t.Fatal(err)
	}
	return r
}

// PN_URL is deliberately left unset in these tests -- dispatchLiveActivityUpdate
// treats an empty relay URL as a no-op (matching FcmRelayProvider's existing
// "not configured, skip" behavior), so these tests exercise the row-state
// transitions without needing a live relay.

func TestNotifyRunStartedOnlyDispatchesActiveRowsForThatChat(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()
	calls := withFakeRelay(t, http.StatusOK)

	user := liveActivityTestUser(t, app, "la-started-1@example.com")
	device := liveActivityTestDevice(t, app, user.Id)
	chatA := liveActivityTestChat(t, app, user.Id)
	chatB := liveActivityTestChat(t, app, user.Id)
	rowA := liveActivityTestRow(t, app, user.Id, device.Id, chatA.Id, "active")
	liveActivityTestRow(t, app, user.Id, device.Id, chatB.Id, "active")
	rowEnded := liveActivityTestRow(t, app, user.Id, device.Id, chatA.Id, "ended")

	if err := NotifyRunStarted(app, chatA.Id); err != nil {
		t.Fatalf("NotifyRunStarted returned error: %v", err)
	}

	if got := calls(); got != 1 {
		t.Fatalf("relay received %d POSTs, want exactly 1 (only chatA's active row)", got)
	}

	reloadedA, err := app.FindRecordById("live_activities", rowA.Id)
	if err != nil {
		t.Fatal(err)
	}
	if reloadedA.GetInt("content_state_version") != 2 {
		t.Fatalf("rowA content_state_version = %d, want 2 (bumped by dispatch)", reloadedA.GetInt("content_state_version"))
	}

	reloadedEnded, err := app.FindRecordById("live_activities", rowEnded.Id)
	if err != nil {
		t.Fatal(err)
	}
	if reloadedEnded.GetInt("content_state_version") != 1 {
		t.Fatalf("rowEnded content_state_version = %d, want 1 (untouched, not active)", reloadedEnded.GetInt("content_state_version"))
	}
}

func TestNotifyRunStartedNoActiveRowsIsNoOp(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	user := liveActivityTestUser(t, app, "la-started-2@example.com")
	chat := liveActivityTestChat(t, app, user.Id)

	if err := NotifyRunStarted(app, chat.Id); err != nil {
		t.Fatalf("NotifyRunStarted with no rows returned error: %v", err)
	}
}

func TestNotifyRunFinishedEndsActiveRowsAndSetsTimestamps(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	user := liveActivityTestUser(t, app, "la-finished-1@example.com")
	device := liveActivityTestDevice(t, app, user.Id)
	chat := liveActivityTestChat(t, app, user.Id)
	row := liveActivityTestRow(t, app, user.Id, device.Id, chat.Id, "active")

	if err := NotifyRunFinished(app, chat.Id, "completed"); err != nil {
		t.Fatalf("NotifyRunFinished returned error: %v", err)
	}

	reloaded, err := app.FindRecordById("live_activities", row.Id)
	if err != nil {
		t.Fatal(err)
	}
	if reloaded.GetString("status") != "ended" {
		t.Fatalf("status = %q, want %q", reloaded.GetString("status"), "ended")
	}
	if reloaded.GetDateTime("ended_at").IsZero() {
		t.Fatal("ended_at was not set")
	}
	if reloaded.GetDateTime("last_push_at").IsZero() {
		t.Fatal("last_push_at was not set")
	}
}

func TestNotifyRunFinishedDoesNotTouchAlreadyEndedRows(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	user := liveActivityTestUser(t, app, "la-finished-2@example.com")
	device := liveActivityTestDevice(t, app, user.Id)
	chat := liveActivityTestChat(t, app, user.Id)
	row := liveActivityTestRow(t, app, user.Id, device.Id, chat.Id, "ended")

	if err := NotifyRunFinished(app, chat.Id, "completed"); err != nil {
		t.Fatalf("NotifyRunFinished returned error: %v", err)
	}

	reloaded, err := app.FindRecordById("live_activities", row.Id)
	if err != nil {
		t.Fatal(err)
	}
	if !reloaded.GetDateTime("ended_at").IsZero() {
		t.Fatal("ended_at was set on an already-ended row, should stay untouched")
	}
}

func TestChatUnmonitorEndsActiveLiveActivities(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()
	RegisterLiveActivityHooks(app)

	user := liveActivityTestUser(t, app, "la-unmonitor@example.com")
	device := liveActivityTestDevice(t, app, user.Id)
	chat := liveActivityTestChat(t, app, user.Id)
	chat.Set("monitored", true)
	if err := app.Save(chat); err != nil {
		t.Fatal(err)
	}
	row := liveActivityTestRow(t, app, user.Id, device.Id, chat.Id, "active")

	// Re-fetch fresh from DB, matching how a real HTTP PATCH handler would
	// load the record -- Original() only reflects the pre-*this*-save
	// baseline correctly starting from a fresh load, not a reused in-memory
	// object carried across multiple Save() calls in the same test.
	fresh, err := app.FindRecordById("chats", chat.Id)
	if err != nil {
		t.Fatal(err)
	}
	fresh.Set("monitored", false)
	if err := app.Save(fresh); err != nil {
		t.Fatal(err)
	}

	reloaded, err := app.FindRecordById("live_activities", row.Id)
	if err != nil {
		t.Fatal(err)
	}
	if reloaded.GetString("status") != "ended" {
		t.Fatalf("status after unmonitor = %q, want %q", reloaded.GetString("status"), "ended")
	}
}

func TestChatArchiveEndsActiveLiveActivities(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()
	RegisterLiveActivityHooks(app)

	user := liveActivityTestUser(t, app, "la-archive@example.com")
	device := liveActivityTestDevice(t, app, user.Id)
	chat := liveActivityTestChat(t, app, user.Id)
	row := liveActivityTestRow(t, app, user.Id, device.Id, chat.Id, "active")

	chat.Set("archived", true)
	if err := app.Save(chat); err != nil {
		t.Fatal(err)
	}

	reloaded, err := app.FindRecordById("live_activities", row.Id)
	if err != nil {
		t.Fatal(err)
	}
	if reloaded.GetString("status") != "ended" {
		t.Fatalf("status after archive = %q, want %q", reloaded.GetString("status"), "ended")
	}
}

func TestLiveActivityCreateRejectsDeviceChatUserMismatch(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()
	RegisterLiveActivityHooks(app)

	owner := liveActivityTestUser(t, app, "la-owner@example.com")
	attacker := liveActivityTestUser(t, app, "la-attacker@example.com")
	ownerDevice := liveActivityTestDevice(t, app, owner.Id)
	ownerChat := liveActivityTestChat(t, app, owner.Id)

	coll, err := app.FindCollectionByNameOrId("live_activities")
	if err != nil {
		t.Fatal(err)
	}
	// attacker points a row at the owner's own chat/device but claims the
	// row's own `user` field as themselves -- this is exactly what the
	// collection's createRule alone (only checking `user = @request.auth.id`)
	// would otherwise let through.
	r := core.NewRecord(coll)
	r.Set("user", attacker.Id)
	r.Set("device", ownerDevice.Id)
	r.Set("chat", ownerChat.Id)
	r.Set("platform", "ios")
	r.Set("status", "active")
	r.Set("content_state_version", 1)
	if err := app.Save(r); err == nil {
		t.Fatal("expected device/chat/user mismatch to be rejected, got no error")
	}
}

func TestLiveActivityCreateAllowsMatchingOwner(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()
	RegisterLiveActivityHooks(app)

	user := liveActivityTestUser(t, app, "la-matching-owner@example.com")
	device := liveActivityTestDevice(t, app, user.Id)
	chat := liveActivityTestChat(t, app, user.Id)

	coll, err := app.FindCollectionByNameOrId("live_activities")
	if err != nil {
		t.Fatal(err)
	}
	r := core.NewRecord(coll)
	r.Set("user", user.Id)
	r.Set("device", device.Id)
	r.Set("chat", chat.Id)
	r.Set("platform", "ios")
	r.Set("status", "active")
	r.Set("content_state_version", 1)
	if err := app.Save(r); err != nil {
		t.Fatalf("expected matching device/chat/user to be accepted, got error: %v", err)
	}
}

func TestDispatchLiveActivityUpdateNoRelayConfiguredIsANoOp(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()
	// PN_URL deliberately left unset -- matches FcmRelayProvider.Send's
	// existing "not configured, skip" convention for the ordinary push path.
	os.Unsetenv("PN_URL")

	user := liveActivityTestUser(t, app, "la-dispatch-1@example.com")
	device := liveActivityTestDevice(t, app, user.Id)
	chat := liveActivityTestChat(t, app, user.Id)
	row := liveActivityTestRow(t, app, user.Id, device.Id, chat.Id, "active")

	if err := dispatchLiveActivityUpdate(app, row, LiveActivityContentState{Status: "running"}); err != nil {
		t.Fatalf("dispatchLiveActivityUpdate with no relay configured returned error: %v", err)
	}
	reloaded, err := app.FindRecordById("live_activities", row.Id)
	if err != nil {
		t.Fatal(err)
	}
	if reloaded.GetString("last_error") != "" {
		t.Fatalf("last_error = %q, want blank when no relay is configured (treated as a no-op send)", reloaded.GetString("last_error"))
	}
	if reloaded.GetInt("content_state_version") != 1 {
		t.Fatalf("content_state_version = %d, want unchanged at 1 (no send happened, nothing to version)", reloaded.GetInt("content_state_version"))
	}
}

func TestDispatchLiveActivityUpdateSetsLastErrorOnRelayFailure(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()
	withFakeRelay(t, http.StatusInternalServerError)

	user := liveActivityTestUser(t, app, "la-dispatch-2@example.com")
	device := liveActivityTestDevice(t, app, user.Id)
	chat := liveActivityTestChat(t, app, user.Id)
	row := liveActivityTestRow(t, app, user.Id, device.Id, chat.Id, "active")

	// dispatchLiveActivityUpdate must never return an error to its caller
	// even when the relay rejects the push -- run-start/run-finish dispatch
	// is fire-and-forget and must not surface delivery failures upward.
	if err := dispatchLiveActivityUpdate(app, row, LiveActivityContentState{Status: "running"}); err != nil {
		t.Fatalf("dispatchLiveActivityUpdate returned error to caller on relay failure: %v", err)
	}
	reloaded, err := app.FindRecordById("live_activities", row.Id)
	if err != nil {
		t.Fatal(err)
	}
	if reloaded.GetString("last_error") == "" {
		t.Fatal("last_error was left blank after a genuine relay failure (500)")
	}
}

func TestDispatchLiveActivityUpdateClearsLastErrorOnSuccess(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()
	withFakeRelay(t, http.StatusOK)

	user := liveActivityTestUser(t, app, "la-dispatch-3@example.com")
	device := liveActivityTestDevice(t, app, user.Id)
	chat := liveActivityTestChat(t, app, user.Id)
	row := liveActivityTestRow(t, app, user.Id, device.Id, chat.Id, "active")
	row.Set("last_error", "stale error from a previous failed attempt")
	if err := app.Save(row); err != nil {
		t.Fatal(err)
	}

	if err := dispatchLiveActivityUpdate(app, row, LiveActivityContentState{Status: "running"}); err != nil {
		t.Fatalf("dispatchLiveActivityUpdate returned error: %v", err)
	}
	reloaded, err := app.FindRecordById("live_activities", row.Id)
	if err != nil {
		t.Fatal(err)
	}
	if reloaded.GetString("last_error") != "" {
		t.Fatalf("last_error = %q, want cleared after a confirmed 2xx delivery", reloaded.GetString("last_error"))
	}
}

func TestDispatchLiveActivityUpdateSendsUserIDAndFCMToken(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()
	lastBody := withFakeRelayCapturing(t, http.StatusOK)

	user := liveActivityTestUser(t, app, "la-dispatch-4@example.com")
	device := liveActivityTestDevice(t, app, user.Id)
	chat := liveActivityTestChat(t, app, user.Id)
	row := liveActivityTestRow(t, app, user.Id, device.Id, chat.Id, "active")

	if err := dispatchLiveActivityUpdate(app, row, LiveActivityContentState{Status: "running"}); err != nil {
		t.Fatalf("dispatchLiveActivityUpdate returned error: %v", err)
	}

	body := lastBody()
	if body == nil {
		t.Fatal("relay never received a request")
	}
	if body["user_id"] != user.Id {
		t.Fatalf("payload user_id = %v, want %q", body["user_id"], user.Id)
	}
	if body["fcm_token"] != "test-token" {
		t.Fatalf("payload fcm_token = %v, want %q (the device's push_token)", body["fcm_token"], "test-token")
	}
	if body["token"] != "activity-token" {
		t.Fatalf("payload token = %v, want %q (the activity_push_token)", body["token"], "activity-token")
	}
}

func TestDispatchLiveActivityUpdateSkipsAndSetsLastErrorWhenDeviceNotFCM(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()
	calls := withFakeRelay(t, http.StatusOK)

	user := liveActivityTestUser(t, app, "la-dispatch-5@example.com")
	device := liveActivityTestDevice(t, app, user.Id)
	device.Set("push_service", "unifiedpush")
	if err := app.Save(device); err != nil {
		t.Fatal(err)
	}
	chat := liveActivityTestChat(t, app, user.Id)
	row := liveActivityTestRow(t, app, user.Id, device.Id, chat.Id, "active")

	if err := dispatchLiveActivityUpdate(app, row, LiveActivityContentState{Status: "running"}); err != nil {
		t.Fatalf("dispatchLiveActivityUpdate returned error: %v", err)
	}

	if got := calls(); got != 0 {
		t.Fatalf("relay received %d POSTs, want 0 (non-fcm device must be skipped)", got)
	}
	reloaded, err := app.FindRecordById("live_activities", row.Id)
	if err != nil {
		t.Fatal(err)
	}
	if reloaded.GetString("last_error") == "" {
		t.Fatal("last_error was left blank when the device isn't FCM-registered")
	}
}
