---
title: PocketCoder OpenAPI Implementation Plan
description: Plan for making the remaining PocketCoder operation API spec-first while leaving PocketBase collections on the PocketBase SDK.
head: []
---

# PocketCoder OpenAPI Implementation Plan

**Status:** Contract, generated clients/types, route parity checks, and the
PocketBase adapter seam are implemented. Strict handler migration remains a
follow-on hardening pass.
**Date:** 2026-08-13
**Baseline:** `1f6601aea` (25-route custom API after collection cleanup)

## Outcome

Create one checked-in OpenAPI source of truth for every remaining
`/api/pocketcoder/*` route. Generate the normal JSON server contract and Dart
client from it, while preserving handwritten incremental transports for SSE,
NDJSON, binary file reads, and the observability proxy.

PocketBase collection CRUD is deliberately outside this specification. Flutter
continues to use the PocketBase SDK, generated collection models, realtime, and
`pocketbase_drift` for collection-backed state.

```text
server/pocketbase/pb_migrations/schema.json
  -> PocketBase collection API and generated collection models

api/openapi/pocketcoder.yaml
  -> Go request/response types and strict JSON operation interface
  -> generated Dart operation client and DTO package
  -> checked API documentation
  -> route and generated-output drift checks
```

## Fixed decisions

### Specification format

- Start with OpenAPI **3.0.3**. It is the stable intersection of the selected Go
  and Dart generators. Do not adopt 3.1/3.2 features until both pinned
  generators support the exact constructs PocketCoder needs.
- Keep one readable source file at `api/openapi/pocketcoder.yaml`. Twenty-five
  routes do not yet justify a multi-file specification.
- Give every operation a stable `operationId`, explicit security, every expected
  response status, and a named request/response schema. Avoid anonymous inline
  object schemas.
- Use lower camel case for PocketCoder JSON fields. Normalize remaining
  snake-case bodies such as MCP and push during this no-user window, without
  compatibility aliases.
- Use the PocketBase error envelope everywhere:
  `{"status": int, "message": string, "data": object}`. Replace the custom
  `{"error": string}` responses rather than documenting two error systems.
- Describe the raw PocketBase token as an `apiKey` security scheme in the
  `Authorization` header. It is not an OAuth bearer-token contract. The public
  release-compatibility operation explicitly declares `security: []`.
- Record role requirements that OpenAPI cannot enforce with
  `x-pocketcoder-roles`, while retaining runtime authorization checks.

### Generators

- Generate Go with `oapi-codegen` **v2.7.2**. The repository currently uses Go
  1.24.4; `oapi-codegen` v2.8.0 requires Go 1.25. Do not quietly couple this work
  to a toolchain upgrade.
- Generate Dart with the pinned OpenAPI Generator **7.24.0** `dart-dio`
  generator. Use its stable `built_value` serialization path and
  `enumUnknownDefaultCase=true`; do not select its beta `json_serializable`
  mode merely to resemble the collection model pipeline.
- Pin tools in repository configuration. Generation must not use `latest`, an
  online generation service, or an unpinned container tag.
- Commit generated code. CI regenerates into a clean working tree and fails on
  any diff.
- Use Redocly CLI only for linting, bundling, and documentation, with a pinned
  version. It is not a second contract source.

The tool choices follow the projects' documented capabilities:
[`oapi-codegen` strict servers](https://github.com/oapi-codegen/oapi-codegen),
the stable [OpenAPI Generator `dart-dio` client](https://openapi-generator.tech/docs/generators/dart-dio/),
and [Redocly linting](https://redocly.com/docs/cli/commands/lint).

### Generated boundaries

Create these implementation artifacts in the future implementation branch:

```text
api/openapi/pocketcoder.yaml                 # hand-authored source of truth
api/openapi/redocly.yaml                     # lint rules
api/openapi/oapi-codegen.yaml                # pinned Go generation options
api/openapi/dart-dio-config.yaml             # pinned Dart options
api/openapi/generator-versions.env            # exact tool versions/digests
tooling/scripts/generate_openapi.sh           # one deterministic entry point

server/pocketbase/internal/openapi/
  pocketcoder.gen.go                          # generated types/server interface
  adapter.go                                  # handwritten PocketBase bridge
  implementation.go                          # handwritten strict implementation

client/packages/pocketcoder_api/              # fully generated Dart workspace package
client/packages/pocketcoder_flutter/
  lib/infrastructure/core/pocketcoder_api_client.dart
                                               # handwritten base URL/auth adapter
```

The generated Dart code lives in its own workspace package. It must not be
mixed into `lib/domain/models`, which is the PocketBase collection pipeline, or
hand-edited inside the Flutter application package.

## Route treatment

The specification covers all 25 routes, but generation is used differently by
transport shape:

| Shape | Count | Server | Flutter |
|:---|---:|:---|:---|
| JSON or no-content operation | 20 | Generated strict interface and response unions | Generated `dart-dio` method and DTOs |
| SSE | 2 | Handwritten streaming response satisfying/documented by the contract | Existing incremental reader, using generated event DTOs where practical |
| NDJSON | 1 | Handwritten streaming response | Existing incremental reader; decode one documented item at a time |
| Binary file read | 1 | Handwritten response | Handwritten byte transport with a spec-checked request shape |
| Opaque observability proxy | 1 | Handwritten reverse proxy | Handwritten repository; no attempt to model arbitrary SQLPage bodies |

The two SSE routes are agent events and Docker logs. Ollama pull is NDJSON.
OpenAPI documents their media types (`text/event-stream` and
`application/x-ndjson`), item schemas, cancellation behavior, and errors before
headers are committed. It does not replace them with buffered generated calls.
The OpenAPI Initiative explicitly treats SSE as a sequential
`text/event-stream` media type; the handwritten reader is therefore an intended
transport adapter, not an escape from the contract.

The current `{path...}` syntax is a PocketBase-router extension, not an OpenAPI
path-template feature. Before freezing the spec:

- change file read/list to a normal `path` query parameter so nested paths are
  encoded predictably by generated clients;
- keep the observability subtree as an opaque proxy and annotate its router
  pattern with `x-pocketcoder-router-path`;
- do not add aliases for the old file URLs.

## PocketBase server integration

Do not replace PocketBase or register a second HTTP server.

1. Generate models plus the `std-http-server` and `strict-server` interfaces for
   the 20 normal operations. Use `include-tags` so streaming, binary, and proxy
   operations remain documented but outside the generated strict handler.
2. Add a small `adapter.go` that wraps the generated `http.Handler` with
   `apis.WrapStdHandler`. Before delegation it places the current PocketBase
   app, `RequestEvent`, and authenticated record in the request context.
3. Register exact PocketBase routes and retain PocketBase middleware. Public,
   authenticated, agent/admin, and admin-only access must remain visible at the
   PocketBase registration boundary; the generated handler does not become an
   authorization bypass.
4. Implement the generated strict interface. Each method receives generated
   request types and must return one of the generated status-specific response
   objects. Add `var _ openapi.StrictServerInterface = (*Server)(nil)` so a spec
   change fails compilation until the backend implements it.
5. Keep business logic outside generated files. Existing ACP, harness auth,
   scheduler, MCP, release, and Ollama services are called through thin
   operation implementations.
6. Add request validation middleware after proving that its errors can be
   rendered through the PocketBase error envelope. Strict server generation
   alone does not perform complete OpenAPI request validation.

ACP SDK objects are not the HTTP contract. Define their HTTP projection in
OpenAPI and add explicit conversions at the agent boundary. This prevents an ACP
dependency update from silently changing the mobile API.

## Flutter integration

1. Add generated `client/packages/pocketcoder_api` to the existing Dart
   workspace and make `pocketcoder_flutter` depend on it by path.
2. Build one injectable `PocketCoderApiClient` adapter around the generated Dio
   client. It owns the deployment base URL, the raw PocketBase Authorization
   token, timeouts, cancellation, and conversion from generated failures to
   domain exceptions.
3. Replace handwritten JSON parsing one feature at a time:
   release and schedules, harness authentication, MCP/push, agent actions, then
   Ollama discovery and file listing.
4. Keep repositories and domain interfaces. Generated transport DTOs must not
   leak into Cubits, widgets, or collection DAOs.
5. Keep `AgentStreamClient`, Ollama pull, log streaming, file bytes, and the
   observability proxy handwritten. Move their raw paths into a small
   spec-checked special-transport endpoint class and reuse generated schemas for
   decoded frames when that does not force buffering.
6. Delete `ApiEndpoints` only after all normal operations use the generated
   client and the special transports have a spec parity test.

The auth adapter must also remove the current inconsistency where one SSE client
sends `Bearer <token>` while PocketBase's other clients send the raw token.

## Implementation sequence

### Contract generation and seam proof

- Write a minimal valid spec containing one JSON operation, agent SSE, file
  bytes, and the observability proxy.
- Pin and run all generators locally.
- Prove the PocketBase-to-strict-server adapter preserves `RequestEvent.Auth`,
  PocketBase errors, path/query parameters, cancellation, and streaming flushes.
- Prove the generated Dart package builds in the workspace and accepts the
  deployment URL plus changing PocketBase auth token.
- Stop if any seam requires generated-file patches. Change configuration or the
  boundary instead; generated output must remain reproducible.

### Phase 2 — author and freeze the complete contract

- Add all 25 operations and group them by feature tags.
- Normalize JSON naming, file query paths, parameter names, success statuses,
  error envelopes, and auth/role metadata.
- Define reusable schemas for record IDs, errors, accepted/no-content results,
  harness auth state, release state, MCP requests, file entries, Ollama models,
  push requests, and agent actions/events.
- Set `additionalProperties: false` for owned request/response objects. Allow
  free-form objects only for explicitly dynamic protocol/upstream fields such
  as MCP config schema and opaque release metadata.
- Include representative examples and bounds/patterns for every identifier and
  enum.
- Replace `api/pocketcoder-routes.json` as a hand-maintained source. It may
  remain temporarily as generated output until the backend parity test reads
  OpenAPI directly.

### Phase 3 — make Go conform

- Generate Go code and introduce the PocketBase adapter.
- Move the 20 JSON operations behind the strict interface feature by feature.
- Standardize all errors and remove anonymous request/response structs and
  `map[string]any` where the contract owns the shape.
- Keep the five special transports handwritten and add media-type/stream-frame
  conformance tests.
- Replace the regex-only route manifest test with an OpenAPI-aware parity test
  that understands the observability router extension.

### Phase 4 — adopt the generated Dart client

- Add the generated package and shared auth/base-URL adapter.
- Migrate feature transports in small commits with repository-level tests.
- Remove duplicate handwritten request/response models after each feature is
  migrated; do not retain compatibility wrappers.
- Retain domain models only when they express product meaning rather than the
  wire format.

### Phase 5 — documentation and enforcement

- Render API reference documentation from the bundled spec in the website
  build. The checked-in YAML remains authoritative.
- Add a dedicated `openapi-contract` CI workflow triggered by the spec,
  generators, custom handlers, generated packages, and API tests.
- Run lint, bundle, generation, `git diff --exit-code`, Go tests, Dart package
  tests, Flutter analysis, and focused integration tests.
- Add a contract test for every documented status code and media type. Include
  unauthenticated, wrong-role, invalid-body, not-found, conflict, and upstream
  failure cases—not only successful examples.

## Required checks

The implementation is complete only when all of these hold:

- The spec contains exactly the 25 intended custom operations, or an explicitly
  reviewed replacement count after the file-path normalization.
- Every backend custom route appears in the spec and every spec route is
  registered by PocketBase.
- Every normal Go implementation satisfies the generated strict interface.
- No owned JSON response is constructed as an untyped map.
- The generated Dart package builds without manual edits.
- Flutter JSON transports no longer carry raw PocketCoder paths or handwritten
  JSON field names.
- SSE and NDJSON tests demonstrate incremental delivery rather than buffering.
- PocketBase auth, owner checks, and role restrictions behave identically
  through the adapter.
- Regeneration followed by `git diff --exit-code` is clean locally and in CI.
- The PocketBase collection model/export pipeline is unchanged.

## Non-goals

- Do not describe or generate PocketBase's standard collection API.
- Do not replace PocketBase authentication, rules, hooks, realtime, or
  `pocketbase_drift`.
- Do not convert streams into polling or buffered JSON.
- Do not create command collections for operations.
- Do not publish a central PocketCoder API service; every spec-described server
  remains the user's own deployment.
- Do not add backward-compatible routes, aliases, or dual JSON field names.
- Do not upgrade Go solely to use a newer generator; that is a separate,
  explicit toolchain decision.

## Principal risks

| Risk | Control |
|:---|:---|
| Generated handler bypasses PocketBase auth context | Exact PocketBase route registration, context adapter, and auth/role contract tests |
| Dart generator buffers streams | Generated client for normal calls only; incremental transports remain handwritten |
| Spec and generated code drift | One generation script, pinned tools, committed output, CI clean-diff check |
| Generator upgrade causes a massive unexplained diff | Upgrade pins in isolated commits and review generated diffs |
| Dynamic maps erase the value of the contract | Permit free-form JSON only where the upstream protocol is genuinely dynamic |
| Greedy PocketBase paths cannot be represented faithfully | Query parameter for files; explicit vendor extension for the opaque proxy |
| ACP package types leak into the public HTTP contract | Generated HTTP projections plus explicit ACP conversion functions |

The current implementation includes the contract, reproducible generators,
generated clients/types, route parity checks, and the adapter seam. The next
increment can migrate handlers behind the generated strict interface in small,
independently tested groups.
