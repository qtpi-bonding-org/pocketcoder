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
	"strings"
	"testing"
)

func TestResolveImageDigest_AlreadyPinnedIsUnchanged(t *testing.T) {
	pinned := "mcp/time@sha256:9c46a918633fb474bf8035e3ee90ebac6bcf2b18ccb00679ac4c179cba0ebfcf"
	got, err := resolveImageDigest("test-verify", pinned)
	if err != nil {
		t.Fatalf("resolveImageDigest: %v", err)
	}
	if got != pinned {
		t.Fatalf("got %q, want unchanged %q (already-pinned refs must not be re-resolved)", got, pinned)
	}
}

// TestResolveImageDigest_ResolvesRealTag hits the real Docker Hub registry
// -- mcp/time is the same known-good public image verified live against
// docker-mcp v0.43.3 in spikes/mcp-gateway-v0.43-upgrade/README.md. Skips
// if offline rather than failing the suite on a network blip.
func TestResolveImageDigest_ResolvesRealTag(t *testing.T) {
	got, err := resolveImageDigest("test-verify", "mcp/time:latest")
	if err != nil {
		t.Skipf("skipping (no network / registry unreachable): %v", err)
	}
	if !strings.HasPrefix(got, "mcp/time@sha256:") {
		t.Fatalf("got %q, want mcp/time@sha256:...", got)
	}
}

func TestResolveImageDigest_DefaultsEmptyImageToMcpName(t *testing.T) {
	got, err := resolveImageDigest("time", "")
	if err != nil {
		t.Skipf("skipping (no network / registry unreachable): %v", err)
	}
	if !strings.HasPrefix(got, "mcp/time@sha256:") {
		t.Fatalf("got %q, want mcp/time@sha256:... (empty image should default to mcp/<name>:latest before resolving)", got)
	}
}
