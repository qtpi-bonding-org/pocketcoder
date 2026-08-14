//go:build live

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

package mcpserver

import (
	"context"
	"strings"
	"testing"
)

func TestResolveImageDigest_LiveRegistryRoundTrip(t *testing.T) {
	got, err := ResolveImageDigest(context.Background(), "test-verify", "mcp/time:latest")
	if err != nil {
		t.Fatal(err)
	}
	if !strings.HasPrefix(got, "mcp/time@sha256:") {
		t.Fatalf("got %q, want mcp/time@sha256:...", got)
	}
}
