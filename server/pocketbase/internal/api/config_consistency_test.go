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

package api

import (
	"os"
	"strings"
	"testing"

	"gopkg.in/yaml.v3"
)

// TestSqlpageSitePrefixMatchesObservabilityProxyPrefix is the regression
// test for a real incident: docker-compose.yml's SQLPAGE_SITE_PREFIX had
// drifted to a stale path missing this proxy's "v1" segment. The reverse
// proxy strips ObservabilityProxyPrefix before forwarding, so SQLPage sees
// an unprefixed path and 308-redirects to whatever site prefix it was
// configured with -- if that doesn't match where this proxy is actually
// mounted, the redirect lands on a path with no registered route at all,
// and every observability/Monitor-screen request 404s. Confirmed live via
// SSH: `docker logs pocketcoder-sqlpage` showed the exact stale-prefix
// redirect, and following it against PocketBase returned 404.
//
// Nothing at the Go unit-test level exercises the deployed compose file's
// actual env var value -- this test reads it directly from
// docker-compose.yml so a future rename of ObservabilityProxyPrefix (or a
// hand-edit of the compose file) fails CI instead of shipping silently
// broken to every deployment.
func TestSqlpageSitePrefixMatchesObservabilityProxyPrefix(t *testing.T) {
	// server/pocketbase/internal/api -> repo root.
	composePath := "../../../../docker-compose.yml"
	raw, err := os.ReadFile(composePath)
	if err != nil {
		t.Fatalf("read %s: %v", composePath, err)
	}

	var doc struct {
		Services struct {
			Sqlpage struct {
				Environment []string `yaml:"environment"`
			} `yaml:"sqlpage"`
		} `yaml:"services"`
	}
	if err := yaml.Unmarshal(raw, &doc); err != nil {
		t.Fatalf("parse %s: %v", composePath, err)
	}

	var sitePrefix string
	var found bool
	for _, entry := range doc.Services.Sqlpage.Environment {
		if value, ok := strings.CutPrefix(entry, "SQLPAGE_SITE_PREFIX="); ok {
			sitePrefix, found = value, true
			break
		}
	}
	if !found {
		t.Fatal("docker-compose.yml's sqlpage service has no SQLPAGE_SITE_PREFIX env var")
	}

	want := ObservabilityProxyPrefix + "/"
	if sitePrefix != want {
		t.Fatalf("SQLPAGE_SITE_PREFIX = %q, want %q (must match ObservabilityProxyPrefix, "+
			"the path this proxy actually forwards to SQLPage from)", sitePrefix, want)
	}
}
