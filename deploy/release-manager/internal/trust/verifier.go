package trust

import (
	"crypto/ed25519"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/hex"
	"encoding/pem"
	"fmt"
	"time"

	"github.com/qtpi-bonding-org/pocketcoder/deploy/release-manager/internal/contract"
)

type Verifier struct {
	RootPublicKey ed25519.PublicKey
	Now           func() time.Time
}

func ParseRootPublicKeyPEM(data []byte) (ed25519.PublicKey, error) {
	block, _ := pem.Decode(data)
	if block == nil {
		return nil, fmt.Errorf("root public key is not PEM")
	}
	key, err := x509.ParsePKIXPublicKey(block.Bytes)
	if err != nil {
		return nil, fmt.Errorf("parse root public key: %w", err)
	}
	publicKey, ok := key.(ed25519.PublicKey)
	if !ok {
		return nil, fmt.Errorf("root public key is not Ed25519")
	}
	return publicKey, nil
}

func (verifier Verifier) VerifyRoot(payload []byte, envelope contract.SignatureEnvelope, delegation contract.RootDelegation) error {
	if envelope.KeyID != delegation.RootKeyID {
		return fmt.Errorf("root envelope key does not match delegation root")
	}
	return verify(payload, envelope, "root", verifier.RootPublicKey)
}

func (verifier Verifier) VerifyDelegated(payload []byte, envelope contract.SignatureEnvelope, role string, delegation contract.RootDelegation) error {
	now := time.Now().UTC()
	if verifier.Now != nil {
		now = verifier.Now().UTC()
	}
	for _, revoked := range delegation.RevokedKeyIDs {
		if revoked == envelope.KeyID {
			return fmt.Errorf("delegated key %q is revoked", envelope.KeyID)
		}
	}
	for _, candidate := range delegation.Roles[role] {
		if candidate.KeyID != envelope.KeyID || candidate.Algorithm != "ed25519" {
			continue
		}
		validFrom, err := time.Parse(time.RFC3339, candidate.ValidFrom)
		if err != nil {
			return fmt.Errorf("invalid delegated key start time: %w", err)
		}
		if now.Before(validFrom) {
			continue
		}
		if candidate.ValidUntil != nil {
			validUntil, err := time.Parse(time.RFC3339, *candidate.ValidUntil)
			if err != nil {
				return fmt.Errorf("invalid delegated key end time: %w", err)
			}
			if now.After(validUntil) {
				continue
			}
		}
		key, err := parseDelegatedKey(candidate.PublicKey)
		if err != nil {
			return err
		}
		return verify(payload, envelope, role, key)
	}
	return fmt.Errorf("no active delegation for %s/%s", role, envelope.KeyID)
}

func parseDelegatedKey(encoded string) (ed25519.PublicKey, error) {
	der, err := base64.StdEncoding.DecodeString(encoded)
	if err != nil {
		return nil, fmt.Errorf("decode delegated public key: %w", err)
	}
	key, err := x509.ParsePKIXPublicKey(der)
	if err != nil {
		return nil, fmt.Errorf("parse delegated public key: %w", err)
	}
	publicKey, ok := key.(ed25519.PublicKey)
	if !ok {
		return nil, fmt.Errorf("delegated public key is not Ed25519")
	}
	return publicKey, nil
}

func verify(payload []byte, envelope contract.SignatureEnvelope, role string, key ed25519.PublicKey) error {
	if envelope.SchemaVersion != contract.SchemaVersion || envelope.Algorithm != "ed25519" || envelope.Role != role {
		return fmt.Errorf("invalid %s signature envelope", role)
	}
	digest := sha256.Sum256(payload)
	if envelope.PayloadSHA256 != hex.EncodeToString(digest[:]) {
		return fmt.Errorf("%s payload digest mismatch", role)
	}
	signature, err := base64.StdEncoding.DecodeString(envelope.Signature)
	if err != nil {
		return fmt.Errorf("decode %s signature: %w", role, err)
	}
	if !ed25519.Verify(key, payload, signature) {
		return fmt.Errorf("%s signature is invalid", role)
	}
	return nil
}
