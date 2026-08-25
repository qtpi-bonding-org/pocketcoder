package hooks

import (
	"fmt"
	"github.com/pocketbase/pocketbase/core"
	"log"
	"os"
	"time"
)

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
			_ = app.Save(r)
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

	err := SendLiveActivityUpdate(activity.GetString("activity_push_token"), state, v, "update")
	if err != nil {
		activity.Set("last_error", err.Error())
		log.Printf("%v", err)
	} else {
		activity.Set("last_error", "")
	}
	_ = app.Save(activity)
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
