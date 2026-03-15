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

// @pocketcoder-core: Files API. Secure endpoint for accessing workspace files.
package filesystem

import (
	"io"
	"path/filepath"
	"strings"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/filesystem"
)

// RegisterFilesApi provides a secure window into the /workspace using the PB Filesystem abstraction.
func RegisterFilesApi(app *pocketbase.PocketBase, e *core.ServeEvent) {
	e.Router.GET("/api/pocketcoder/files/{path...}", func(re *core.RequestEvent) error {
		// 1. Auth Gate
		if re.Auth == nil {
			return re.ForbiddenError("Direct access to fragments is forbidden for shadows.", nil)
		}

		// 2. Resolve Path
		pathParam := re.Request.PathValue("path")
		if pathParam == "" {
			return re.BadRequestError("Empty path.", nil)
		}

		// Sanitization
		cleanPath := filepath.Clean(pathParam)
		if strings.HasPrefix(cleanPath, "..") || strings.HasPrefix(cleanPath, "/") {
			return re.ForbiddenError("Path escape attempt detected.", nil)
		}

		// 3. Initialize Filesystem Abstraction (S3-Ready)
		// For now we point it at the local /workspace volume
		fsys, err := filesystem.NewLocal("/workspace")
		if err != nil {
			return re.InternalServerError("Sovereign storage failure.", err)
		}
		defer fsys.Close()

		// 4. Stream File
		r, err := fsys.GetReader(cleanPath)
		if err != nil {
			return re.NotFoundError("File not found.", err)
		}
		defer r.Close()

		// Sniff Content Type if possible, or default to octet-stream
		// Actually, http.ServeContent or similar might be better, but GetReader logic is manual
		// We'll set a default and let the client handle it for now, or use a basic extension check.
		re.Response.Header().Set("Content-Type", "application/octet-stream")
		if strings.HasSuffix(cleanPath, ".html") { re.Response.Header().Set("Content-Type", "text/html") }
		if strings.HasSuffix(cleanPath, ".png") { re.Response.Header().Set("Content-Type", "image/png") }
		if strings.HasSuffix(cleanPath, ".txt") { re.Response.Header().Set("Content-Type", "text/plain") }

		_, err = io.Copy(re.Response, r)
		return err
	}).Bind(apis.RequireAuth())
}
