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

// @pocketcoder-core: Proxy API. Reverse proxy for observability and log services.
package api

import (
	"net/http/httputil"
	"net/url"
	"strings"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
)

// RegisterProxyApi registers the reverse proxy endpoints for logs and observability.
func RegisterProxyApi(app *pocketbase.PocketBase, e *core.ServeEvent) {
	// 📊 Logs Proxy (Dozzle)
	// Proxies to the Dozzle container which provides real-time Docker logs.
	e.Router.Any("/api/pocketcoder/proxy/logs/{path...}", createProxyHandler("http://dozzle:8080", "/api/pocketcoder/proxy/logs")).Bind(apis.RequireAuth())

	// 📈 Observability Proxy (SQLPage)
	// Proxies to the SQLPage container which provides database dashboards.
	e.Router.Any("/api/pocketcoder/proxy/observability/{path...}", createProxyHandler("http://sqlpage:8080", "/api/pocketcoder/proxy/observability")).Bind(apis.RequireAuth())
}

// createProxyHandler creates a standard reverse proxy handler that strips a prefix and forwards to a target.
func createProxyHandler(target string, prefix string) func(re *core.RequestEvent) error {
	targetUrl, _ := url.Parse(target)
	proxy := httputil.NewSingleHostReverseProxy(targetUrl)

	return func(re *core.RequestEvent) error {
		// 🛡️ Security Gate: Only allow authenticated admins to access internal observability tools.
		if re.Auth == nil || re.Auth.GetString("role") != "admin" {
			return re.ForbiddenError("Only admins can access system proxies.", nil)
		}

		req := re.Request
		
		// Update headers and target URL for the proxy
		req.URL.Host = targetUrl.Host
		req.URL.Scheme = targetUrl.Scheme
		req.Header.Set("X-Forwarded-Host", req.Header.Get("Host"))
		req.Header.Set("X-Forwarded-Prefix", prefix)
		req.Host = targetUrl.Host

		// Strip prefix from the path so the target service sees its own root
		path := req.URL.Path
		if strings.HasPrefix(path, prefix) {
			req.URL.Path = strings.TrimPrefix(path, prefix)
			if req.URL.Path == "" {
				req.URL.Path = "/"
			}
		}

		// Perform the proxying
		proxy.ServeHTTP(re.Response, req)
		return nil
	}
}
