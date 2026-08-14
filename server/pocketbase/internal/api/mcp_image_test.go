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

import "testing"

func TestMCPResolveImageDigest_AlreadyPinnedIsUnchanged(t *testing.T) {
	pinned := "mcp/time@sha256:9c46a918633fb474bf8035e3ee90ebac6bcf2b18ccb00679ac4c179cba0ebfcf"
	got, err := resolveImageDigest("test-verify", pinned)
	if err != nil {
		t.Fatalf("resolveImageDigest: %v", err)
	}
	if got != pinned {
		t.Fatalf("got %q, want unchanged %q", got, pinned)
	}
}

func TestMCPNormalizeImageRef(t *testing.T) {
	tests := []struct {
		name, image, want string
	}{
		{"empty defaults to MCP name", "", "mcp/time:latest"},
		{"repository gets latest", "mcp/time", "mcp/time:latest"},
		{"pinned stays pinned", "mcp/time@sha256:abc", "mcp/time@sha256:abc"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := normalizeImageRef("time", tt.image); got != tt.want {
				t.Fatalf("normalizeImageRef() = %q, want %q", got, tt.want)
			}
		})
	}
}
