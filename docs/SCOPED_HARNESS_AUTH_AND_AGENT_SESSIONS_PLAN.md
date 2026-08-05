# Scoped Harness Authentication and Generic Agent Sessions

## Summary

Replace the current development-only schema with a clean scoped design. The
first runtime scope is `user/<PocketBase user id>`; there are no existing users
or data to preserve. Codex, Claude Code, and future harnesses use the same
account-auth lifecycle, while Goose remains multi-provider.

## Key changes

- Replace `goose_sessions` with generic `agent_sessions`: one chat maps to one
  ACP session on one harness instance. Rename API, coordinator, PocketBase, and
  Flutter types from Goose-specific names to agent/ACP names.
- Add `harness_auth_bindings` and short-lived `harness_auth_attempts`, keyed by
  `scope_kind` and `scope_id`. Store connection state and timestamps only;
  never OAuth URLs, device codes, auth codes, tokens, or raw CLI output.
- Scope `harness_instances`, provider keys, auth volumes, workspace volumes,
  and container lookup to the same user identity. Update uniqueness rules so
  separate users cannot reuse each other's runtime or credentials.
- Keep `model_provider` nullable on a harness instance for provider-pinned
  harnesses, and nullable on `agent_sessions` as the actual model-provider
  snapshot. Goose has no instance-level provider pin; its selected provider is
  recorded per session.
- Do not add a singular provider field to the harness catalog. Preserve
  Goose's multi-provider model behavior.
- Generalize Docker creation to support labeled, scoped containers and multiple
  named mounts: isolated workspace plus isolated harness-home/auth volume.
- Add a private, short-lived auth helper inside the selected harness image.
  PocketBase starts, polls, submits Claude browser codes to, and destroys this
  helper through an internal authenticated API—never Docker attach or SSH.
- Implement concrete Codex device-code and Claude Code browser-code
  authenticators behind a shared Go interface. A successful flow persists only
  inside the scoped auth volume and makes the normal harness runtime usable.
- Add PocketBase endpoints for connection status, start, poll, Claude-code
  submit, cancel, and disconnect. An explicit credential mode selects exactly
  one source per scoped harness: account login, API key, or none.
- Add a “Harness connections” section to the existing Flutter Provider screen
  for status, start, browser/device challenge display, code entry when
  required, cancellation, and disconnect. Keep provider-key controls available
  for API-key mode.
- Preserve actual Goose-specific behavior—scheduler integration, Cognee, and
  Goose configuration—while removing only the misleading session/runtime
  naming.

## Test plan

- Regenerate the flat schema and schema tests with no compatibility or data
  migration path.
- Unit-test scope resolution, credential-mode selection, session persistence,
  provider snapshots, and prevention of cross-user provider-key/auth-volume/
  container reuse.
- Test auth-helper protocol transitions: start, browser wait, code submit,
  success, failure, expiry, cancellation, and secret-safe error handling.
- Test Docker provisioning with distinct scoped workspace and auth mounts,
  labels, cleanup, and runtime reuse.
- Run container-level Codex and Claude Code login checks using separate named
  volumes; verify a real authenticated prompt succeeds and that one scope
  cannot use another scope's credentials.
- Add Flutter/API tests for connection state rendering and challenge submission,
  plus existing agent-session behavior under the renamed generic contract.

## Assumptions

- This is a clean development cutover: no existing users or data are migrated,
  and no backward-compatibility tables, endpoints, or model aliases are kept.
- Scope is designed for future multi-user use now; initial supported scope
  values are `user` and `deployment`, with production chat execution using
  `user`.
- The existing Provider screen is the connection-management home.
