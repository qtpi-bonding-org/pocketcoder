package pb_migrations

import (
	"strings"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

// Removes Goose-superseded turn-state: the messages/permissions/acp_terminals
// collections and the legacy chats session-id/engine fields. Goose owns
// conversation, tool, approval, and terminal state; goose_sessions is the only
// c1 runtime mapping. Forward-only; deleting pre-launch records is acceptable.
func init() {
	migrations.Register(func(app core.App) error {
		for _, name := range []string{"messages", "permissions", "acp_terminals"} {
			col, err := app.FindCollectionByNameOrId(name)
			if err != nil {
				continue // already absent
			}
			if err := app.Delete(col); err != nil {
				return err
			}
		}
		chats, err := app.FindCollectionByNameOrId("chats")
		if err != nil {
			return err
		}
		chats.Indexes = dropIndexes(chats.Indexes, "idx_chats_ai_engine_session_id", "idx_chats_acp_session_id")
		for _, f := range []string{"acp_session_id", "engine_type", "ai_engine_session_id"} {
			if field := chats.Fields.GetByName(f); field != nil {
				chats.Fields.RemoveById(field.GetId())
			}
		}
		return app.Save(chats)
	}, func(app core.App) error {
		// Down: no-op. Pre-launch prune is not reversible by design; recreating
		// empty legacy collections would serve no purpose.
		return nil
	})
}

// dropIndexes returns the index definitions that do not mention any of names.
func dropIndexes(indexes []string, names ...string) []string {
	kept := make([]string, 0, len(indexes))
	for _, idx := range indexes {
		drop := false
		for _, n := range names {
			if strings.Contains(strings.ToLower(idx), strings.ToLower(n)) {
				drop = true
				break
			}
		}
		if !drop {
			kept = append(kept, idx)
		}
	}
	return kept
}