---
title: Backend API Boundary
description: When PocketCoder uses PocketBase collections, record hooks, or explicit PocketCoder operations.
head: []
---

# Backend API Boundary

**Status:** Endpoint reduction implemented; OpenAPI contract generation is the
next phase
**Date:** 2026-08-13
**Revalidated against:** `172ccbef4` (release image delivery) plus the API cleanup branch
**Scope:** PocketBase collection APIs, PocketBase hooks, and `/api/pocketcoder/*`

There are no deployed users or user data to migrate. This cleanup does not
preserve obsolete routes, collections, field shapes, or Dart compatibility
wrappers. Schema changes are made directly in the canonical PocketBase schema
snapshot, with no additive migration files and no dual-read/dual-write period.

## Context

Every PocketCoder deployment belongs to one VPS owner, but a deployment may
contain several PocketBase users for family or friends. PocketBase is the
deployment's durable control plane. The Flutter app uses the official PocketBase
Dart SDK, extended by `pocketbase_drift`, for authentication, collection CRUD,
realtime subscriptions, and offline caching.

Before this cleanup, PocketCoder registered 37 routes below
`/api/pocketcoder/*`.
Some are true operations or streams. Others duplicate CRUD already provided by
PocketBase collections. Maintaining both paths produces two contracts, two sets
of Dart models, inconsistent authorization, and avoidable endpoint drift.

This document defines the boundary for the collection conversion and the
generated API contract that follows it.

## Pre-cleanup surface snapshot

The post-Git-SSH, post-harness-normalization route surface is:

| Area | Routes | Direction |
|:---|---:|:---|
| Agent session and stream | 7 | Keep as operations/stream |
| Harness authentication | 6 | Keep as operations |
| Schedules | 8 | Replace 7 CRUD wrappers; keep `run-now` |
| Skills | 4 | Replace with collection CRUD |
| Workspace files | 2 | Keep as non-collection reads |
| Ollama | 2 | Keep discovery plus pull stream |
| MCP request and OAuth intake | 2 | Keep as operations |
| Release compatibility/status | 2 | Keep as deployment reads; rename cleanly |
| Logs and observability | 2 | Keep as stream/proxy |
| Obsolete inbound SSH-key projection | 1 | Remove |
| Push dispatch | 1 | Keep as operation |
| **Total** | **37** | |

The Flutter `ApiEndpoints` class was not an accurate inventory. It contained
routes the backend did not register (`permission`, `health`), omitted several
routes the backend did register, and was bypassed by raw path strings in some
infrastructure clients. That made a checked route manifest/parity test an early
cleanup requirement, not merely final polish.

## Implemented outcome

The cleanup leaves 25 custom routes and checks them against one repository route
manifest from both Go and Flutter tests. The remaining surface consists of:

| Transport shape | Routes |
|:---|---:|
| JSON operations | 20 |
| SSE or NDJSON streams | 3 |
| Binary workspace file read | 1 |
| Observability proxy | 1 |
| **Total** | **25** |

Skills and schedules now use generated PocketBase records and collection
DAOs/repositories. Only schedule `run-now` remains an operation. Harness
accounts and per-profile selections use owner-scoped collection rules, request
hooks, cross-collection validation, and a Flutter repository. The obsolete
inbound `ssh_keys` projection and terminal client were removed. Release routes
and response fields now follow the release metadata vocabulary.

Skill materialization now respects project scope, deduplicates sibling harness
writes to their shared user workspace, and records a manifest of PocketCoder-
owned files. Removing stale managed files and exposing retry/error state remain
reconciler follow-ups; they are not reasons to restore CRUD wrapper routes.

## Decision

Use the following hierarchy:

1. **PocketBase collections for durable state.** If a request means create,
   read, update, delete, filter, or watch a durable entity, use the standard
   PocketBase collection API.
2. **PocketBase hooks for invariants and reconciliation.** Validate records and
   react to committed changes with hooks rather than wrapping collection CRUD in
   another HTTP API.
3. **Explicit PocketCoder operations for behavior.** Keep a
   `/api/pocketcoder/*` operation when the request starts work, coordinates
   multiple records, controls a process or container, accesses a non-PocketBase
   resource, proxies another service, or requires a synchronous behavioral
   result.
4. **Explicit PocketCoder streams for continuous output.** SSE and NDJSON remain
   dedicated routes with specialized Flutter stream readers.

In compact form:

```text
durable state       -> PocketBase collection API
committed change    -> PocketBase hook + reconciler
imperative behavior -> PocketCoder operation
continuous output   -> PocketCoder streaming operation
```

The mere fact that an operation reads or writes a collection does not make it
CRUD. The question is whether the collection record is the durable source of
truth or merely an implementation detail of a command.

## PocketBase collection path

Collection-backed features use the existing generation pipeline:

```text
server/pocketbase/pb_migrations/schema.json
  -> exported Flutter pb_schema.json
  -> scripts/generate_models.py
  -> generated Dart models and Collections constants
  -> BaseDao<T>
  -> domain repository
  -> Cubit
  -> Flutter UI
```

Flutter should use the injected PocketBase client:

```dart
pb.collection(Collections.skills).getFullList();
pb.collection(Collections.skills).create(body: request);
pb.collection(Collections.skills).subscribe('*', callback);
```

The PocketBase SDK owns URL construction, the current auth token, collection
rules, record errors, realtime, and `pocketbase_drift` caching. A feature using
this path must not repeat collection routes under `/api/pocketcoder/*`.

## Hook responsibilities

Hooks have distinct jobs:

- Collection field constraints handle static requirements such as required
  values, lengths, select values, and safe name patterns.
- request hooks may set or reject request-specific ownership and server-managed
  fields;
- model validation hooks enforce invariants for every write path, including
  writes initiated by server code;
- after-create/update/delete-success hooks reconcile external state only after
  the database commit succeeds;
- startup reconciliation repairs external state after crashes or downtime.

External side effects are not part of the database transaction. A committed
record must remain the desired state even if Docker, the filesystem, or another
service is temporarily unavailable. Reconcilers therefore need deterministic,
idempotent retries and observable error state where failure matters to the user.

Do not put slow Docker or filesystem work in a pre-commit validation hook. Do not
silently treat a best-effort copy as permanent success.

## Immediate endpoint reductions

### Skills

The `skills` collection is already canonical. The existing record hooks already
attempt to materialize skills into managed files in the user's shared workspace.
The following redundant wrapper routes should be removed:

- `POST /api/pocketcoder/skills/list`
- `POST /api/pocketcoder/skills/create`
- `POST /api/pocketcoder/skills/update`
- `POST /api/pocketcoder/skills/delete`

Flutter should use generated `Skill` collection records through a `SkillDao` and
repository. PocketBase rules continue to expose the user's own skills plus
system skills and prevent ordinary users from modifying system records.

The wrapper routes and Flutter transport models are removed in the same change.
The materializer must become a real reconciler:

- write every desired managed skill file;
- remove stale managed files after delete or rename;
- respect project scope instead of materializing every skill globally;
- avoid repeating identical work for several harnesses sharing one workspace;
- retain a manifest of files PocketCoder owns so it never deletes user files;
- retry on harness/workspace start and expose reconciliation failures.

The collection is desired state; files under `.agents/skills` and
`.claude/skills` are derived state.

### Schedules

The `schedule_owners` collection already contains the owner, display name, cron,
prompt, paused state, and last-run state. These routes should become ordinary
collection operations:

- `POST /api/pocketcoder/schedules/list`
- `POST /api/pocketcoder/schedules/create`
- `POST /api/pocketcoder/schedules/rename`
- `POST /api/pocketcoder/schedules/update-cron`
- `POST /api/pocketcoder/schedules/pause`
- `POST /api/pocketcoder/schedules/unpause`
- `POST /api/pocketcoder/schedules/delete`

The existing create/update/delete hooks should own registration with
PocketBase's cron scheduler. The collection needs owner-scoped create, update,
and delete rules; protection for `user` and server-owned `last_run`; and cron
validation before it is exposed for direct writes.

`POST /api/pocketcoder/schedules/run-now` remains an operation because it starts
work immediately and returns acceptance rather than representing a durable
schedule edit.

The current `currentlyRunning` API field does not justify a wrapper: it is
declared but never populated. If running state is needed, it should be modeled as
real observable state rather than synthesized as a permanently false field.

### Git SSH credentials and repository access

The Git SSH work now follows the intended boundary without adding a custom HTTP
route:

- `git_ssh_credentials` stores user-owned credential metadata and materializer
  status;
- `git_repository_access` stores user-owned repository access intent;
- owner-scoped PocketBase rules provide standard CRUD;
- request/model hooks set ownership, protect server-managed fields, canonicalize
  repositories, and validate credential relationships;
- generated Dart models and `BaseDao` implementations provide Flutter access;
- private key material belongs in the per-user Git SSH volume, not in a
  PocketBase field.

The landed queue/materializer pieces are still infrastructure, not a reason to
add wrapper CRUD routes. Completing asynchronous reconciliation and surfacing
its status should continue through those collections.

This is separate from the obsolete `ssh_keys` collection and
`GET /api/pocketcoder/ssh_keys`, which aggregate inbound public keys as an
`authorized_keys` text file. No current production consumer is visible in the
repository. With no deployed users or compatibility requirement, remove the
route, its Flutter auth method/constants, its tests, and the `ssh_keys`
collection rather than carrying an unused second SSH concept alongside outbound
Git credentials.

## Operations that remain justified

### Agent sessions

Keep prompt, cancel, mode/config changes, permission responses, elicitation
responses, and the agent SSE stream. These coordinate a live ACP session and are
not chat-record CRUD.

### Harness authentication

Keep start, poll, submit, cancel, disconnect, and status operations. They control
short-lived helper containers and authentication challenges. Persistent account
metadata remains in PocketBase collections, but the login process is behavior.

### Harness accounts

Harness login identity, access, and user preference are separate concepts:

- `harness_accounts` owns the named login identity and its auth volume. A
  personal account is owner-only; a deployment-visible account is available to
  every authenticated profile on that self-hosted deployment.
- `harness_account_selections` stores one selected account per user and harness,
  enforced by a unique `(user, harness)` index.
- PocketBase users continue to own their workspace volumes independently of
  the selected harness account.

The selection hook already verifies that the account belongs to the recorded
harness and is accessible to the recorded user. However, both collections still
have closed (`null`) API rules, and Flutter has collection constants/models but
no complete DAO/repository workflow. Before exposing direct access:

- add rules that list personal accounts owned by the caller plus
  deployment-visible accounts;
- allow owners to create/rename/manage their accounts without permitting clients
  to forge status, provider-key bindings, or ownership;
- scope selections to the caller and protect the `user` field in request hooks;
- preserve the `(user, harness)` uniqueness and cross-collection selection
  validation;
- add generated-model DAOs/repositories for listing accounts and upserting the
  caller's selection.

No new list/create/select wrapper endpoint is needed. Authentication start,
poll, submit, cancel, disconnect, and status remain explicit operations because
they control live helper containers and challenges.

### Workspace files

Keep workspace file listing and download routes. They expose controlled access to
the mounted workspace, not PocketBase file fields.

### Ollama

Keep model discovery and model pull. They proxy a private service, and pull is an
NDJSON progress stream.

### MCP

Keep OAuth token intake because it handles one-shot secret input and updates
managed service configuration. Keep MCP request behavior unless the product is
deliberately redesigned around a durable `mcp_requests` job collection with
status, idempotency, retries, and retention. Direct client writes to
`mcp_servers` are not equivalent because the current operation resolves an image
digest and deduplicates pending/active requests.

### Release, observability, logs, and push

Keep release compatibility/status, the observability proxy, Docker log SSE, and
push dispatch. These read deployment state, proxy private services, or trigger
delivery rather than performing collection CRUD.

Release route and field names should match the authoritative update JSON rather
than introducing a second vocabulary:

- rename `GET /api/pocketcoder/compatibility` to
  `GET /api/pocketcoder/release/compatibility`;
- rename `GET /api/pocketcoder/capabilities` to
  `GET /api/pocketcoder/release/status`;
- do not retain aliases for the old paths;
- shape the public compatibility response around `schemaVersion`,
  `dataVersion`, and the release manifest's nested
  `compatibility.app.contractVersion`, `compatibility.server.apiVersion`, and
  `compatibility.deployment.contractVersion` names;
- shape the authenticated status response around the local update-state names
  `current` (`current.json`) and `metadataStatus` (`metadata-status.json`).

The compatibility resource performs current client/server contract negotiation;
it does not preserve retired endpoint or schema shapes.

## Do not create command collections casually

It is possible to replace an operation with a record such as:

```text
commands/{id}
  kind: run_schedule
  payload: {...}
  status: pending
```

That is appropriate only when PocketCoder intentionally needs a durable job
queue. It otherwise adds command lifecycle, idempotency, retry, offline replay,
retention, cancellation, and delayed-error semantics. A normal operation is
simpler and more honest for immediate behavior.

In particular, `pocketbase_drift` may replay offline writes. That is desirable
for durable state but potentially dangerous for commands such as “run now,”
“send push,” or “pull model.” Imperative operations should be network-only and
must not be represented as ordinary offline-capable record creation by accident.

## OpenAPI decision

OpenAPI is not required for the standard PocketBase collection API. PocketBase's
schema and Dart SDK already define that contract.

The post-reduction inventory contains 20 JSON operations in addition to three
streams, a binary read, and a proxy. A path manifest prevents route drift, but it
cannot detect request/response field drift. Adopt OpenAPI for **all remaining
`/api/pocketcoder/*` operations**, including normal JSON operations and stream
metadata. Do not introduce it only for streaming routes: generated clients
provide the most value for typed JSON request/response operations, while SSE and
NDJSON still need specialized incremental Dart readers.

The intended split would be:

```text
PocketBase schema
  -> collection models, CRUD, rules, realtime, offline state

PocketCoder OpenAPI
  -> operation paths, methods, typed request/response models, errors,
     authentication declarations, and stream media/event contracts
```

OpenAPI would describe streams, but generated code would delegate their actual
transport to handwritten `Stream<T>` implementations using the shared
PocketBase base URL and auth token.

The route manifest remains the checked path inventory until the OpenAPI source
replaces it. During that transition, remaining PocketCoder operations still
have a single typed Flutter client/repository boundary. Raw
`/api/pocketcoder/*` path strings must not appear in Cubits, adapters, widgets,
or screens.

## Expected result

Skills and schedules remove eleven redundant routes. Removing the obsolete
inbound `ssh_keys` projection removes one more, reducing the custom surface from
37 routes to 25. Harness-account and Git-SSH CRUD add no custom routes.

The goal is not the smallest possible route count. The goal is one canonical
interface per behavior:

- a durable entity has one PocketBase collection contract;
- an external representation is derived by a reconciler;
- an imperative behavior has one explicit operation contract;
- a continuous result has one explicit stream contract.

## Implementation record and next steps

1. Completed: establish a checked 37-route inventory, then reduce it to 25 and
   enforce backend/Flutter parity through `api/pocketcoder-routes.json`.
2. Completed: convert skills to generated collection models and
   DAO/repository access; remove the four CRUD wrappers and custom transport
   models.
3. Completed: convert schedules to collection CRUD with strengthened
   rules/hooks; retain only `run-now` as an operation.
4. Completed: expose `harness_accounts` and `harness_account_selections`
   through scoped collection rules, hooks, DAOs, and a Flutter repository.
5. Completed: remove the obsolete inbound `ssh_keys` collection, route,
   terminal client, and tests without an alias or migration.
6. Completed: rename release endpoints and response fields to match the release
   JSON vocabulary without compatibility paths.
7. Decided: add OpenAPI for all 25 remaining operations, with handwritten
   incremental stream transports conforming to the documented contracts.
8. Follow-up: finish stale managed-skill removal and observable reconciliation
   retry/error state using the ownership manifest already written to each user
   workspace.
