package tlscert

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/sha256"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/base64"
	"encoding/pem"
	"math/big"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func generateTestCACert(t *testing.T) []byte {
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
		Subject:      pkix.Name{CommonName: "PocketCoder Local Root"},
		NotBefore:    time.Now().Add(-time.Minute), NotAfter: time.Now().Add(time.Hour),
		IsCA: true, BasicConstraintsValid: true,
		KeyUsage: x509.KeyUsageCertSign | x509.KeyUsageCRLSign | x509.KeyUsageDigitalSignature,
	}
	der, err := x509.CreateCertificate(rand.Reader, template, template, &key.PublicKey, key)
	if err != nil {
		t.Fatalf("create certificate: %v", err)
	}
	return pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: der})
}

func TestExportCAFingerprint(t *testing.T) {
	root := t.TempDir()
	caDir := filepath.Join(root, "pki", "authorities", "local")
	if err := os.MkdirAll(caDir, 0700); err != nil {
		t.Fatal(err)
	}
	caPEM := generateTestCACert(t)
	if err := os.WriteFile(filepath.Join(caDir, "root.crt"), caPEM, 0600); err != nil {
		t.Fatal(err)
	}

	oldRoots := searchRoots
	searchRoots = []string{root}
	t.Cleanup(func() { searchRoots = oldRoots })

	result, err := ExportCAFingerprint()
	if err != nil {
		t.Fatalf("ExportCAFingerprint: %v", err)
	}
	block, _ := pem.Decode(caPEM)
	cert, err := x509.ParseCertificate(block.Bytes)
	if err != nil {
		t.Fatal(err)
	}
	digest := sha256.Sum256(cert.RawSubjectPublicKeyInfo)
	expected := "SHA256:" + base64.RawStdEncoding.EncodeToString(digest[:])
	if result.Fingerprint != expected {
		t.Fatalf("fingerprint = %q, want %q", result.Fingerprint, expected)
	}
	decoded, err := base64.StdEncoding.DecodeString(result.CertificatePemBase64)
	if err != nil || !strings.EqualFold(string(decoded), string(caPEM)) {
		t.Fatalf("exported certificate PEM does not match root certificate")
	}
}

func TestExportCAFingerprintRequiresRoot(t *testing.T) {
	oldRoots := searchRoots
	searchRoots = []string{t.TempDir()}
	t.Cleanup(func() { searchRoots = oldRoots })
	if _, err := ExportCAFingerprint(); err == nil {
		t.Fatal("expected missing root certificate error")
	}
}
