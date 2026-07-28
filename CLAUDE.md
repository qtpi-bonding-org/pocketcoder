# PocketCoder

## Deployment Model — read this before designing any cross-service feature

**Each docker-compose deployment belongs to exactly one user.** PocketBase,
goose, and mcp-gateway in a given deployment are that user's own — spun up
onto their own VPS by **Aeroform** (`flutter_aeroform`, a sibling package
this org owns), which auto-provisions the box and deploys the stack with
**no SSH step at all**. The Flutter app that talks to that deployment is
also that one user's own client. We (the PocketCoder team) never operate
or reach into any individual user's PocketBase/goose/gateway.

**The only infrastructure we run centrally is `workers/` (Cloudflare
Workers)** — `push-relay`, `image-relay`, and any sibling worker. That's
"our backend." Anything that needs a stable, publicly-reachable endpoint
shared across every self-hosted deployment (OAuth app registrations,
third-party API brokering, anything requiring a secret no individual
user's box should hold) belongs in a Worker, not in PocketBase or the
gateway — a per-deployment service can never be the single registered
callback/endpoint an external provider expects, since there are as many
deployments as there are users.

When a design needs "a human to register something with a third party"
(an OAuth app's redirect URI, an API client registration, etc.), that
registration has to be done once by us, centrally — end users never see
that step in a zero-touch Aeroform-provisioned flow. See
`docs/superpowers/specs/2026-07-27-mcp-oauth-flow-design.md` for a worked
example of this pattern (GitHub OAuth: Worker holds the shared
client_id/client_secret, exchanges the code, hands the finished token to
the user's own deployment) and `flutter_aeroform`'s existing
`LinodeOAuthService`/`LinodeAPIClient` for the precedent it followed.

## PocketBase Schema Conventions

**PocketBase always owns its own primary key.** A collection's `id` is always
PocketBase's own auto-generated id — never repurpose an external system's
identifier (a Goose session id, schedule id, etc.) as a record's PK. Store
the external id as a plain (usually unique-indexed) field instead, e.g.
`goose_sessions.goose_session_id`. The rule of thumb: **if a field holds an
auto-generated PocketBase id, PocketBase owns that entity's identity; if it
holds an external id as a plain field, the external system owns it and
PocketBase is only tracking/attributing it.** This keeps rename/display-name
changes (PocketBase-side) decoupled from the external system's immutable
identifier, and matches every existing case in this schema (`chats`,
`goose_sessions`, etc.).

## Model Generation Pipeline

PocketBase schema lives in exactly two migration files:
`server/pocketbase/pb_migrations/1756000000_schema.go` (imports
`schema.json`, a full collection-schema snapshot) and
`1756000100_seed.go` (default users/tool-permissions). Make schema
changes by editing `schema.json` directly (or making the change via the
PocketBase Admin UI locally, then re-running `tooling/scripts/export_schema.sh`
and copying its output over `schema.json`) rather than appending a new
timestamped migration file — until one of these two files grows large
enough that splitting it out makes sense again.

After changing PB collections/schema, run this sequence:

1. `docker compose build pocketbase goose` — rebuild containers
2. `docker compose up -d pocketbase goose` — start with new code
3. `tooling/scripts/export_schema.sh` — exports PB schema to `client/packages/pocketcoder_flutter/assets/pb_schema.json`
4. `cd client/packages/pocketcoder_flutter && python3 scripts/generate_models.py` — generates Dart models in `lib/domain/models/`
5. `dart run build_runner build --delete-conflicting-outputs` — generates freezed + json_serializable code (run from `client/packages/pocketcoder_flutter`)
