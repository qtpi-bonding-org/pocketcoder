-- image_relay_revocations: the sole write surface for image-relay's credential
-- revocation. A row means the named credential jti is no longer honored,
-- regardless of RevenueCat or the credential's own signature. Written only by
-- an authenticated, root-signed POST /v1/revoke. Rows are permanent.
CREATE TABLE IF NOT EXISTS image_relay_revocations (
  jti TEXT PRIMARY KEY,
  revoked_at TEXT NOT NULL DEFAULT (datetime('now'))
);
