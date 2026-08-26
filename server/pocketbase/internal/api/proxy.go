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
	"fmt"
	"net/http"
	"net/http/httputil"
	"net/url"
	"strings"

	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/operation"
)

type ProxyDeps struct {
	Transport http.RoundTripper
	TargetURL string
}

// ObservabilityProxyPrefix is the path this proxy is mounted at, exported
// so config_consistency_test.go can assert docker-compose.yml's
// SQLPAGE_SITE_PREFIX actually matches it. It has to: the reverse proxy
// strips this prefix before forwarding, so SQLPage sees an unprefixed
// path and 308-redirects to whatever site prefix IT was told to expect --
// a mismatch there sends that redirect to a path this proxy never
// registered at all, 404ing. Confirmed live: SQLPAGE_SITE_PREFIX had
// drifted to a stale pre-v1 path (missing this route's "v1" segment),
// breaking the Monitor screen's observability dashboard 100% of the time.
const ObservabilityProxyPrefix = "/api/pocketcoder/v1/proxy/observability"

func AddProxyOperations(registry *operation.Registry, deps ProxyDeps) {
	target := strings.TrimSpace(deps.TargetURL)
	if target == "" {
		target = "http://sqlpage:8080"
	}
	transport := deps.Transport
	if transport == nil {
		transport = http.DefaultTransport
	}

	// 📈 Observability Proxy (SQLPage)
	// Proxies to the SQLPage container which provides database dashboards.
	registry.Add(operation.Route{
		OperationID: "proxyObservability",
		Method:      http.MethodGet,
		Path:        ObservabilityProxyPrefix + "/{path...}",
		Auth:        true,
		Direct:      true,
		Action:      createProxyHandler(target, ObservabilityProxyPrefix, transport),
	})
}

// createProxyHandler creates a standard reverse proxy handler that strips a prefix and forwards to a target.
func createProxyHandler(target string, prefix string, transport http.RoundTripper) func(re *core.RequestEvent) error {
	targetUrl, err := url.Parse(target)
	if err != nil {
		// Return a handler that always reports the misconfiguration.
		return func(re *core.RequestEvent) error {
			return re.BadRequestError(fmt.Sprintf("Proxy target URL is malformed: %v", err), nil)
		}
	}
	proxy := httputil.NewSingleHostReverseProxy(targetUrl)
	proxy.Transport = transport

	return func(re *core.RequestEvent) error {
		req := re.Request
		// The memory dashboard is read-only and belongs to the authenticated
		// deployment user. Keep every other SQLPage surface admin-only.
		memoryDashboard := req.URL.Path == prefix+"/memory.sql"
		if !memoryDashboard {
			if err := requireRole(re, "admin"); err != nil {
				return err
			}
		}

		// Update headers and target URL for the proxy
		req.URL.Host = targetUrl.Host
		req.URL.Scheme = targetUrl.Scheme
		req.Header.Set("X-Forwarded-Host", req.Host)
		req.Header.Set("X-Forwarded-Prefix", prefix)
		req.Host = targetUrl.Host

		// Deliberately NOT stripping prefix from the path here. SQLPage's own
		// site_prefix config (SQLPAGE_SITE_PREFIX) expects to see this prefix
		// still present in the request path -- it strips/routes internally
		// itself, and any request that arrives WITHOUT its configured prefix
		// gets a 308 redirect TO that prefix (its own "you're missing my
		// mount point" recovery). Confirmed live: stripping here caused an
		// infinite redirect loop -- our proxy stripped the prefix before
		// forwarding, SQLPage saw an unprefixed path and 308-redirected back
		// to the (correctly-configured, matching) prefixed path, which
		// re-entered this same proxy, which stripped the prefix again, ad
		// infinitum, until the client's own HTTP stack gave up with
		// "Redirect loop detected". See sql-page.com's own nginx reverse-
		// proxy guide: the documented pattern is `proxy_pass` with the
		// prefixed path left completely intact, matched by
		// `"site_prefix": "<same prefix>"` in sqlpage.json.

		// Perform the proxying
		proxy.ServeHTTP(re.Response, req)
		return nil
	}
}
