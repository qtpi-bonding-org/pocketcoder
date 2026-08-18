package tlscert

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/pem"
	"math/big"
	"testing"
	"time"
)

func generateTestCert(t *testing.T, notAfter time.Time) (certPEM, keyPEM []byte) {
	t.Helper()
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatalf("generate key: %v", err)
	}
	serial, err := rand.Int(rand.Reader, new(big.Int).Lsh(big.NewInt(1), 128))
	if err != nil {
		t.Fatalf("generate serial: %v", err)
	}
	template := &x509.Certificate{
		SerialNumber: serial,
		Subject:      pkix.Name{CommonName: "example.com"},
		NotBefore:    time.Now().Add(-time.Minute),
		NotAfter:     notAfter,
		KeyUsage:     x509.KeyUsageDigitalSignature | x509.KeyUsageKeyEncipherment,
		DNSNames:     []string{"example.com"},
	}
	der, err := x509.CreateCertificate(rand.Reader, template, template, &key.PublicKey, key)
	if err != nil {
		t.Fatalf("create certificate: %v", err)
	}
	keyDER, err := x509.MarshalPKCS8PrivateKey(key)
	if err != nil {
		t.Fatalf("marshal key: %v", err)
	}
	return pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: der}),
		pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: keyDER})
}

func TestValidateBundleRejectsExpiredCertificate(t *testing.T) {
	certPEM, keyPEM := generateTestCert(t, time.Now().Add(-time.Hour))
	err := ValidateBundle(certPEM, keyPEM)
	if err == nil {
		t.Fatal("expected an expired certificate to be rejected")
	}
}

func TestValidateBundleRejectsMismatchedKey(t *testing.T) {
	certPEM, _ := generateTestCert(t, time.Now().Add(time.Hour))
	_, otherKeyPEM := generateTestCert(t, time.Now().Add(time.Hour))
	err := ValidateBundle(certPEM, otherKeyPEM)
	if err == nil {
		t.Fatal("expected a mismatched key to be rejected")
	}
}

func TestValidateBundleAcceptsAFreshMatchingPair(t *testing.T) {
	certPEM, keyPEM := generateTestCert(t, time.Now().Add(time.Hour))
	if err := ValidateBundle(certPEM, keyPEM); err != nil {
		t.Fatalf("ValidateBundle: %v", err)
	}
}
