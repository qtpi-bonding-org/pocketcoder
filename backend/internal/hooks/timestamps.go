package hooks

import (
	"time"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
)

// RegisterGlobalTimestamps registers hooks for created, updated, and last_active timestamps.
func RegisterGlobalTimestamps(app *pocketbase.PocketBase) {
	handler := func(e *core.RecordEvent) error {
		now := time.Now().Format("2006-01-02 15:04:05.000Z")
		collection := e.Record.Collection()

		if f := collection.Fields.GetByName("created"); f != nil {
			if e.Record.GetString("created") == "" {
				e.Record.Set("created", now)
			}
		}
		if f := collection.Fields.GetByName("updated"); f != nil {
			e.Record.Set("updated", now)
		}
		if collection.Name == "chats" {
			if f := collection.Fields.GetByName("last_active"); f != nil {
				e.Record.Set("last_active", now)
			}
		}
		return e.Next()
	}

	collections := []string{"chats", "messages", "permissions", "usages", "ssh_keys", "ai_agents"}
	for _, col := range collections {
		app.OnRecordCreate(col).BindFunc(handler)
		app.OnRecordUpdate(col).BindFunc(handler)
	}
}
