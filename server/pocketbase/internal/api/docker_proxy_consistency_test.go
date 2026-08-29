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
	"testing"

	"gopkg.in/yaml.v3"
)

// TestDockerProxyWriteAllowsLifecycleActionsOurCodeUses is the regression
// test for a real incident: docker-socket-proxy-write's environment had
// CONTAINERS=1 and POST=1 set, which the adjacent comment believed covered
// container start/restart -- it doesn't. Tecnativa/docker-socket-proxy gates
// each container lifecycle action (start, stop, restart, pause, unpause)
// behind its own dedicated ALLOW_* variable, independent of the general
// CONTAINERS/POST switches. Confirmed live: dockerapi.Client.Create()
// succeeded (HTTP 201) but the immediately-following Start() call 404'd on
// every single attempt, because ALLOW_START was never set -- every harness
// container got created and then stuck permanently at "Created", never
// actually running. hooks/docker.go's restartContainer() has the identical
// gap via ALLOW_RESTARTS.
//
// Nothing at the Go unit-test level exercises the deployed compose file's
// actual env var values -- this test reads docker-compose.yml directly, the
// same approach TestSqlpageSitePrefixMatchesObservabilityProxyPrefix uses
// for the sibling SQLPage-proxy incident, so a future accidental removal of
// these variables fails CI instead of silently shipping a harness that can
// never start.
func TestDockerProxyWriteAllowsLifecycleActionsOurCodeUses(t *testing.T) {
	// server/pocketbase/internal/api -> repo root.
	composePath := "../../../../docker-compose.yml"
	raw, err := os.ReadFile(composePath)
	if err != nil {
		t.Fatalf("read %s: %v", composePath, err)
	}

	var doc struct {
		Services struct {
			DockerSocketProxyWrite struct {
				Environment []string `yaml:"environment"`
			} `yaml:"docker-socket-proxy-write"`
		} `yaml:"services"`
	}
	if err := yaml.Unmarshal(raw, &doc); err != nil {
		t.Fatalf("parse %s: %v", composePath, err)
	}

	env := make(map[string]string, len(doc.Services.DockerSocketProxyWrite.Environment))
	for _, entry := range doc.Services.DockerSocketProxyWrite.Environment {
		key, value, found := splitEnvEntry(entry)
		if !found {
			t.Fatalf("malformed environment entry in docker-socket-proxy-write: %q", entry)
		}
		env[key] = value
	}
	if len(env) == 0 {
		t.Fatal("docker-compose.yml's docker-socket-proxy-write service has no environment entries")
	}

	// Our own dockerapi.Client (used for harness provisioning) calls
	// /containers/{id}/start; hooks/docker.go's restartContainer calls
	// /containers/{id}/restart. Neither /stop, /pause, nor /unpause is
	// called anywhere in this codebase, so this test deliberately does not
	// require ALLOW_STOP/ALLOW_PAUSE/ALLOW_UNPAUSE -- matching this same
	// compose file's existing least-privilege pattern (NETWORKS=0,
	// VOLUMES=0, etc.) rather than granting permissions nothing uses.
	required := []string{"ALLOW_START", "ALLOW_RESTARTS"}
	for _, key := range required {
		if env[key] != "1" {
			t.Fatalf("docker-socket-proxy-write environment %s = %q, want \"1\" "+
				"(without it, the corresponding container lifecycle call 404s against this proxy)",
				key, env[key])
		}
	}
}

// splitEnvEntry splits a "KEY=value" docker-compose environment string.
func splitEnvEntry(entry string) (key, value string, found bool) {
	for i := 0; i < len(entry); i++ {
		if entry[i] == '=' {
			return entry[:i], entry[i+1:], true
		}
	}
	return "", "", false
}
