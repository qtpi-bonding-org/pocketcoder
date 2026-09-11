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

import "testing"

func TestRelaySecretForIsDeterministic(t *testing.T) {
	a := relaySecretFor("root-secret", "user-1")
	b := relaySecretFor("root-secret", "user-1")
	if a != b {
		t.Fatalf("relaySecretFor is not deterministic: %q != %q", a, b)
	}
}

func TestRelaySecretForDiffersByUserID(t *testing.T) {
	a := relaySecretFor("root-secret", "user-1")
	b := relaySecretFor("root-secret", "user-2")
	if a == b {
		t.Fatal("relaySecretFor produced the same secret for two different userIDs under the same root secret")
	}
}

func TestRelaySecretForDiffersByRootSecret(t *testing.T) {
	a := relaySecretFor("root-secret-a", "user-1")
	b := relaySecretFor("root-secret-b", "user-1")
	if a == b {
		t.Fatal("relaySecretFor produced the same secret for two different root secrets with the same userID")
	}
}

// TestRelaySecretForMatchesHMACKeyedByRootSecret pins the exact
// construction: the ROOT SECRET is the HMAC key, the USER ID is the
// message. The four tests above alone would also pass with the arguments
// swapped (HMAC keyed by userID, root secret as message) -- this test
// exists specifically to catch that. The expected value was generated
// with: printf '%s' "user-1" | openssl dgst -sha256 -hmac "root-secret" -r
func TestRelaySecretForMatchesHMACKeyedByRootSecret(t *testing.T) {
	got := relaySecretFor("root-secret", "user-1")
	if len(got) != 64 {
		t.Fatalf("len(got) = %d, want 64 (hex-encoded SHA-256 digest)", len(got))
	}
	const want = "17ead0ca598a9bf29eff0e9847121e48825bbefd4049b332a84dd05af3bd904b"
	if got != want {
		t.Fatalf("relaySecretFor(\"root-secret\", \"user-1\") = %q, want %q -- the HMAC key must be rootSecret and the message must be userID, not the other way around", got, want)
	}
}
