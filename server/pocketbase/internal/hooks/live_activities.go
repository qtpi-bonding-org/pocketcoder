package hooks

import (
	"fmt"
	"github.com/pocketbase/pocketbase/core"
	"log"
	"os"
	"time"
)

// LiveActivityAttributesType is the exact ActivityAttributes Swift type
// name the future widget extension must declare -- fixed here as part of
// the wire contract between server and client.
const LiveActivityAttributesType = "PocketCoderChatActivityAttributes"
const MaxConcurrentLiveActivities = 5

type LiveActivityContentState struct {
	Status    string `json:"status"`
	Title     string `json:"title"`
	UpdatedAt int64  `json:"updated_at"`
}

func activeActivities(app core.App, chatID string) ([]*core.Record, error) {
	return app.FindRecordsByFilter("live_activities", "chat = {:chat} && status = 'active'", "", 0, 0, map[string]any{"chat": chatID})
}
func NotifyRunStarted(app core.App, chatID string) error {
	rows, err := activeActivities(app, chatID)
	if err != nil {
		return err
	}
	for _, r := range rows {
		_ = dispatchLiveActivityUpdate(app, r, LiveActivityContentState{Status: "running", Title: "Agent is running", UpdatedAt: time.Now().Unix()})
	}
	if len(rows) == 0 {
		_ = maybeStartLiveActivities(app, chatID)
	}
	return nil
}

func maybeStartLiveActivities(app core.App, chatID string) error {
	chat, err := app.FindRecordById("chats", chatID)
	if err != nil || !chat.GetBool("monitored") {
		return nil
	}
	userID := chat.GetString("user")
	active, err := app.FindRecordsByFilter("live_activities", "user = {:user} && status = 'active'", "", 0, 0, map[string]any{"user": userID})
	if err != nil || len(active) >= MaxConcurrentLiveActivities {
		return nil
	}
	devices, err := app.FindRecordsByFilter("devices", "user = {:user} && platform = 'ios' && is_active = true && push_to_start_token != ''", "", 0, 0, map[string]any{"user": userID})
	if err != nil {
		return nil
	}
	coll, err := app.FindCollectionByNameOrId("live_activities")
	if err != nil {
		return nil
	}
	for _, d := range devices {
		if len(active) >= MaxConcurrentLiveActivities {
			break
		}
		existing, _ := app.FindRecordsByFilter("live_activities", "chat = {:chat} && device = {:device} && status = 'active'", "", 1, 0, map[string]any{"chat": chatID, "device": d.Id})
		if len(existing) > 0 {
			continue
		}
		row := core.NewRecord(coll)
		row.Set("user", userID)
		row.Set("device", d.Id)
		row.Set("chat", chatID)
		row.Set("platform", "ios")
		row.Set("status", "active")
		row.Set("content_state_version", 1)
		if err := app.Save(row); err != nil {
			log.Printf("live activities: server-create for push-to-start: %v", err)
			continue
		}
		active = append(active, row)
		err = SendLiveActivityUpdate(d.GetString("push_to_start_token"), d.GetString("push_token"), userID,
			LiveActivityContentState{Status: "running", Title: "Agent is running", UpdatedAt: time.Now().Unix()},
			1, "start", LiveActivityAttributesType, map[string]any{"chatId": chatID})
		if err != nil {
			row.Set("last_error", err.Error())
			_ = app.Save(row)
		}
	}
	return nil
}
func NotifyRunFinished(app core.App, chatID, outcome string) error {
	rows, err := activeActivities(app, chatID)
	if err != nil {
		return err
	}
	for _, r := range rows {
		_ = dispatchLiveActivityUpdate(app, r, LiveActivityContentState{Status: outcome, Title: "Agent " + outcome, UpdatedAt: time.Now().Unix()})
		if r.GetString("status") == "active" {
			r.Set("status", "ended")
			r.Set("ended_at", time.Now())
			r.Set("last_push_at", time.Now())
			if err := app.Save(r); err != nil {
				log.Printf("live activities: save finished activity: %v", err)
			}
		}
	}
	return nil
}

func dispatchLiveActivityUpdate(app core.App, activity *core.Record, state LiveActivityContentState) error {
	v := activity.GetInt("content_state_version") + 1
	if v < 1 {
		v = 1
	}
	activity.Set("content_state_version", v)

	if os.Getenv("PN_URL") == "" {
		// Matches FcmRelayProvider.Send's existing "not configured, skip"
		// convention -- no send happened, so don't persist the version
		// bump either (nothing was actually dispatched).
		return nil
	}

	device, derr := app.FindRecordById("devices", activity.GetString("device"))
	if derr != nil || device.GetString("push_service") != "fcm" {
		// FCM v1's Live Activity delivery needs a normal FCM
		// registration token alongside the activity's own push token
		// (see notifications.go's SendLiveActivityUpdate doc) -- a
		// missing device or a non-FCM one (e.g. unifiedpush) can't
		// carry that, so skip the send rather than dispatch a request
		// the relay can never fulfill.
		activity.Set("last_error", "live activity device is missing or not FCM-registered")
		if err := app.Save(activity); err != nil {
			log.Printf("live activities: save activity: %v", err)
		}
		return nil
	}

	err := SendLiveActivityUpdate(activity.GetString("activity_push_token"), device.GetString("push_token"), activity.GetString("user"), state, v, "update", "", nil)
	if err != nil {
		activity.Set("last_error", err.Error())
		log.Printf("%v", err)
	} else {
		activity.Set("last_error", "")
	}
	if err := app.Save(activity); err != nil {
		log.Printf("live activities: save activity: %v", err)
	}
	return nil
}

func RegisterLiveActivityHooks(app core.App) {
	// OnRecordUpdate (a before-save hook), not OnRecordAfterUpdateSuccess:
	// by the time an AfterUpdateSuccess hook fires, Original() has already
	// been resynced to match the just-persisted state, so the flip-detect
	// comparison below would never be true. RegisterChatsHarnessPinHook
	// (chats_harness_pin.go) establishes the same before-save pattern for
	// exactly this reason.
	app.OnRecordUpdate("chats").BindFunc(func(e *core.RecordEvent) error {
		o := e.Record.Original()
		if o == nil {
			return e.Next()
		}
		if (o.GetBool("monitored") && !e.Record.GetBool("monitored")) || (!o.GetBool("archived") && e.Record.GetBool("archived")) {
			_ = NotifyRunFinished(e.App, e.Record.Id, "cancelled")
		}
		return e.Next()
	})
	app.OnRecordCreate("live_activities").BindFunc(func(e *core.RecordEvent) error {
		d, derr := e.App.FindRecordById("devices", e.Record.GetString("device"))
		c, cerr := e.App.FindRecordById("chats", e.Record.GetString("chat"))
		if derr != nil || cerr != nil || d.GetString("user") != e.Record.GetString("user") || c.GetString("user") != e.Record.GetString("user") {
			return fmt.Errorf("live activity device, chat, and user must match")
		}
		return e.Next()
	})
}
