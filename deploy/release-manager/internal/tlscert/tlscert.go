package tlscert

import (
	"bufio"
	"crypto/tls"
	"crypto/x509"
	"encoding/base64"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

// Bundle is the JSON representation exchanged with the Flutter client.
type Bundle struct {
	Hostname             string `json:"hostname"`
	Issuer               string `json:"issuer,omitempty"`
	CertificatePemBase64 string `json:"certificatePemBase64"`
	PrivateKeyPemBase64  string `json:"privateKeyPemBase64"`
}

var searchRoots = []string{
	"/var/lib/caddy/.local/share/caddy/certificates",
	"/var/lib/caddy/.config/caddy/certificates",
	"/var/lib/caddy/.local/share/caddy",
	"/var/lib/caddy/.config/caddy",
}

var safeIdentifier = regexp.MustCompile(`^[A-Za-z0-9._-]+$`)

// ValidateBundle verifies that the PEM certificate and private key form a
// usable pair and that the certificate has not expired.
func ValidateBundle(certPEM, keyPEM []byte) error {
	pair, err := tls.X509KeyPair(certPEM, keyPEM)
	if err != nil {
		return fmt.Errorf("parse certificate and private key: %w", err)
	}
	if len(pair.Certificate) == 0 {
		return fmt.Errorf("certificate bundle contains no certificate")
	}
	cert, err := x509.ParseCertificate(pair.Certificate[0])
	if err != nil {
		return fmt.Errorf("parse certificate: %w", err)
	}
	if time.Now().After(cert.NotAfter) {
		return fmt.Errorf("certificate expired at %s", cert.NotAfter.Format("2006-01-02T15:04:05Z07:00"))
	}
	return nil
}

func readBaseDomain(path string) (string, error) {
	file, err := os.Open(path)
	if err != nil {
		return "", fmt.Errorf("open domain configuration: %w", err)
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if strings.HasPrefix(line, "BASE_DOMAIN=") {
			domain := strings.TrimPrefix(line, "BASE_DOMAIN=")
			if domain != "" {
				return domain, nil
			}
		}
	}
	if err := scanner.Err(); err != nil {
		return "", fmt.Errorf("read domain configuration: %w", err)
	}
	return "", fmt.Errorf("BASE_DOMAIN not found in %s", path)
}

func ExportBundle() (Bundle, error) {
	domain, err := readBaseDomain("/etc/pocketcoder/domain.env")
	if err != nil {
		return Bundle{}, err
	}
	if !safeIdentifier.MatchString(domain) {
		return Bundle{}, fmt.Errorf("invalid base domain %q", domain)
	}
	for _, root := range searchRoots {
		matches, err := filepath.Glob(filepath.Join(root, "*", domain, domain+".crt"))
		if err != nil {
			return Bundle{}, fmt.Errorf("glob certificates under %s: %w", root, err)
		}
		for _, certPath := range matches {
			keyPath := strings.TrimSuffix(certPath, ".crt") + ".key"
			certPEM, err := os.ReadFile(certPath)
			if err != nil {
				continue
			}
			keyPEM, err := os.ReadFile(keyPath)
			if err != nil {
				continue
			}
			if err := ValidateBundle(certPEM, keyPEM); err != nil {
				continue
			}
			issuer := filepath.Base(filepath.Dir(filepath.Dir(certPath)))
			if !safeIdentifier.MatchString(issuer) {
				continue
			}
			return Bundle{
				Hostname:             domain,
				Issuer:               issuer,
				CertificatePemBase64: base64.StdEncoding.EncodeToString(certPEM),
				PrivateKeyPemBase64:  base64.StdEncoding.EncodeToString(keyPEM),
			}, nil
		}
	}
	return Bundle{}, fmt.Errorf("no valid certificate found for domain %q", domain)
}

func ImportBundle(bundle Bundle) error {
	if !safeIdentifier.MatchString(bundle.Hostname) {
		return fmt.Errorf("invalid certificate hostname %q", bundle.Hostname)
	}
	if bundle.Issuer == "" {
		bundle.Issuer = "acme-v02.api.letsencrypt.org-directory"
	}
	if !safeIdentifier.MatchString(bundle.Issuer) {
		return fmt.Errorf("invalid certificate issuer %q", bundle.Issuer)
	}
	certPEM, err := base64.StdEncoding.DecodeString(bundle.CertificatePemBase64)
	if err != nil {
		return fmt.Errorf("decode certificate PEM: %w", err)
	}
	keyPEM, err := base64.StdEncoding.DecodeString(bundle.PrivateKeyPemBase64)
	if err != nil {
		return fmt.Errorf("decode private key PEM: %w", err)
	}
	if err := ValidateBundle(certPEM, keyPEM); err != nil {
		return fmt.Errorf("validate certificate bundle: %w", err)
	}
	dir := filepath.Join("/var/lib/caddy/.local/share/caddy/certificates", bundle.Issuer, bundle.Hostname)
	if err := os.MkdirAll(dir, 0700); err != nil {
		return fmt.Errorf("create certificate directory: %w", err)
	}
	certPath := filepath.Join(dir, bundle.Hostname+".crt")
	if err := os.WriteFile(certPath, certPEM, 0644); err != nil {
		return fmt.Errorf("write certificate: %w", err)
	}
	keyPath := filepath.Join(dir, bundle.Hostname+".key")
	if err := os.WriteFile(keyPath, keyPEM, 0600); err != nil {
		return fmt.Errorf("write private key: %w", err)
	}
	if err := exec.Command("systemctl", "restart", "caddy").Run(); err != nil {
		return fmt.Errorf("restart caddy: %w", err)
	}
	return nil
}
