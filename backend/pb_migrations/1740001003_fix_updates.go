
package pb_migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

func init() {
	migrations.Register(func(app core.App) error {
		// 1. Fix Permissions Collection
		permissions, err := app.FindCollectionByNameOrId("permissions")
		if err == nil {
			if f := permissions.Fields.GetByName("source"); f == nil {
				permissions.Fields.Add(&core.TextField{Name: "source"})
			}
			if f := permissions.Fields.GetByName("message_id"); f == nil {
				permissions.Fields.Add(&core.TextField{Name: "message_id"})
			}
			if f := permissions.Fields.GetByName("call_id"); f == nil {
				permissions.Fields.Add(&core.TextField{Name: "call_id"})
			}
			if f := permissions.Fields.GetByName("challenge"); f == nil {
				permissions.Fields.Add(&core.TextField{Name: "challenge"})
			}
			if f := permissions.Fields.GetByName("chat"); f == nil {
				chats, _ := app.FindCollectionByNameOrId("chats")
				if chats != nil {
					permissions.Fields.Add(&core.RelationField{
						Name:         "chat",
						CollectionId: chats.Id,
						MaxSelect:    1,
					})
				}
			}
			app.Save(permissions)
		}

		// 2. Fix Whitelist Actions
		wlActions, err := app.FindCollectionByNameOrId("whitelist_actions")
		if err == nil {
			if f := wlActions.Fields.GetByName("permission"); f == nil {
				wlActions.Fields.Add(&core.TextField{Name: "permission"})
			}
			if f := wlActions.Fields.GetByName("kind"); f == nil {
				wlActions.Fields.Add(&core.SelectField{Name: "kind", Values: []string{"strict", "pattern"}, MaxSelect: 1})
			}
			if f := wlActions.Fields.GetByName("value"); f == nil {
				wlActions.Fields.Add(&core.TextField{Name: "value"})
			}
			if f := wlActions.Fields.GetByName("active"); f == nil {
				wlActions.Fields.Add(&core.BoolField{Name: "active"})
			}
			app.Save(wlActions)
		}

		// 3. Fix Roles and Rules
		chats, _ := app.FindCollectionByNameOrId("chats")
		if chats != nil {
			r := "@request.auth.id != '' && (user = @request.auth.id || @request.auth.role = 'agent' || @request.auth.role = 'admin')"
			chats.ListRule = &r
			chats.ViewRule = &r
			chats.UpdateRule = &r
			app.Save(chats)
		}

		messages, _ := app.FindCollectionByNameOrId("messages")
		if messages != nil {
			listRule := "@request.auth.id != '' && (@request.auth.role = 'agent' || @request.auth.role = 'admin' || chat.user = @request.auth.id)"
			updateRule := "@request.auth.role = 'agent' || @request.auth.role = 'admin'"
			messages.ListRule = &listRule
			messages.ViewRule = &listRule
			messages.UpdateRule = &updateRule
			app.Save(messages)
		}

		return nil
	}, func(app core.App) error {
		return nil
	})
}
