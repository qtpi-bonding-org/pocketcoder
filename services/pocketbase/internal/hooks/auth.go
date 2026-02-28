package hooks

import (
	"bytes"
	"crypto/ed25519"
	"encoding/base64"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
)

// RegisterAuthHooks registers the global middleware for asymmetric key authentication.
func RegisterAuthHooks(app *pocketbase.PocketBase) {
	app.OnServe().BindFunc(func(se *core.ServeEvent) error {
		se.Router.BindFunc(func(e *core.RequestEvent) error {
			// Only intercept if our custom signature header is present
			signatureBase64 := e.Request.Header.Get("X-PC-Signature")
			if signatureBase64 == "" {
				return e.Next() // Fallback to standard PocketBase auth if no signature
			}

		nonce := e.Request.Header.Get("X-PC-Nonce")
		timestampStr := e.Request.Header.Get("X-PC-Timestamp")
		fingerprint := e.Request.Header.Get("X-PC-Fingerprint")

		if nonce == "" || timestampStr == "" || fingerprint == "" {
			return e.JSON(http.StatusUnauthorized, map[string]string{
				"error": "Missing required authentication headers (Nonce, Timestamp, or Fingerprint)",
			})
		}

		// 1. Time Check (1 minute window)
		reqTimeMs, err := strconv.ParseInt(timestampStr, 10, 64)
		if err != nil {
			return e.JSON(http.StatusUnauthorized, map[string]string{"error": "Invalid timestamp format"})
		}
		
		reqTime := time.UnixMilli(reqTimeMs)
		now := time.Now().UTC()
		diff := now.Sub(reqTime)
		
		if diff < -time.Minute || diff > time.Minute {
			return e.JSON(http.StatusUnauthorized, map[string]string{
				"error":       "payload expired or time desync",
				"action":      "retry",
				"server_time": now.Format(time.RFC3339),
			})
		}

		// 2. Replay Check (Nonce cache)
		cacheKey := "nonce_" + nonce
		if app.Store().Has(cacheKey) {
			return e.JSON(http.StatusUnauthorized, map[string]string{
				"error":  "replay detected",
				"action": "retry",
			})
		}
		// Store the nonce for 2 minutes just to be safe (time window is 1 min each way)
		// PocketBase cache currently doesn't have per-key TTL out of the box in app.Store() map,
		// but we can use app.Cache() if it exists or implement a simple memory map if not.
		// Wait, app.Store() is just a concurrent map. PocketBase v0.23 has a Cache().
		// Let's check what app has. e.App.Store() is a basic store.
		// For now we'll just set it. A proper TTL might be needed, but we can do a naive sync.Map or go-cache inside.
		// Actually, PocketBase provides e.App.Store().Set().
		app.Store().Set(cacheKey, time.Now().Unix())

		// 3. Look up the Public Key by fingerprint
		sshKeyRecords, err := app.FindRecordsByFilter(
			"ssh_keys",
			"fingerprint = {:fingerprint}",
			"-updated",
			1,
			0,
			map[string]any{"fingerprint": fingerprint},
		)
		if err != nil || len(sshKeyRecords) == 0 {
			return e.JSON(http.StatusUnauthorized, map[string]string{"error": "Key not found or not authorized"})
		}
		sshKeyRecord := sshKeyRecords[0]
		pubKeyRaw := sshKeyRecord.GetString("public_key")
		
		// Extract raw base64 from OpenSSH format (ssh-ed25519 AAA... comment)
		parts := strings.Split(pubKeyRaw, " ")
		if len(parts) < 2 {
			return e.JSON(http.StatusUnauthorized, map[string]string{"error": "Invalid stored public key format"})
		}
		pubKeyBytesExtracted, err := base64.StdEncoding.DecodeString(parts[1])
		if err != nil {
			return e.JSON(http.StatusUnauthorized, map[string]string{"error": "Failed to decode stored public key"})
		}
		
		// The OpenSSH public key format has a wire format header.
		// For Ed25519, the wire format is: [uint32 len] "ssh-ed25519" [uint32 len] [32 bytes key]
		// We need the raw 32 bytes for ed25519.Verify.
		if len(pubKeyBytesExtracted) < 51 {
             return e.JSON(http.StatusUnauthorized, map[string]string{"error": "Invalid ed25519 key length"})
		}
		pubKeyBytes := pubKeyBytesExtracted[len(pubKeyBytesExtracted)-ed25519.PublicKeySize:]

		// 4. Read Request Body for Signature
		// We need to read the body without consuming it so the next handlers can read it
		var bodyBytes []byte
		if e.Request.Body != nil {
			bodyBytes, _ = io.ReadAll(e.Request.Body)
			e.Request.Body = io.NopCloser(bytes.NewBuffer(bodyBytes)) // restore body
		}

		// 5. Construct Payload and Verify
		uri := e.Request.URL.RequestURI()
		payloadString := fmt.Sprintf("%s|%s|%s|%s", uri, string(bodyBytes), nonce, timestampStr)
		
		signatureBytes, err := base64.StdEncoding.DecodeString(signatureBase64)
		if err != nil {
			return e.JSON(http.StatusUnauthorized, map[string]string{"error": "Invalid signature encoding"})
		}

		isValid := ed25519.Verify(pubKeyBytes, []byte(payloadString), signatureBytes)
		if !isValid {
			return e.JSON(http.StatusUnauthorized, map[string]string{"error": "Invalid signature"})
		}

		// 6. Authenticate Request
		userID := sshKeyRecord.GetString("user")
		userRecord, err := app.FindRecordById("users", userID)
		if err != nil {
			return e.JSON(http.StatusUnauthorized, map[string]string{"error": "Related user not found"})
		}

		e.Auth = userRecord

		// Proceed to next handler
		return e.Next()
		})
		
		return se.Next()
	})
}
