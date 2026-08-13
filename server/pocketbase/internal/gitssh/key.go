package gitssh

import (
	"crypto/ed25519"
	"crypto/rand"
	"encoding/pem"
	"fmt"
	"strings"

	"golang.org/x/crypto/ssh"
)

type KeyMaterial struct {
	Private     []byte
	Public      string
	Fingerprint string
}

func GenerateKey(comment string) (KeyMaterial, error) {
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		return KeyMaterial{}, err
	}
	pk, err := ssh.NewPublicKey(pub)
	if err != nil {
		return KeyMaterial{}, err
	}
	private, err := ssh.MarshalPrivateKey(priv, comment)
	if err != nil {
		return KeyMaterial{}, err
	}
	public := strings.TrimSpace(string(ssh.MarshalAuthorizedKey(pk))) + " " + comment
	return KeyMaterial{Private: pem.EncodeToMemory(private), Public: public, Fingerprint: ssh.FingerprintSHA256(pk)}, nil
}

func ImportKey(private []byte, comment string) (KeyMaterial, error) {
	if len(private) == 0 || len(private) > 64*1024 {
		return KeyMaterial{}, fmt.Errorf("private key is empty or too large")
	}
	key, err := ssh.ParseRawPrivateKey(private)
	if err != nil {
		return KeyMaterial{}, fmt.Errorf("parse private key: %w", err)
	}
	if signer, err := ssh.NewSignerFromKey(key); err != nil {
		return KeyMaterial{}, fmt.Errorf("unsupported private key: %w", err)
	} else {
		public := strings.TrimSpace(string(ssh.MarshalAuthorizedKey(signer.PublicKey()))) + " " + comment
		return KeyMaterial{Private: append([]byte(nil), private...), Public: public, Fingerprint: ssh.FingerprintSHA256(signer.PublicKey())}, nil
	}
}
