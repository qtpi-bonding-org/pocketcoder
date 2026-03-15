/*
PocketCoder: An accessible, secure, and user-friendly open-source coding assistant platform.
Copyright (C) 2026 Qtpi Bonding LLC

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

package hooks

import (
	"log"
	"time"

	"github.com/pocketbase/pocketbase/core"
)

const (
	OpenCodeContainer = "pocketcoder-opencode"
	GatewayContainer  = "pocketcoder-mcp-gateway"
	SandboxContainer  = "pocketcoder-sandbox"
)

// renderAndRestart runs a config render function and restarts the given container.
// On render failure it logs and continues the hook chain without restarting.
func renderAndRestart(prefix string, renderFn func() error, container string, e *core.RecordEvent) error {
	if err := renderFn(); err != nil {
		log.Printf("❌ %s Failed to render: %v", prefix, err)
		return e.Next()
	}
	if err := restartContainer(container, 30*time.Second); err != nil {
		log.Printf("❌ %s Failed to restart %s: %v", prefix, container, err)
	}
	return e.Next()
}

// registerCrudHooks binds the same handler to Create, Update, and Delete success events.
func registerCrudHooks(app core.App, collection string, handler func(*core.RecordEvent) error) {
	app.OnRecordAfterCreateSuccess(collection).BindFunc(handler)
	app.OnRecordAfterUpdateSuccess(collection).BindFunc(handler)
	app.OnRecordAfterDeleteSuccess(collection).BindFunc(handler)
}
