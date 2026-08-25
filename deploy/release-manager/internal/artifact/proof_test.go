package artifact

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"os"
	"strings"
	"testing"
)

func TestProofSignerAndVectorNormalization(t *testing.T) {
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	der, err := x509.MarshalPKCS8PrivateKey(key)
	if err != nil {
		t.Fatal(err)
	}
	signer, err := NewProofSignerFromPKCS8Base64(base64.StdEncoding.EncodeToString(der), "credential")
	if err != nil {
		t.Fatal(err)
	}
	proof, err := signer.SignProof("GET", "https://images.relay.pocketcoder.org/v1/artifacts/abc123?x=1")
	if err != nil {
		t.Fatal(err)
	}
	parts := strings.Split(proof, ".")
	if len(parts) != 3 {
		t.Fatalf("proof parts = %d", len(parts))
	}
	claimsBytes, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		t.Fatal(err)
	}
	var claims map[string]any
	if err := json.Unmarshal(claimsBytes, &claims); err != nil {
		t.Fatal(err)
	}
	if claims["htu"] != "https://images.relay.pocketcoder.org/v1/artifacts/abc123" || claims["htm"] != "GET" {
		t.Fatalf("claims = %#v", claims)
	}
	var vector struct {
		RootJWK map[string]string `json:"rootJwk"`
		Proof   string            `json:"proof"`
	}
	data, err := os.ReadFile("../../../../workers/image-relay/scripts/test-vectors.json")
	if err != nil {
		t.Fatal(err)
	}
	if err := json.Unmarshal(data, &vector); err != nil {
		t.Fatal(err)
	}
	jwk := publicJwk(&key.PublicKey)
	if jwk["kty"] != "EC" || jwk["crv"] != "P-256" || jwk["x"] == "" || jwk["y"] == "" {
		t.Fatalf("bad jwk: %#v", jwk)
	}
	vp := strings.Split(vector.Proof, ".")
	vb, err := base64.RawURLEncoding.DecodeString(vp[1])
	if err != nil {
		t.Fatal(err)
	}
	var vc struct {
		HTU string `json:"htu"`
	}
	if err := json.Unmarshal(vb, &vc); err != nil {
		t.Fatal(err)
	}
	normalized, err := normalizeHtu(vc.HTU)
	if err != nil {
		t.Fatal(err)
	}
	if normalized != vc.HTU {
		t.Fatalf("vector htu normalized to %q", normalized)
	}
	if vector.RootJWK["kty"] != "EC" || vector.RootJWK["crv"] != "P-256" {
		t.Fatalf("bad vector rootJwk: %#v", vector.RootJWK)
	}
}
