# PocketCoder MVP — Code Gap TODO

This list tracks the implementation and verification gaps found during the
atomic MVP-01..MVP-28 audit. It is intentionally separate from the launch
checklist and covers both repositories. Complete the code, unit/widget,
integration, and applicable live levels before beginning the final E2E pass.

The remaining test work below is deliberately limited to MVP behavior. It does
not require a new test framework or a new product API: unit/widget tests use
the existing Flutter fakes, and integration tests use the existing Compose,
Bats, Docker release-manager, and Pro test harnesses.

Core/FOSS is `/Users/aicoder/Documents/pocketcoder`. Pro is the sibling
repository `/Users/aicoder/Documents/pocketcoder-pro`; it owns the proprietary
app assembly, RevenueCat, Aeroform deployment orchestration, deployment
onboarding/review/progress presentation, walkthrough presentation, and Pro
Widgetbook. Where Pro already implements an item below, the remaining work is
audit, wiring, and evidence—not reimplementing it in Core.

Onboarding walkthrough chat is intentionally local/fake and uses prepared
content. Connected chat uses the real `ChatCubit`/API. Shared presentation
widgets may be reused, but state and adapters stay separate.

## 1. Dedicated review flow — Pro implementation exists

Related: MVP-04, MVP-05, MVP-06

- [x] Pro implementation: `client/packages/pocketcoder_pro/lib/presentation/deployment/details_screen.dart`,
      `widgets/details_view.dart`, and `adapters/details_adapter.dart`.
- [ ] Verify it displays the selected provider, size, region, OS, harnesses, estimated
      cost, and relevant memory-sizing guidance.
- [ ] Verify the review action is the single confirmation point before provisioning.
- [ ] Verify earlier choices remain when navigating back from review.
- [ ] Verify localized copy and terminal/CRT styling use shared theme tokens.
- [x] Pro tests exist at `client/packages/pocketcoder_pro/test/presentation/deployment/details_screen_test.dart` and `config_view_test.dart`.
- [x] Run/record those tests; the Pro suite passed on 2026-08-14.
- [ ] Add or confirm narrow-mobile review coverage if the existing test does
      not exercise the constrained layout.
- [ ] Add integration coverage for review-to-provision configuration handoff:
      assert that the reviewed size, region, OS, and harness selections reach
      the provisioning adapter unchanged.

## 2. PocketCoder progress pane — Pro implementation exists

Related: MVP-02, MVP-07, MVP-08, MVP-21

- [x] Pro implementation: `client/packages/pocketcoder_pro/lib/presentation/deployment/widgets/pocketcoder_progress_pane.dart`,
      `progress_view.dart`, and `adapters/progress_adapter.dart`.
- [ ] Verify provision and deploy are separate stages with current-step
      text, terminal status glyphs, and truthful backend state.
- [ ] Verify output/details are expandable and hidden by default.
- [ ] Verify active, waiting, done, and failed states without fabricated
      percentages.
- [x] Pro adapter and tests exist at `client/packages/pocketcoder_pro/lib/presentation/deployment/adapters/progress_adapter.dart` and `client/packages/pocketcoder_pro/test/presentation/deployment/pocketcoder_progress_pane_test.dart`.
- [x] Pro Widgetbook screen registry exists at `client/apps/pocketcoder/lib/widgetbook_screens.dart`.
- [x] Run/record every-state widget tests; the Pro suite passed on 2026-08-14.
- [ ] Verify the full deployment Widgetbook story is reachable and renders
      provision, deploy, waiting, active, done, and failed states.
- [ ] Add integration coverage for backend status-to-pane mapping, including
      a failed deployment and a completed deployment.
- [ ] Verify the pane during the live deployment flow.

## 3. Walkthrough and brief state — Pro implementation exists

Related: MVP-07, MVP-08, MVP-21, MVP-22

- [x] Pro models/state: `client/packages/pocketcoder_pro/lib/domain/deployment/walkthrough.dart`, `application/walkthrough/walkthrough_state.dart`, and `walkthrough_cubit.dart`.
- [x] Verify the Cubit tracks the current walkthrough and brief without
      turning them into separate product task objects.
- [x] Pro presentation: `client/packages/pocketcoder_pro/lib/presentation/deployment/widgets/walkthrough_panel.dart`, `walkthrough_conversation_view.dart`, `walkthrough_brief.dart`, and `walkthrough_snippet.dart`.
- [x] Verify each walkthrough is a bounded terminal conversation session.
- [x] Verify the same provision/deploy progress pane remains while moving between
      walkthroughs and briefs.
- [x] Keep the onboarding walkthrough local/fake; do not call the real chat API.
- [x] Pro Cubit tests exist at `client/packages/pocketcoder_pro/test/application/walkthrough/walkthrough_cubit_test.dart`.
- [x] Run/record selection, next/previous, boundaries, and
      preserved choices.
- [x] Add widget tests for long briefs, long snippets, and narrow layouts.
- [ ] Add an integration test covering brief navigation, walkthrough
      boundaries, preserved choices, and the unchanged progress pane.

## 4. FAQ chips and prepared Poco responses — Pro state exists

Related: MVP-07, MVP-08, MVP-22

- [x] Pro FAQ history/state exists in `client/packages/pocketcoder_pro/lib/application/walkthrough/walkthrough_cubit.dart` via `addFaqTurn` and `faqHistory`.
- [x] Verify contextual chip data and prepared local Poco responses for each walkthrough/brief.
- [x] Selecting a chip should append a user-like turn to the local
      onboarding conversation and append Poco's prepared response.
- [x] Keep the onboarding interaction local; it must not create a backend chat
      request.
- [x] Verify chips use the shared terminal suggestion widget and no UI emoji.
- [x] Pro Cubit tests cover FAQ history and duplicate taps in `client/packages/pocketcoder_pro/test/application/walkthrough/walkthrough_cubit_test.dart`.
- [x] Run/record widget tests for wrapping, long labels, and narrow mobile layouts.
- [ ] Add an integration test covering chip selection → local user turn →
      prepared Poco response, and assert that no backend chat request occurs.

## 5. Shared chat widget wiring

Related: MVP-07, MVP-11, MVP-12, MVP-13, MVP-14, MVP-21, MVP-22

- [x] Make the shared terminal conversation widgets the presentation layer
      for both local onboarding and live chat.
- [x] Keep separate adapters/state sources: local `PocoCubit` for onboarding;
      live `ChatCubit` for connected chat.
- [x] Reuse shared rendering for Poco turns, user turns, terminal commands,
      status glyphs, expandable output, approvals, and composer behavior.
- [x] Ensure historical chat and the current assistant turn render correctly
      without stale Poco messages leaking between steps.
- [x] Unit/widget coverage passed in Core's full 350-test suite, including
      `test/presentation/core/terminal_conversation_test.dart`,
      `test/presentation/chat/pocketcoder_chat_builders_test.dart`, and
      `test/presentation/onboarding/onboarding_screen_test.dart`.
- [ ] Add integration coverage proving the live adapter does not use fake
      onboarding state and the onboarding adapter does not call the backend.
      The test should exercise both adapters through the shared conversation
      widgets, not only test their Cubits in isolation.
- [ ] Add/complete Widgetbook stories for the shared conversation states.

## 6. Server controls — implementation complete; verification remains

Related: MVP-23, MVP-24, MVP-25, MVP-26

- [x] Define the supported five-operation contract: restart PocketCoder,
      update PocketCoder, restart NixOS, update NixOS, and save backup.
- [—] No backend operation/status endpoint is required: controls intentionally
      use the owner's typed root-SSH path through Pro/Aeroform.
- [x] Complete the reviewed typed root-SSH command mapping in
      `client/packages/pocketcoder_flutter/lib/infrastructure/os_control/`; no
      arbitrary shell execution is exposed.
- [—] No separate backup API/status path is required: backup is one reviewed
      typed root-SSH operation invoking the deployed backup script.
- [x] Add the shared `ServerControlCubit`, service, and terminal-styled view
      with explicit confirmation for disruptive operations.
- [x] Reuse Aeroform's existing secure-storage credential provider in Pro:
      `client/packages/pocketcoder_pro/lib/infrastructure/pocketcoder_update/aeroform_root_ssh_credentials_provider.dart`.
- [x] Replace the update-only service/screen with the unified
      `SshServerControlService` and `ServerControlScreen`.
- [ ] Add `ServerControlCubit` unit tests for operation delegation, loading,
      success, and failure states.
- [ ] Add `SshServerControlService` unit tests for release inspection,
      operation delegation, host extraction, and error conversion.
- [ ] Add `ServerControlView` widget tests for the five controls, confirmation
      before disruptive operations, busy-state disabling, release status, and
      command output/error rendering.
- [ ] Add integration tests against a disposable deployment for one safe
      backup operation and the non-destructive release inspection path. Keep
      reboot/update operations behind an explicit live-test gate.
- [ ] Add live verification for restart/update/backup behavior where safe.

## 7. Memory inspection UI

Related: MVP-19, MVP-20

- [x] Smallest MVP surface selected: the existing read-only SQLPage memory
      dashboard shows counts, recent observations, interpretations, links, and
      interpretation details.
- [x] Reuse the existing PocketBase-to-SQLPage proxy instead of adding a second
      memory REST/client contract or exposing primitive storage operations as
      MCP tools.
- [x] Preserve the many-to-many observation/interpretation source of truth;
      the dashboard reads the canonical memory database without mutations.
- [x] Add an authenticated in-app WebView entry point at the Settings surface:
      `MemoryDashboardScreen` loads `memory.sql` with the PocketBase token.
- [x] Add backend authorization coverage for ordinary authenticated access in
      `TestMemoryDashboardIsAvailableToAuthenticatedUser`; Flutter widget/live
      coverage remains open.
- [x] Add a repeatable Compose integration test against the memory container:
      initialize the MCP session, create an observation, retrieve it, verify
      account isolation, and remove the disposable test volume. See
      `tests/memory/run.sh` and `tests/memory/memory.bats`.
- [x] Live verification that memory persists and can be retrieved passed on
      2026-08-14; the disposable record was removed afterward.

## 8. Required remaining test additions

These are the actual new test files/flows still needed. Existing broad suites
already cover the rest of the unit and integration surface.

### Unit/widget additions

- [x] Core Flutter `server_control_cubit_test.dart`: all five operation
      branches, loading/success/failure state transitions, and release
      inspection.
- [x] Core Flutter `ssh_server_control_service_test.dart`: typed command
      delegation, PocketBase host extraction, release inspection delegation,
      and wrapped failures.
- [x] Core Flutter `server_control_view_test.dart`: five controls, confirm
      dialog, disabled/busy state, release status, success output, and error
      output.

### Integration additions

- [ ] Pro review-to-provision handoff flow.
- [ ] Pro walkthrough boundary/brief/FAQ flow with no backend request.
- [ ] Shared chat adapter separation flow: fake onboarding versus real chat.
- [ ] Full deployment Widgetbook story check.
- [ ] Compose memory MCP create/read/isolation/delete flow.
- [x] One real MCP gateway/tool flow (`tests/agent-c1/mcp_gateway.bats`).
- [x] One real harness authentication flow (`tests/api-flows/core.bats`); a
      real provider-backed harness request remains an explicit live test.
- [ ] Disposable server-control inspection/backup flow; disruptive commands
      remain explicit live tests.

## 9. Integration and live evidence sweep

Run this only after the code gaps above have landed:

- [x] Run the release-manager Docker integration harness.
- [x] Run API-flow Bats against the Compose stack; all 10 flows passed.
- [ ] Run generated OpenAPI/PocketBase contract checks and verify a clean diff.
- [ ] Run the full Widgetbook/story generation check, including deployment.
- [x] Run local test-container PocketBase health, compatibility, and
      authenticated release-status checks.
- [ ] Run the same checks against the real provisioned deployment.
- [ ] Run real harness authentication and one real harness request.
- [ ] Run one live MCP tool flow.
- [x] Run live memory persistence/retrieval locally.
- [ ] Run the control-plane integration/live checks that are safe to repeat.

### Verification pass — 2026-08-14

- [x] Core analyzer and full Flutter suite passed: 350 tests.
- [x] Pro dependency resolution and code generation completed; Pro full
      package suite passed 64 tests. Two billed live tests were intentionally
      skipped by explicit environment gates.
- [x] PocketBase backend `go test ./...` passed.
- [x] Pocket Memory `cargo test` passed.
- [x] Pinned release-contract validation passed.
- [x] Release-manager Docker integration passed with successful migration,
      failed-migration snapshot restore, idempotency, concurrency, and recovery
      phase coverage. The harness cleaned up only its temporary fixtures.
- [x] Containerized API-flow Bats passed all 10 tests using
      `tests/api-flows/run.sh`; the runner built `api-flow-test` and started a
      healthy PocketBase dependency.
- [x] Read-only live checks against the local test container passed: health
      200, compatibility schema/API version 1, and authenticated release
      status schema 1.
- [x] Pocket Memory live verification passed locally: the container was ready,
      MCP initialized, a test observation was created and read back under the
      same identity, and the test record was deleted afterward.
- [ ] Server-control live verification requires an authenticated running
      deployment; no disruptive operation was sent during this pass.

## Definition of ready for E2E

- [ ] Every code path above has a code audit record with `P/B/F` references.
- [ ] Every applicable unit/widget test is green.
- [ ] Every applicable integration test is green.
- [ ] Every applicable live test is green or explicitly marked not applicable.
- [ ] Only then begin the real iOS/Android Flutter E2E pass.
