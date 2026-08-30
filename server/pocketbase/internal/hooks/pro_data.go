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
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"time"

	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/operation"
)

func AddProDataOperations(app core.App, registry *operation.Registry) {
	registry.Add(operation.Route{OperationID: "deleteProData", Method: http.MethodDelete, Path: "/api/pocketcoder/v1/pro-data", Auth: true, Action: func(re *core.RequestEvent) error {
		if err := DeleteProDataOperation(re.Auth.Id); err != nil {
			return err
		}
		return re.NoContent(http.StatusNoContent)
	}})
}

// DeleteProDataOperation never touches this deployment's own local
// PocketBase data -- only push-relay's Supabase rows and the RevenueCat
// customer record. userID always comes from the caller's own auth token,
// never a request parameter.
func DeleteProDataOperation(userID string) error {
	return purgeRelayData(userID)
}

// purgeRelayData tells push-relay to delete this user's Supabase rows
// (relay_bindings, push_quota) and RevenueCat customer record. Unlike the
// notification-send path, this is NOT best-effort: there is no local
// fallback state here, so a failed purge must be reported as a failed
// deletion rather than silently swallowed.
func purgeRelayData(userID string) error {
	url := os.Getenv("PN_URL")
	if url == "" {
		return nil // no relay configured (e.g. self-hosted without push) -- nothing to purge
	}
	secret := os.Getenv("PN_RELAY_SECRET")
	body, err := json.Marshal(map[string]string{"user_id": userID})
	if err != nil {
		return err
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Relay-Delete-Pro-Data", "1")
	if secret != "" {
		req.Header.Set("X-Relay-Secret", secret)
	}
	resp, err := (&http.Client{Timeout: 5 * time.Second}).Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("push-relay pro-data purge: %s", resp.Status)
	}
	return nil
}
