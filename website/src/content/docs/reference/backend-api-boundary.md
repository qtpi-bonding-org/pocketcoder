---
title: Backend API Boundary
description: When PocketCoder uses PocketBase collections, record hooks, or explicit PocketCoder operations.
head: []
---

# Backend API Boundary

**Status:** Proposed architecture
**Date:** 2026-08-13
**Scope:** PocketBase collection APIs, PocketBase hooks, and `/api/pocketcoder/*`

## Context

Every PocketCoder deployment belongs to one VPS owner, but a deployment may
contain several PocketBase users for family or friends. PocketBase is the
deployment's durable control plane. The Flutter app uses the official PocketBase
Dart SDK, extended by `pocketbase_drift`, for authentication, collection CRUD,
realtime subscriptions, and offline caching.

PocketCoder also registers approximately 37 routes below `/api/pocketcoder/*`.
Some are true operations or streams. Others duplicate CRUD already provided by
PocketBase collections. Maintaining both paths produces two contracts, two sets
of Dart models, inconsistent authorization, and avoidable endpoint drift.

This document defines the boundary before a generated API contract is added.

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
The following compatibility routes should be removed:

- `POST /api/pocketcoder/skills/list`
- `POST /api/pocketcoder/skills/create`
- `POST /api/pocketcoder/skills/update`
- `POST /api/pocketcoder/skills/delete`

Flutter should use generated `Skill` collection records through a `SkillDao` and
repository. PocketBase rules continue to expose the user's own skills plus
system skills and prevent ordinary users from modifying system records.

Before removing the wrapper, the materializer must become a real reconciler:

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

### SSH keys

SSH-key redesign and reconciliation are intentionally out of scope for this
document because they are being implemented independently. That work should
apply the same boundary: collection records for durable credential/configuration
state, hooks or reconcilers for derived files, and explicit operations only for
imperative key lifecycle behavior that cannot be represented safely as CRUD.

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

The selection hook must verify that the account belongs to the recorded harness
and is accessible to the recorded user. Listing, renaming, and selection should
use protected collection access once the collection rules and Flutter
repositories are added. Authentication start, poll, submit, cancel, disconnect,
and status remain explicit operations because they control live helper
containers and challenges.

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

Keep release compatibility/capabilities, the observability proxy, Docker log
SSE, and push dispatch. These read deployment state, proxy private services, or
trigger delivery rather than performing collection CRUD.

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

First remove redundant collection wrappers. Then inventory the remaining
PocketCoder behavior API. If OpenAPI is adopted, it should cover **all remaining
`/api/pocketcoder/*` operations**, including normal JSON operations and stream
metadata. It should not be introduced only for streaming routes: generated
clients provide the most value for typed JSON request/response operations, while
SSE and NDJSON still need specialized incremental Dart readers.

The intended split would be:

```text
PocketBase schema
  -> collection models, CRUD, rules, realtime, offline state

PocketCoder OpenAPI (if retained after the endpoint reduction)
  -> operation paths, methods, typed request/response models, errors,
     authentication declarations, and stream media/event contracts
```

OpenAPI would describe streams, but generated code would delegate their actual
transport to handwritten `Stream<T>` implementations using the shared
PocketBase base URL and auth token.

Until that decision is made, remaining PocketCoder operations must still have a
single typed Flutter client/repository boundary. Raw `/api/pocketcoder/*` path
strings must not appear in Cubits, adapters, widgets, or screens.

## Expected result

The immediate skills and schedules conversion removes eleven redundant routes,
reducing the current custom surface from approximately 37 routes to 26 before
new harness-account operations. SSH work may reduce or reshape it further.

The goal is not the smallest possible route count. The goal is one canonical
interface per behavior:

- a durable entity has one PocketBase collection contract;
- an external representation is derived by a reconciler;
- an imperative behavior has one explicit operation contract;
- a continuous result has one explicit stream contract.

## Implementation order

1. Complete the independently owned SSH-key work without overlapping changes.
2. Convert skills to generated collection models, DAO/repository access, and a
   deterministic filesystem reconciler; remove the four compatibility routes.
3. Convert schedule state to collection CRUD and strengthen its rules/hooks;
   retain only `run-now` as an operation.
4. Classify harness-account listing as a protected collection view or operation,
   then implement transactional create/select behavior.
5. Re-inventory the remaining `/api/pocketcoder/*` surface.
6. Decide whether the reduced operation surface warrants OpenAPI generation.
7. Regardless of OpenAPI, enforce route parity and ban raw PocketCoder paths
   outside the infrastructure transport layer.
