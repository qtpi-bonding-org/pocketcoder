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

// @pocketcoder-core: Notification Dispatcher. Sends push notifications based on record events and user presence.
package hooks

import (
	"bytes"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strings"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
)

// PushProvider defines the interface for different notification services.
type PushProvider interface {
	Send(token, title, body string) error
}

// NtfyDirectProvider sends notifications directly to a UnifiedPush (ntfy) endpoint.
// This preserves the "Zero-Trust" sovereign architecture.
type NtfyDirectProvider struct{}

func (p *NtfyDirectProvider) Send(endpoint, title, body string) error {
	req, err := http.NewRequest("POST", endpoint, strings.NewReader(body))
	if err != nil {
		return err
	}

	// ntfy specific headers
	req.Header.Set("Title", title)
	req.Header.Set("Click", "pocketcoder://") // Deep link into the app
	req.Header.Set("Priority", "high")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		log.Printf("❌ [Push/ntfy] Direct dispatch failed: %s", resp.Status)
	}
	return nil
}

// FcmRelayProvider routes notifications through a Cloudflare Worker relay.
type FcmRelayProvider struct {
	RelayURL string
}

func (p *FcmRelayProvider) Send(token, title, body string) error {
	if p.RelayURL == "" {
		log.Printf("⚠️ [Push/FCM] Relay URL not configured. Skipping.")
		return nil
	}

	payload := map[string]string{
		"token":     token,
		"title":     title,
		"body":      body,
		"click_url": "pocketcoder://",
		"service":   "fcm",
	}

	bodyBytes, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	req, err := http.NewRequest("POST", p.RelayURL, bytes.NewBuffer(bodyBytes))
	if err != nil {
		return err
	}

	req.Header.Set("Content-Type", "application/json")
	// Optional: add a secret token for the Cloudflare Relay
	if secret := os.Getenv("PN_RELAY_SECRET"); secret != "" {
		req.Header.Set("X-Relay-Secret", secret)
	}

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		log.Printf("❌ [Push/FCM] Relay error: %s", resp.Status)
	} else {
		log.Printf("✅ [Push/FCM] Dispatched to Relay.")
	}
	return nil
}

// RegisterNotificationHooks registers hooks for triggering push notifications.
func RegisterNotificationHooks(app *pocketbase.PocketBase) {
	app.OnRecordAfterCreateSuccess("permissions").BindFunc(func(e *core.RecordEvent) error {
		// 1. Gating: Only notify for waiting authorizations
		if e.Record.GetString("status") != "draft" {
			return e.Next()
		}

		// 2. Resolve User
		userID := ""
		chatId := e.Record.GetString("chat")
		if chatId != "" {
			chat, err := e.App.FindRecordById("chats", chatId)
			if err == nil {
				userID = chat.GetString("user")
			}
		}

		if userID == "" {
			return e.Next()
		}

		// 3. Presence Check: If ANY device is online, suppress PNs
		if IsUserOnline(e.App, userID) {
			log.Printf("🔔 [Notifications] User %s is online. Suppressing push notifications.", userID)
			return e.Next()
		}

		// 4. Dispatch to ALL active devices
		go DispatchNotifications(e.App, userID, e.Record)

		return e.Next()
	})
}

// IsUserOnline checks if the user has an active Realtime (SSE) connection.
func IsUserOnline(app core.App, userID string) bool {
	broker := app.SubscriptionsBroker()
	if broker == nil {
		return false
	}
	
	clients := broker.Clients()
	for _, c := range clients {
		if val := c.Get("authRecord"); val != nil {
			if record, ok := val.(*core.Record); ok && record.Id == userID {
				return true
			}
		}
	}
	return false
}

// DispatchNotifications sends notifications to every active device registered to the user.
func DispatchNotifications(app core.App, userID string, permission *core.Record) {
	devices, err := app.FindRecordsByFilter(
		"devices",
		"user = {:userID} && is_active = true",
		"-created",
		0, 0,
		map[string]any{"userID": userID},
	)
	if err != nil {
		log.Printf("❌ [Push] Error searching for devices: %v", err)
		return
	}

	if len(devices) == 0 {
		return
	}

	// Provider Configuration
	providerMode := os.Getenv("PN_PROVIDER") // "FCM" or "NTFY" (or empty for FOSS-direct only)
	relayURL := os.Getenv("PN_URL")

	ntfyDirect := &NtfyDirectProvider{}
	fcmRelay := &FcmRelayProvider{RelayURL: relayURL}

	for _, device := range devices {
		serviceType := device.GetString("push_service")
		token := device.GetString("push_token")
		title := "SIGNATURE REQUIRED"
		body := "Action: " + permission.GetString("permission")

		var provider PushProvider

		switch serviceType {
		case "unifiedpush":
			// Sovereign Direct: UnifiedPush endpoints are always POSTed to directly
			provider = ntfyDirect
		case "fcm":
			// Cloudflare Relay: Only dispatch if PN_PROVIDER is set to FCM (Pro/App Mode)
			if strings.ToUpper(providerMode) == "FCM" {
				provider = fcmRelay
			} else {
				log.Printf("⚠️ [Push] Skipping FCM notification for device %s (PN_PROVIDER != FCM)", device.Id)
			}
		default:
			log.Printf("⚠️ [Push] Unknown service %s on device %s", serviceType, device.Id)
		}

		if provider != nil {
			if err := provider.Send(token, title, body); err != nil {
				log.Printf("❌ [Push] %s dispatch error: %v", serviceType, err)
			} else {
				log.Printf("✅ [Push] Notification dispatched via %s", serviceType)
			}
		}
	}
}
