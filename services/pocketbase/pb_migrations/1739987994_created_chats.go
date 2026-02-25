package pb_migrations

import (
	"encoding/json"

	"github.com/pocketbase/pocketbase/daos"
	"github.com/pocketbase/pocketbase/models"
	"github.com/pocketbase/pocketbase/models/schema"
)

func init() {
	migrate.Add(func(db daos.QueryApplier) error {
		jsonData := `{
			"id": "e0p7j0p0p0p0p0p",
			"created": "2026-02-19 04:39:54.000Z",
			"updated": "2026-02-19 04:39:54.000Z",
			"name": "chats",
			"type": "base",
			"system": false,
			"schema": [
				{
					"system": false,
					"id": "u0p7j0p0p0p0p0p",
					"name": "engine_type",
					"type": "select",
					"required": true,
					"presentable": false,
					"unique": false,
					"options": {
						"maxSelect": 1,
						"values": [
							"opencode",
							"custom",
							"unknown"
						]
					}
				},
				{
					"system": false,
					"id": "y0p7j0p0p0p0p0p",
					"name": "title",
					"type": "text",
					"required": true,
					"presentable": false,
					"unique": false,
					"options": {
						"min": null,
						"max": null,
						"pattern": ""
					}
				},
				{
					"system": false,
					"id": "z0p7j0p0p0p0p0p",
					"name": "preview",
					"type": "text",
					"required": false,
					"presentable": false,
					"unique": false,
					"options": {
						"min": null,
						"max": null,
						"pattern": ""
					}
				},
				{
					"system": false,
					"id": "w0p7j0p0p0p0p0p",
					"name": "user",
					"type": "relation",
					"required": true,
					"presentable": false,
					"unique": false,
					"options": {
						"collectionId": "_pb_users_auth_",
						"cascadeDelete": true,
						"minSelect": null,
						"maxSelect": 1,
						"displayFields": null
					}
				}
			],
			"indexes": [],
			"listRule": "@request.auth.id = user.id",
			"viewRule": "@request.auth.id = user.id",
			"createRule": "@request.auth.id != \"\"",
			"updateRule": "@request.auth.id = user.id",
			"deleteRule": "@request.auth.id = user.id",
			"options": {}
		}`

		collection := &models.Collection{}
		if err := json.Unmarshal([]byte(jsonData), &collection); err != nil {
			return err
		}

		return daos.New(db).SaveCollection(collection)
	}, func(db daos.QueryApplier) error {
		dao := daos.New(db)

		collection, err := dao.FindCollectionByNameOrId("chats")
		if err != nil {
			return err
		}

		return dao.DeleteCollection(collection)
	})
}
