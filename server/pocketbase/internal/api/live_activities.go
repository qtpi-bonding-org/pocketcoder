package api

import (
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/errorutil"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/operation"
	"net/http"
	"time"
)

func AddLiveActivityOperations(app core.App, registry *operation.Registry) {
	registry.Add(operation.Route{OperationID: "endLiveActivity", Method: http.MethodPost, Path: "/api/pocketcoder/v1/live-activities/{id}/end", Auth: true, Action: func(re *core.RequestEvent) error {
		if err := EndLiveActivity(app, re); err != nil {
			return err
		}
		return re.JSON(http.StatusOK, map[string]any{"ok": true})
	}})
	registry.Add(operation.Route{OperationID: "setLiveActivityToken", Method: http.MethodPost, Path: "/api/pocketcoder/v1/live-activities/{id}/token", Auth: true, Action: func(re *core.RequestEvent) error {
		if err := SetLiveActivityToken(app, re); err != nil {
			return err
		}
		return re.JSON(http.StatusOK, map[string]any{"ok": true})
	}})
}

func EndLiveActivity(app core.App, re *core.RequestEvent) error {
	rec, err := requireOwnedRecord(app, re, "live_activities", re.Request.PathValue("id"))
	if err != nil {
		return err
	}
	// requireOwnedRecord's rejection path returns (nil, nil), not
	// (nil, non-nil error): native PocketBase errors are returned
	// whatever re.JSON's write reported, which is nil on any normal
	// successful write of the 404 body it already sent. The err != nil
	// guard above alone doesn't catch a rejection, so it must be
	// paired with a nil check on the record itself, or this dereferences
	// a nil *core.Record below.
	if rec == nil {
		return nil
	}
	if rec.GetString("status") != "active" {
		return apis.NewApiError(http.StatusConflict, "Live activity is not active", nil)
	}
	rec.Set("status", "ended")
	rec.Set("ended_at", time.Now())
	if err := app.Save(rec); err != nil {
		return errorutil.Internal("update live activity status", err)
	}
	return nil
}

// SetLiveActivityToken lets the client report back the real ActivityKit
// push token once it's handed one asynchronously after a server-created
// (push-to-start) Activity actually starts on-device -- there is no other
// way to do this, since the collection's updateRule is null. Parses the
// body itself, for the raw registry.Route path.
func SetLiveActivityToken(app core.App, re *core.RequestEvent) error {
	var input struct {
		ActivityPushToken string `json:"activity_push_token"`
	}
	if err := re.BindBody(&input); err != nil || input.ActivityPushToken == "" {
		return apis.NewApiError(http.StatusBadRequest, "activity_push_token is required", nil)
	}
	return SetLiveActivityTokenByID(app, re, re.Request.PathValue("id"), input.ActivityPushToken)
}

// SetLiveActivityTokenByID does the ownership check and status-checked
// save, taking an already-parsed token -- shared by SetLiveActivityToken's
// raw-body path and the operationapi strict handler (which already has
// request.Body.ActivityPushToken typed for it, so it calls this directly
// rather than round-tripping through a raw HTTP body).
func SetLiveActivityTokenByID(app core.App, re *core.RequestEvent, id, token string) error {
	rec, err := requireOwnedRecord(app, re, "live_activities", id)
	if err != nil {
		return err
	}
	if rec.GetString("status") != "active" {
		return apis.NewApiError(http.StatusConflict, "Live activity is not active", nil)
	}
	rec.Set("activity_push_token", token)
	rec.Set("last_error", "")
	if err := app.Save(rec); err != nil {
		return errorutil.Internal("update live activity token", err)
	}
	return nil
}
