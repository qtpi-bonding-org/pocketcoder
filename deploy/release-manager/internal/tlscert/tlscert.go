package tlscert

import (
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/pem"
	"fmt"
	"os"
	"path/filepath"
)

// CAFingerprint is the public identity of Caddy's internal root CA and the
// certificate clients can install as a trust anchor. It intentionally has no
// private-key material.
type CAFingerprint struct {
	Fingerprint          string `json:"fingerprint"`
	CertificatePemBase64 string `json:"certificatePemBase64"`
}

// searchRoots are the possible Caddy data roots used by the NixOS service and
// by supported non-NixOS installations. The CA is below pki, not certificates.
var searchRoots = []string{
	"/var/lib/caddy/.local/share/caddy",
	"/var/lib/caddy/.config/caddy",
}

// ExportCAFingerprint returns the SPKI SHA-256 fingerprint and public PEM
// certificate for Caddy's internal root CA. Only root.crt is trusted/exported;
// the intermediate is deliberately not needed for this stable pin.
func ExportCAFingerprint() (CAFingerprint, error) {
	var lastErr error
	for _, root := range searchRoots {
		caPath := filepath.Join(root, "pki", "authorities", "local", "root.crt")
		pemBytes, err := os.ReadFile(caPath)
		if err != nil {
			lastErr = err
			continue
		}
		block, _ := pem.Decode(pemBytes)
		if block == nil || block.Type != "CERTIFICATE" {
			lastErr = fmt.Errorf("%s does not contain a PEM certificate", caPath)
			continue
		}
		cert, err := x509.ParseCertificate(block.Bytes)
		if err != nil {
			lastErr = fmt.Errorf("parse internal CA certificate %s: %w", caPath, err)
			continue
		}
		digest := sha256.Sum256(cert.RawSubjectPublicKeyInfo)
		return CAFingerprint{
			Fingerprint:          "SHA256:" + base64.RawStdEncoding.EncodeToString(digest[:]),
			CertificatePemBase64: base64.StdEncoding.EncodeToString(pemBytes),
		}, nil
	}
	if lastErr == nil {
		lastErr = os.ErrNotExist
	}
	return CAFingerprint{}, fmt.Errorf("internal CA root certificate not found: %w", lastErr)
}
