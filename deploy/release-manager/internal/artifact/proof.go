package artifact

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"math/big"
	"net/url"
	"strings"
	"time"
)

// ProofSigner signs the DPoP-style per-request proof (Artifact 2) and
// carries the credential (Artifact 1) to attach alongside it. The exact claim shapes must match byte-for-byte with the
// Worker's verifier -- go-jose/similar libraries are deliberately not
// used here; this uses only the standard library.
type ProofSigner struct {
	PrivateKey *ecdsa.PrivateKey
	Credential string // compact JWS, delivered via runtime.env, unmodified
}

// NewProofSignerFromPKCS8Base64 parses the box's PKCS8-DER private key
// (base64-standard-encoded, per the protocol spec's private-key
// delivery profile) as delivered in runtime.env's BOX_PRIVATE_KEY_PKCS8.
func NewProofSignerFromPKCS8Base64(pkcs8Base64, credential string) (*ProofSigner, error) {
	der, err := base64.StdEncoding.DecodeString(pkcs8Base64)
	if err != nil {
		return nil, fmt.Errorf("decode PKCS8 base64: %w", err)
	}
	key, err := x509.ParsePKCS8PrivateKey(der)
	if err != nil {
		return nil, fmt.Errorf("parse PKCS8: %w", err)
	}
	ecKey, ok := key.(*ecdsa.PrivateKey)
	if !ok {
		return nil, fmt.Errorf("PKCS8 key is not an ECDSA key")
	}
	if ecKey.Curve != elliptic.P256() {
		return nil, fmt.Errorf("PKCS8 key is not P-256")
	}
	return &ProofSigner{PrivateKey: ecKey, Credential: credential}, nil
}

func b64u(data []byte) string {
	return base64.RawURLEncoding.EncodeToString(data)
}

func b64uJSON(v any) (string, error) {
	data, err := json.Marshal(v)
	if err != nil {
		return "", err
	}
	return b64u(data), nil
}

// coordToBytes returns a big.Int's value as a fixed-width, big-endian,
// zero-padded byte slice -- required for JWK x/y (32 bytes for P-256),
// never a variable-width encoding.
func coordToBytes(n *big.Int, width int) []byte {
	buf := make([]byte, width)
	b := n.Bytes()
	copy(buf[width-len(b):], b)
	return buf
}

func publicJwk(pub *ecdsa.PublicKey) map[string]string {
	return map[string]string{
		"kty": "EC",
		"crv": "P-256",
		"x":   b64u(coordToBytes(pub.X, 32)),
		"y":   b64u(coordToBytes(pub.Y, 32)),
	}
}

// normalizeHtu implements RFC 9449 section 4.3: lowercase scheme/host,
// default port omitted, no query, no fragment.
func normalizeHtu(rawURL string) (string, error) {
	u, err := url.Parse(rawURL)
	if err != nil {
		return "", err
	}
	scheme := strings.ToLower(u.Scheme)
	host := strings.ToLower(u.Hostname())
	port := u.Port()
	if (scheme == "https" && port == "443") || (scheme == "http" && port == "80") {
		port = ""
	}
	hostport := host
	if port != "" {
		hostport = host + ":" + port
	}
	return scheme + "://" + hostport + u.Path, nil
}

// SignProof signs a fresh DPoP-style proof for one request. Must be
// called once per outbound request -- a proof is not reusable across
// two different requests even to the same URL (fresh iat/jti each time).
func (s *ProofSigner) SignProof(method, targetURL string) (string, error) {
	htu, err := normalizeHtu(targetURL)
	if err != nil {
		return "", fmt.Errorf("normalize htu: %w", err)
	}

	header := map[string]any{
		"alg": "ES256",
		"typ": "dpop+jwt",
		"jwk": publicJwk(&s.PrivateKey.PublicKey),
	}
	nonceBytes := make([]byte, 16)
	if _, err := rand.Read(nonceBytes); err != nil {
		return "", fmt.Errorf("generate jti: %w", err)
	}
	claims := map[string]any{
		"htm": strings.ToUpper(method),
		"htu": htu,
		"iat": time.Now().Unix(),
		"jti": b64u(nonceBytes),
	}

	headerB64, err := b64uJSON(header)
	if err != nil {
		return "", err
	}
	claimsB64, err := b64uJSON(claims)
	if err != nil {
		return "", err
	}
	signingInput := headerB64 + "." + claimsB64

	digest := sha256.Sum256([]byte(signingInput))
	r, sVal, err := ecdsaSignRawRS(s.PrivateKey, digest[:])
	if err != nil {
		return "", fmt.Errorf("sign: %w", err)
	}
	sigB64 := b64u(append(coordToBytes(r, 32), coordToBytes(sVal, 32)...))

	return signingInput + "." + sigB64, nil
}

// ecdsaSignRawRS wraps ecdsa.Sign and returns r/s directly -- Go's
// stdlib ECDSA signing naturally produces r/s as big.Ints (it's
// ecdsa.SignASN1 that DER-encodes them), so no DER round-trip or
// conversion is needed on the Go side, unlike the OpenSSL/shell leg.
func ecdsaSignRawRS(key *ecdsa.PrivateKey, digest []byte) (r, s *big.Int, err error) {
	return ecdsa.Sign(rand.Reader, key, digest)
}
