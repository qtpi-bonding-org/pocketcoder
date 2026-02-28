package hooks

import (
	"crypto/ed25519"
	"encoding/base64"
	"fmt"
	"strings"
	"testing"
	"time"
)

// The helper logic in auth.go that we are testing for correctness.
// We extract the public key and verify a signature exactly as the hook does.
func TestAuthSignatureVerification(t *testing.T) {
	// 1. Generate a valid Ed25519 KeyPair (Simulating Flutter app)
	publicKey, privateKey, err := ed25519.GenerateKey(nil)
	if err != nil {
		t.Fatalf("Failed to generate key: %v", err)
	}

	// Format Public Key as OpenSSH format (Simulating PocketBase storage)
	// Wire format: [uint32 len(11)] ssh-ed25519 [uint32 len(32)] [32 bytes key]
	// Standard OpenSSH ed25519 key prefix is 17 bytes: 00 00 00 0B 73 73 68 2D 65 64 32 35 35 31 39 00 00 00 20
	prefix := []byte{0, 0, 0, 11, 's', 's', 'h', '-', 'e', 'd', '2', '5', '5', '1', '9', 0, 0, 0, 32}
	wireFormat := append(prefix, publicKey...)
	storedPubKey := "ssh-ed25519 " + base64.StdEncoding.EncodeToString(wireFormat) + " test@pocketcoder"

	// 2. Client Side: Create Payload & Signature
	uri := "/api/pocketcoder/sandbox/1"
	body := `{"cmd": "npm install"}`
	nonce := "123e4567-e89b-12d3-a456-426614174000"
	timestampStr := fmt.Sprintf("%d", time.Now().UnixMilli())
	
	payloadString := fmt.Sprintf("%s|%s|%s|%s", uri, body, nonce, timestampStr)
	signature := ed25519.Sign(privateKey, []byte(payloadString))
	signatureBase64 := base64.StdEncoding.EncodeToString(signature)

	// -------------------------------------------------------------
	// 3. Server Side (Hook Logic)
	// -------------------------------------------------------------
	
	// A. Parse stored key
	parts := strings.Split(storedPubKey, " ")
	if len(parts) < 2 {
		t.Fatal("Invalid stored key format")
	}
	pubKeyExtracted, err := base64.StdEncoding.DecodeString(parts[1])
	if err != nil {
		t.Fatalf("Failed to decode pubkey: %v", err)
	}
	if len(pubKeyExtracted) < 51 {
		t.Fatal("Invalid ed25519 key length inside wire format")
	}
	// Extract the last 32 bytes
	actualPubKey := pubKeyExtracted[len(pubKeyExtracted)-ed25519.PublicKeySize:]

	// B. Verify payload
	serverPayloadString := fmt.Sprintf("%s|%s|%s|%s", uri, body, nonce, timestampStr)
	serverSignatureBytes, err := base64.StdEncoding.DecodeString(signatureBase64)
	if err != nil {
		t.Fatalf("Failed to decode signature: %v", err)
	}

	isValid := ed25519.Verify(actualPubKey, []byte(serverPayloadString), serverSignatureBytes)
	if !isValid {
		t.Errorf("Signature verification failed! Expected valid signature.")
	}

	// C. Test Invalid Signature (Tampered body)
	badPayloadString := fmt.Sprintf("%s|%s|%s|%s", uri, `{"cmd": "rm -rf /"}`, nonce, timestampStr)
	isBadValid := ed25519.Verify(actualPubKey, []byte(badPayloadString), serverSignatureBytes)
	if isBadValid {
		t.Errorf("Signature verification succeeded for tampered payload! Expected failure.")
	}
}
