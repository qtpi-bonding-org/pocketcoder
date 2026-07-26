# PocketCoder

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
PocketBase Admin UI locally, then re-running `scripts/export_schema.sh`
and copying its output over `schema.json`) rather than appending a new
timestamped migration file — until one of these two files grows large
enough that splitting it out makes sense again.

After changing PB collections/schema, run this sequence:

1. `docker compose build pocketbase goose` — rebuild containers
2. `docker compose up -d pocketbase goose` — start with new code
3. `scripts/export_schema.sh` — exports PB schema to `client/packages/pocketcoder_flutter/assets/pb_schema.json`
4. `cd client/packages/pocketcoder_flutter && python3 scripts/generate_models.py` — generates Dart models in `lib/domain/models/`
5. `dart run build_runner build --delete-conflicting-outputs` — generates freezed + json_serializable code (run from `client/packages/pocketcoder_flutter`)
