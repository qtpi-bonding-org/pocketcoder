-- image_relay_revocations: the sole write surface for image-relay's
-- credential revocation. A row here means the named credential jti is no
-- longer honored, regardless of what RevenueCat or the credential's own
-- signature say. Populated only by an authenticated (root-signed) POST
-- /v1/revoke call -- see docs/superpowers/specs/2026-08-24-image-relay-
-- auth-protocol.md for the full authorization chain.
create table if not exists image_relay_revocations (
  jti text primary key,
  revoked_at timestamptz not null default now()
);

grant select, insert on public.image_relay_revocations to service_role;
