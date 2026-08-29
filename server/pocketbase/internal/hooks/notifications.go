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
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/operation"
)

// SendLiveActivityUpdate posts the live-activity payload directly to
// push-relay. fcmToken is the device's normal FCM registration token
// (devices.push_token) -- FCM's v1 API requires it alongside the
// activity's own push token in the same request to deliver an
// ActivityKit update (see the push-relay Worker's push_type ==
// "live_activity" branch).
func SendLiveActivityUpdate(token, fcmToken, userID string, state LiveActivityContentState, version int, event, attributesType string, attributes any) error {
	url := os.Getenv("PN_URL")
	if url == "" {
		return nil
	}
	payload := map[string]any{
		"push_type": "live_activity", "user_id": userID,
		"token": token, "fcm_token": fcmToken,
		"content_state": state, "content_state_version": version,
		"event": event, "stale_date": time.Now().Add(time.Hour).Unix(),
	}
	if event == "start" {
		payload["attributes_type"] = attributesType
		payload["attributes"] = attributes
	}
	body, err := json.Marshal(payload)
	if err != nil {
		return err
	}
	req, err := http.NewRequest(http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	if secret := os.Getenv("PN_RELAY_SECRET"); secret != "" {
		req.Header.Set("X-Relay-Secret", secret)
	}
	resp, err := (&http.Client{}).Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("live activity relay: %s", resp.Status)
	}
	return nil
}

// PushProvider defines the interface for different notification services.
// extra carries notification-type-specific structured data (e.g. a pending
// permission's request_id and offered options) that a provider merges into
// its payload if it can; a provider with no such support just ignores it.
type PushProvider interface {
	Send(token, title, body string, extra map[string]string) error
}

// NtfyDirectProvider sends notifications directly to a UnifiedPush (ntfy) endpoint.
// This preserves the "Zero-Trust" sovereign architecture.
type NtfyDirectProvider struct {
	ChatID string
	Type   string
}

// extra is ignored here: ntfy's direct path has no structured-action
// support yet -- that's out of scope for this slice.
func (p *NtfyDirectProvider) Send(endpoint, title, body string, extra map[string]string) error {
	req, err := http.NewRequest("POST", endpoint, strings.NewReader(body))
	if err != nil {
		return err
	}

	// Deep link: pocketcoder://chat/{id} if we have a chat, else root
	clickURL := "pocketcoder://"
	if p.ChatID != "" {
		clickURL = "pocketcoder://chat/" + p.ChatID
	}

	// ntfy specific headers
	req.Header.Set("Title", title)
	req.Header.Set("Click", clickURL)
	req.Header.Set("Priority", "high")
	if p.Type != "" {
		req.Header.Set("Tags", p.Type)
	}

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
// The Worker handles subscription verification (RevenueCat), rate limiting
// (Supabase), and FCM v1 delivery — PocketBase just fires and forgets.
type FcmRelayProvider struct {
	RelayURL string
	UserID   string
	ChatID   string
	Type     string
}

func (p *FcmRelayProvider) Send(token, title, body string, extra map[string]string) error {
	if p.RelayURL == "" {
		log.Printf("⚠️ [Push/FCM] Relay URL not configured. Skipping.")
		return nil
	}

	payload := map[string]string{
		"token":   token,
		"user_id": p.UserID,
		"service": "fcm",
		"title":   title,
		"message": body,
		"type":    p.Type,
		"chat":    p.ChatID,
	}
	for k, v := range extra {
		payload[k] = v
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

// RegisterNotificationHooks registers hooks for triggering push notifications
// and the /api/push custom endpoint.
func RegisterNotificationHooks(app core.App) {
}

func AddPushOperations(app core.App, registry *operation.Registry) {
	registry.Add(operation.Route{OperationID: "sendPushNotification", Method: http.MethodPost, Path: "/api/pocketcoder/v1/push", Auth: true, Action: func(re *core.RequestEvent) error {
		if err := SendPushOperation(app, re); err != nil {
			return err
		}
		return re.JSON(200, map[string]any{"ok": true})
	}})
}

func SendPushOperation(app core.App, re *core.RequestEvent) error {
	// Only agent or admin can send push notifications
	role := re.Auth.GetString("role")
	if role != "agent" && role != "admin" {
		return apis.NewApiError(403, "Insufficient permissions", nil)
	}

	var input struct {
		UserID  string `json:"user_id"`
		Title   string `json:"title"`
		Message string `json:"message"`
		Type    string `json:"type"`
		ChatID  string `json:"chat"`
	}

	if err := re.BindBody(&input); err != nil {
		return apis.NewApiError(400, "Invalid request body", nil)
	}

	if input.UserID == "" || input.Type == "" {
		return apis.NewApiError(400, "user_id and type are required", nil)
	}

	go func() {
		// This response has already been sent by the time this runs, so
		// a panic here (e.g. the app tearing down mid-flight, which a
		// test reproduced as a nil-pointer panic inside PocketBase's own
		// query path) would otherwise escape unrecovered and crash the
		// whole process instead of just failing to notify.
		defer func() {
			if r := recover(); r != nil {
				log.Printf("[Push] dispatch panic: %v", r)
			}
		}()
		if err := SendPushNotification(app, input.UserID, input.Title, input.Message, input.Type, input.ChatID); err != nil {
			log.Printf("[Push] dispatch: %v", err)
		}
	}()

	return nil
}

// SendPushNotification is the unified dispatch function.
// Flow: rules check -> presence check -> device dispatch
func SendPushNotification(app core.App, userID, title, message, notifType, chatID string) error {
	return SendPushNotificationWithExtra(app, userID, title, message, notifType, chatID, nil)
}

// SendPushNotificationWithExtra is SendPushNotification plus structured
// type-specific data (e.g. a pending permission's request_id and offered
// options) merged into the outgoing payload -- see PushProvider.Send.
func SendPushNotificationWithExtra(app core.App, userID, title, message, notifType, chatID string, extra map[string]string) error {
	if !isNotificationTypeEnabled(app, userID, notifType) {
		log.Printf("🔕 [Push] User %s has disabled '%s' notifications. Skipping.", userID, notifType)
		return nil
	}

	if IsUserOnline(app, userID) {
		log.Printf("🔔 [Push] User %s is online. Suppressing '%s' notification.", userID, notifType)
		return nil
	}

	return dispatchToDevices(app, userID, title, message, notifType, chatID, extra)
}

// isNotificationTypeEnabled checks the user's notification_rules record.
// Returns true if the type is enabled or if no rules exist (opt-out model).
func isNotificationTypeEnabled(app core.App, userID, notifType string) bool {
	record, err := app.FindFirstRecordByFilter(
		"notification_rules",
		"user = {:userID}",
		map[string]any{"userID": userID},
	)
	if err != nil {
		// No rules record = all types enabled (default)
		return true
	}

	rulesRaw := record.Get("rules")
	if rulesRaw == nil {
		return true
	}

	var rules map[string]bool
	switch v := rulesRaw.(type) {
	case string:
		if err := json.Unmarshal([]byte(v), &rules); err != nil {
			log.Printf("⚠️ [Push] Failed to parse notification rules: %v", err)
			return true
		}
	case map[string]any:
		rules = make(map[string]bool)
		for k, val := range v {
			if b, ok := val.(bool); ok {
				rules[k] = b
			}
		}
	default:
		return true
	}

	// If the type is not in the map, default to enabled
	enabled, exists := rules[notifType]
	if !exists {
		return true
	}
	return enabled
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

// dispatchToDevices sends notifications to every active device registered to the user.
func dispatchToDevices(app core.App, userID, title, message, notifType, chatID string, extra map[string]string) error {
	devices, err := app.FindRecordsByFilter(
		"devices",
		"user = {:userID} && is_active = true",
		"",
		0, 0,
		map[string]any{"userID": userID},
	)
	if err != nil {
		log.Printf("❌ [Push] Error searching for devices: %v", err)
		return err
	}

	if len(devices) == 0 {
		return nil
	}

	providerMode := os.Getenv("PN_PROVIDER")
	relayURL := os.Getenv("PN_URL")

	ntfyDirect := &NtfyDirectProvider{ChatID: chatID, Type: notifType}
	fcmRelay := &FcmRelayProvider{RelayURL: relayURL, UserID: userID, ChatID: chatID, Type: notifType}

	for _, device := range devices {
		serviceType := device.GetString("push_service")
		token := device.GetString("push_token")

		var provider PushProvider

		switch serviceType {
		case "unifiedpush":
			provider = ntfyDirect
		case "fcm":
			if strings.ToUpper(providerMode) == "FCM" {
				provider = fcmRelay
			} else {
				log.Printf("⚠️ [Push] Skipping FCM notification for device %s (PN_PROVIDER != FCM)", device.Id)
			}
		default:
			log.Printf("⚠️ [Push] Unknown service %s on device %s", serviceType, device.Id)
		}

		if provider != nil {
			if err := provider.Send(token, title, message, extra); err != nil {
				log.Printf("❌ [Push] %s dispatch error: %v", serviceType, err)
			} else {
				log.Printf("✅ [Push] '%s' notification dispatched via %s", notifType, serviceType)
			}
		}
	}
	return nil
}
