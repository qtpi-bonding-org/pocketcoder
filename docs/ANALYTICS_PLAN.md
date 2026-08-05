# PocketCoder Flutter Diagnostics and Error Observability Plan

Status: Implemented locally; Docker/TestFlight validation pending

## Implementation status

Implemented in `client/packages/pocketcoder_flutter`:

- bounded pre-bootstrap diagnostic capture backed by the pinned Privserver
  `ErrorEntry`/storage API;
- Flutter framework and uncaught async error handlers installed from bootstrap;
- bootstrap queue flush after Privserver configuration;
- explicit capture at the main direct-Cubit failure boundaries, while leaving
  existing Cubit UI state transitions unchanged;
- safe single-entry and copy-all diagnostic report formatting;
- Error Inbox copy actions using an `AppCubit`/`UiFlowListener` flow;
- console error logging now records exception types instead of arbitrary
  exception messages.

Focused diagnostics/Error Inbox tests and the complete
`pocketcoder_flutter` test suite pass locally. The remaining validation is the
Docker golden-path failure matrix and a simulator/TestFlight reproduction of a
controlled failure.

Verification completed after implementation:

- 327 Flutter package tests pass.
- Global Flutter/async bridge tests pass.
- Direct harness-auth exactly-once capture test passes.
- Targeted Dart analysis is clean.
- FOSS purity check passes for the 199-package runtime closure, with the four
  existing named license allowlist exceptions reported by the checker.
- Current Docker topology is healthy: PocketBase, Goose, MCP gateway, and
  Ollama are healthy; Goose reaches Ollama over the internal network and sees
  the installed tool-capable models.
- The repository's legacy Docker BATS runner cannot currently execute its
  full matrix because it references a missing `docker-compose.test.yml` and
  removed `sandbox`/`opencode` services. This is a test-harness maintenance
  item, not a diagnostics implementation failure.

## Decision

PocketCoder does not need product analytics for the current Linode-to-phone
verification goal. We care about diagnosing failures, not measuring product
usage.

Do not build an analytics event inbox or third-party analytics integration at
this stage. Improve the existing `AppLogger` and `flutter_error_privserver`
integration instead.

## Goal

When a local, simulator, TestFlight, or production phone flow fails, the user
should be able to provide a useful diagnostic report without SSH access or a
development console.

The system should capture safe technical error context locally, show it in the
existing Error Inbox, and allow the user to copy/export it for support or
debugging.

## Privacy and capture rules

Follow the pinned `flutter_error_privserver` design and the existing
`tryMethod` rules:

- Privacy comes from what is captured, not from redacting arbitrary logs.
- Capture only developer-controlled technical fields: source, operation name,
  exception type, mapped error code, full stack trace, and optional localized
  user message.
- Never capture prompts, chat messages, file contents, tokens, secrets,
  credentials, email addresses, names, arbitrary user input, or raw network
  payloads.
- Do not serialize arbitrary exception messages into diagnostic context.
- Technical labels and operation names must be static developer-controlled
  strings.
- Diagnostics must never block, fail, or materially delay the user operation.
- Preserve the full original stack trace for local debugging, as Privserver
  does. Do not add generic ANSI stripping, truncation, or redaction to the
  Privserver error record.

## Current state

- `AppLogger` writes timestamped messages to `debugPrint`.
- `tryMethod` wraps service/repository failures with a safe method name and
  preserves the original stack.
- `AppCubit` uses `ErrorPrivserverMixin` for Cubits built on the shared base.
- The Error Inbox provides local persisted Privserver entries.
- There is no reliable global Flutter/async error bridge.
- Several direct `Cubit` classes bypass `AppCubit` and its Privserver path.
- Early bootstrap failures can happen before Privserver is configured.
- The Error Inbox does not yet provide a convenient copy/export diagnostics
  action.
- AppLogger output is not persisted and should not be treated as the durable
  error-reporting system.

## Responsibility boundaries

### PocketCoder architecture rules

- Keep shared implementation in the FOSS-pure `pocketcoder_flutter` package;
  do not add Firebase, Sentry, proprietary analytics, or other proprietary
  SDKs to that package.
- Put Cubits and UI state in `lib/application/`, repositories/services in
  their existing infrastructure areas, and presentation widgets in
  `lib/presentation/`.
- Register new services through injectable/GetIt and regenerate the injectable
  configuration. Do not hand-edit generated DI files.
- Use the existing `AppCubit`/`TryOperationCubit` and
  `IUiFlowState`/`UiFlowStatus` conventions for UI-facing flows.
- Use the existing `UiFlowListener`/feedback conventions for user-visible
  success and failure messages; do not add ad-hoc loading or toast handling.
- Keep the diagnostics feature itself covered by unit/widget tests and keep
  the existing package purity checks passing.

### `tryMethod`

`tryMethod` remains the service/repository boundary:

- wrap unexpected exceptions with a static method name and safe exception
  cause;
- preserve the original stack trace;
- allow the owning feature/Cubit to surface the typed failure;
- do not write logs or Privserver entries automatically unless that is already
  the explicit owner of the failure.

### `tryOperation`

`tryOperation` remains the Cubit state boundary:

- emit loading/success/failure states;
- preserve the typed error behavior;
- capture the operation failure through the existing Privserver mixin where
  configured;
- do not become a generic logging or analytics recorder.

The implementation must preserve `cubit_ui_flow` behavior: loading and failure
states remain represented by the Cubit's `IUiFlowState`, and diagnostics are a
side effect of the failure path rather than a replacement for state handling.

### `AppLogger`

`AppLogger` remains useful for development console output and short-lived
diagnostic breadcrumbs. It must not become an arbitrary production log dump.

If a persistent breadcrumb buffer is added later, it must accept structured,
allowlisted technical records only and remain separate from Privserver error
entries.

## Implementation plan

### 1. Add a single Privserver capture adapter

Create a small shared helper in
`packages/pocketcoder_flutter/lib/infrastructure/errors/` that is the app's
single entry point for capturing structured errors.

The helper should:

- accept an error, stack, static source, and optional controlled operation/code;
- map exceptions through the existing error-code mapper;
- delegate to the pinned Privserver API;
- no-op safely if Privserver is not configured yet;
- never throw back into the application operation.

The adapter must integrate with the existing `ErrorPrivserverMixin` and
configuration rather than bypassing `cubit_ui_flow` or introducing a parallel
error-state mechanism.

Do not modify the pinned dependency or create a second error-record format
unless the existing API cannot support the required bootstrap behavior.

### 2. Install global error bridges early

Install handlers as early as the application entrypoint allows:

- `FlutterError.onError` for framework errors;
- `PlatformDispatcher.instance.onError` for uncaught async errors;
- `runZonedGuarded` only if needed to cover a remaining uncaught boundary.

Before Privserver is configured, queue only the safe structured fields in a
small bounded bootstrap buffer. Flush the buffer after configuration. Never
queue arbitrary log strings or raw request data.

### 3. Audit direct Cubits

Classify every direct `Cubit` that does not extend `AppCubit`:

- migrate it to `AppCubit` when its state supports the shared UI-flow model;
- otherwise add explicit capture at its operation boundary through the shared
  adapter;
- do not duplicate capture in both the Cubit and repository for one failure.

Priority areas are authentication, harness login, chat/session transport,
deployment, notifications, and bootstrap-related services.

### 4. Improve Error Inbox diagnostics export

Add a user-triggered copy/export action to the existing Error Inbox. Export
only Privserver's safe fields:

- timestamp;
- source;
- exception type;
- mapped error code;
- localized user message, if present;
- full stack trace.

Do not export `AppLogger` arbitrary messages, chat content, request bodies, or
credentials. The UI should clearly label the output as a diagnostic report.

Implement the screen action using the existing Cubit/UI-flow conventions:
the operation has explicit loading/success/failure state, uses the shared
feedback/listener path, and never blocks the screen on clipboard/export work.

### 5. Keep console logging useful

Audit high-value `AppLogger` calls around:

- PocketBase connection/bootstrap;
- Linode deployment;
- harness authentication;
- chat/session creation and streaming;
- push registration and delivery observation.

Messages must use static technical labels and may include controlled status
values. Do not log tokens, authorization URLs containing secrets, prompts,
responses, file paths supplied by users, or raw exception text.

## Testing plan

Unit tests must verify:

- the adapter captures source, type, mapped code, message, and stack correctly;
- capture never throws when Privserver is unavailable;
- bootstrap errors are queued and flushed safely;
- the global Flutter and async handlers reach the adapter;
- direct-Cubit failures reach the adapter exactly once;
- no unsafe payload fields are accepted;
- Error Inbox export contains only the approved fields.

Integration tests should verify the local Docker golden path for:

- PocketBase connection failure;
- deployment failure;
- Codex authentication failure;
- Claude Code authentication failure;
- chat send/receive failure;
- push registration failure.

Each test should assert that a structured diagnostic entry is created and that
prompts, responses, tokens, and credentials are absent from the exported
report.

For TestFlight, verify that a user can reproduce a controlled failure, open
the Error Inbox, copy the diagnostic report, and provide it without attaching
Xcode or SSH logs.

## Delivery phases

1. Implement the capture adapter and unit tests.
2. Add early global error handlers and bootstrap buffering.
3. Audit/migrate direct Cubits in the golden path.
4. Add Error Inbox copy/export.
5. Audit high-value console logs and run local Docker integration tests.
6. Verify the complete diagnostics flow on simulator, then TestFlight phone.

## Explicit non-goals

- No product analytics.
- No third-party analytics SDK.
- No arbitrary production log upload.
- No generic redaction pass over unsafe logs.
- No prompts, messages, files, tokens, credentials, or user identity in
  diagnostics.
- No schema migration or backward-compatibility layer for this work.
