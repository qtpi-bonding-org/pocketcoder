package crypto

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/sha256"
	"encoding/base64"
	"math/big"

	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
)

type VerificationRequest struct {
	Challenge string `json:"challenge"`
	Signature string `json:"signature"`
	PublicKey map[string]interface{} `json:"publicKey"` // JWK format
}

// verifySignature checks if the signature matches the challenge using the public key
func verifySignature(req VerificationRequest) error {
	// 1. Parse JWK to ECDSA Public Key
	// Note: We are using a simplified parsing here. In prod, use a JWK library.
    // For P-256 (ES256), X and Y are base64url encoded.
	jwk := req.PublicKey
    if jwk["kty"] != "EC" || jwk["crv"] != "P-256" {
        return apis.NewBadRequestError("Invalid Key Type. Expected EC P-256", nil)
    }
    
    xStr, _ := jwk["x"].(string)
    yStr, _ := jwk["y"].(string)

    // Decode Base64URL
    xBytes, err := base64.RawURLEncoding.DecodeString(xStr)
    if err != nil {
         return apis.NewBadRequestError("Invalid X coord", err)
    }
    yBytes, err := base64.RawURLEncoding.DecodeString(yStr)
     if err != nil {
         return apis.NewBadRequestError("Invalid Y coord", err)
    }

	pubKey := ecdsa.PublicKey{
		Curve: elliptic.P256(),
		X:     new(big.Int).SetBytes(xBytes),
		Y:     new(big.Int).SetBytes(yBytes),
	}

	// 2. Decode Signature
    // The client sends standard Base64, but sometimes URL encoding depending on lib.
    // We try standard first.
	sigBytes, err := base64.StdEncoding.DecodeString(req.Signature)
	if err != nil {
		return apis.NewBadRequestError("Invalid Signature Encoding", err)
	}

	// 3. Verify
    // ecdsa.VerifyASN1 is for ASN.1 DER encoded signatures (standard for crypto libs)
    // webcrypto usually outputs raw R+S concatenation.
    // We need to handle this. For P-256, signature is 64 bytes (32 R + 32 S).
    
    if len(sigBytes) != 64 {
        // Fallback: If it's ASN1, it will be variable length (usually 70-72).
        // If it's 64, it's raw.
        // Go's ecdsa.Verify expects separate big.Ints.
        return apis.NewBadRequestError("Invalid Signature Length. Expected 64 bytes (Raw R+S)", nil) 
    }

    r := new(big.Int).SetBytes(sigBytes[:32])
    s := new(big.Int).SetBytes(sigBytes[32:])

	hash := sha256.Sum256([]byte(req.Challenge))

	valid := ecdsa.Verify(&pubKey, hash[:], r, s)
	if !valid {
		return apis.NewBadRequestError("Signature Invalid", nil)
	}

	return nil
}

// BindSecurityRoutes adds the verify endpoint
func BindSecurityRoutes(app core.App, e *core.ServeEvent) {
    e.Router.POST("/api/pocketcoder/verify", func(c *core.RequestEvent) error {
        var req VerificationRequest
        if err := c.BindBody(&req); err != nil {
            return apis.NewBadRequestError("Invalid Body", err)
        }

        if err := verifySignature(req); err != nil {
            return err
        }

        return c.JSON(200, map[string]string{
            "status": "verified",
            "message": "Signature Accepted",
        })
    })
}
