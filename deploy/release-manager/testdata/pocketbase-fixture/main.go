package main

import (
	"net/http"
	"os"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
	"github.com/pocketbase/pocketbase/plugins/migratecmd"
)

const (
	baseMigration = "100_release_fixture_base.go"
	v2Migration   = "200_release_fixture_v2.go"
)

func registerMigrations() {
	migrations.Register(func(app core.App) error {
		_, err := app.NonconcurrentDB().NewQuery(`
			CREATE TABLE release_fixture_items (
				id TEXT PRIMARY KEY NOT NULL,
				value TEXT NOT NULL
			)
		`).Execute()
		return err
	}, func(app core.App) error {
		_, err := app.NonconcurrentDB().NewQuery("DROP TABLE IF EXISTS release_fixture_items").Execute()
		return err
	}, baseMigration)

	if os.Getenv("FIXTURE_DATA_VERSION") != "2" {
		return
	}
	migrations.Register(func(app core.App) error {
		_, err := app.NonconcurrentDB().NewQuery(`
			ALTER TABLE release_fixture_items
			ADD COLUMN migration_marker TEXT NOT NULL DEFAULT 'migrated-by-v2'
		`).Execute()
		return err
	}, func(app core.App) error {
		_, err := app.NonconcurrentDB().NewQuery(`
			ALTER TABLE release_fixture_items DROP COLUMN migration_marker
		`).Execute()
		return err
	}, v2Migration)
}

func main() {
	registerMigrations()
	app := pocketbase.New()
	migratecmd.MustRegister(app, app.RootCmd, migratecmd.Config{Automigrate: true})
	app.OnServe().BindFunc(func(event *core.ServeEvent) error {
		event.Router.GET("/fixture/health", func(request *core.RequestEvent) error {
			if os.Getenv("FIXTURE_HEALTHY") == "false" {
				return request.JSON(http.StatusServiceUnavailable, map[string]any{"healthy": false})
			}
			return request.JSON(http.StatusOK, map[string]any{"healthy": true})
		})
		event.Router.POST("/fixture/seed", func(request *core.RequestEvent) error {
			_, err := request.App.DB().NewQuery(`
				INSERT OR REPLACE INTO release_fixture_items (id, value)
				VALUES ('seed', 'preserved-across-release')
			`).Execute()
			if err != nil {
				return request.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
			}
			return request.JSON(http.StatusCreated, map[string]any{"seeded": true})
		})
		event.Router.GET("/fixture/state", func(request *core.RequestEvent) error {
			var row struct {
				Value string `db:"value"`
			}
			if err := request.App.DB().NewQuery("SELECT value FROM release_fixture_items WHERE id = 'seed'").One(&row); err != nil {
				return request.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
			}
			var columns struct {
				Count int `db:"count"`
			}
			if err := request.App.DB().NewQuery(`
				SELECT COUNT(*) AS count
				FROM pragma_table_info('release_fixture_items')
				WHERE name = 'migration_marker'
			`).One(&columns); err != nil {
				return request.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
			}
			return request.JSON(http.StatusOK, map[string]any{
				"value":            row.Value,
				"migrationApplied": columns.Count == 1,
			})
		})
		return event.Next()
	})
	if err := app.Start(); err != nil {
		panic(err)
	}
}
