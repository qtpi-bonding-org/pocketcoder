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
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
)

// relaySecretFor derives a per-user relay secret from this deployment's
// shared PN_RELAY_SECRET, so push-relay's tenant-binding check
// (workers/push-relay's checkTenantBinding) sees a distinct secret_hash
// per PocketBase account instead of one shared value every account on
// this deployment would otherwise collide on. Forging a valid secret for
// an arbitrary userID still requires knowing this deployment's real
// rootSecret -- see the plan's Background section for the honest
// before/after accounting of what this does and doesn't change about
// the binding's anti-spoofing property.
func relaySecretFor(rootSecret, userID string) string {
	mac := hmac.New(sha256.New, []byte(rootSecret))
	mac.Write([]byte(userID))
	return hex.EncodeToString(mac.Sum(nil))
}
