package trust

import (
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/hex"
	"testing"
	"time"

	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/contract"
)

func TestDelegatedVerification(t *testing.T) {
	publicKey, privateKey, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	der, err := x509.MarshalPKIXPublicKey(publicKey)
	if err != nil {
		t.Fatal(err)
	}
	payload := []byte(`{"schemaVersion":1}`)
	digest := sha256.Sum256(payload)
	envelope := contract.SignatureEnvelope{
		SchemaVersion: 1, Algorithm: "ed25519", Role: "release", KeyID: "operations",
		PayloadSHA256: hex.EncodeToString(digest[:]),
		Signature:     base64.StdEncoding.EncodeToString(ed25519.Sign(privateKey, payload)),
	}
	delegation := contract.RootDelegation{Roles: map[string][]contract.DelegatedKey{
		"release": {{KeyID: "operations", Algorithm: "ed25519", PublicKey: base64.StdEncoding.EncodeToString(der), ValidFrom: "2026-01-01T00:00:00Z"}},
	}}
	verifier := Verifier{Now: func() time.Time { return time.Date(2026, 8, 12, 0, 0, 0, 0, time.UTC) }}
	if err := verifier.VerifyDelegated(payload, envelope, "release", delegation); err != nil {
		t.Fatal(err)
	}
	payload[0] = '['
	if err := verifier.VerifyDelegated(payload, envelope, "release", delegation); err == nil {
		t.Fatal("expected modified payload rejection")
	}
}
