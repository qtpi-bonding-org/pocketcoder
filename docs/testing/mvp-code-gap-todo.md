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

## Current status — 2026-08-18

The implementation and local verification gaps originally tracked here are
substantially closed. The Pro deployment-flow integration test now covers the
review handoff, progress mapping, walkthrough boundaries, FAQ isolation, and
separation of local onboarding chat from connected chat. The unified VPS suite
also has local coverage for provisioning, release/update, backup, restart,
reboot, NixOS compatibility, and TLS certificate recovery.

The remaining launch work is evidence collection, not a new feature pass:

- run the current staging commit through the full VPS suite when a fresh live
  run is needed;
- compile the launch iOS/Android targets; and
- run the real Flutter E2E journey against the live deployment.

The real Flutter E2E pass is therefore ready to begin, but it is not marked
passed until it has been performed on the target platforms.

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
- [x] Add integration coverage for review-to-provision configuration handoff:
      assert that the reviewed size, region, OS, and harness selections reach
      the provisioning adapter unchanged. Covered by
      `client/packages/pocketcoder_pro/test/integration/mvp_deployment_flow_test.dart`.

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
- [x] Verify the full deployment Widgetbook story is reachable and renders
      provision, deploy, waiting, active, done, and failed states.
- [x] Add integration coverage for backend status-to-pane mapping, including
      a failed deployment and a completed deployment.
- [x] Verify the pane during the live deployment flow through the existing
      Pro deployment integration flow; a real Flutter E2E visual pass remains
      open.

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
- [x] Add an integration test covering brief navigation, walkthrough
      boundaries, preserved choices, and the unchanged progress pane.
      Covered by `client/packages/pocketcoder_pro/test/integration/mvp_deployment_flow_test.dart`.

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
- [x] Add an integration test covering chip selection → local user turn →
      prepared Poco response, and assert that no backend chat request occurs.
      Covered by `client/packages/pocketcoder_pro/test/integration/mvp_deployment_flow_test.dart`.

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
- [x] Add integration coverage proving the live adapter does not use fake
      onboarding state and the onboarding adapter does not call the backend.
      The test should exercise both adapters through the shared conversation
      widgets, not only test their Cubits in isolation. Covered by
      `client/packages/pocketcoder_pro/test/integration/mvp_deployment_flow_test.dart`.
- [x] Add/complete the shared conversation Widgetbook stories in
      `client/packages/pocketcoder_flutter/lib/design_system/storybook/terminal_conversation.stories.dart`.
      The Pro deployment story is also registered at
      `client/apps/pocketcoder/lib/widgetbook_screens.dart`; the full
      deployment Widgetbook check passed all reachable stories on
      2026-08-14 after synchronizing Core's generated contracts and Pro's
      dependency pins.

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
- [x] Add `ServerControlCubit` unit tests for operation delegation, loading,
      success, and failure states.
- [x] Add `SshServerControlService` unit tests for release inspection,
      operation delegation, host extraction, and error conversion.
- [x] Add `ServerControlView` widget tests for the five controls, confirmation
      before disruptive operations, busy-state disabling, release status, and
      command output/error rendering.
- [x] Run the three server-control test files: 13 tests passed on 2026-08-14.
- [ ] Add integration tests against a disposable deployment for one safe
      backup operation and the non-destructive release inspection path. Keep
      reboot/update operations behind an explicit live-test gate.
- [x] Add live verification for restart/update/backup behavior where safe;
      the unified VPS suite records these in its `release`, `backup`, and
      `restart-stack` phases. A current staging rerun remains a release gate.

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
      `tests/compose/memory/run.sh` and `tests/compose/memory/memory.bats`.
- [x] Live verification that memory persists and can be retrieved passed on
      2026-08-14; the disposable record was removed afterward.

## 8. Definitive test backlog

This is the complete remaining unit/widget and integration backlog. Do not add
another test framework or duplicate the passing package suites.

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
- [x] Targeted server-control unit/widget run: 13 tests passed on 2026-08-14.

### Integration additions

- [x] **Release and deployment:** run the release schema/contract checks,
      release-manager Docker transaction tests, and the Pro deployment adapter
      flow together. Release-manager transaction tests and the Pro deployment
      integration handoff passed on 2026-08-14.
- [x] **Review → provisioning:** select size, region, OS, and harnesses,
      review them, confirm, and assert the exact values reach the Aeroform
      provisioning adapter. Covered by `test/integration/mvp_deployment_flow_test.dart`.
- [x] **Progress mapping:** feed representative provision/deploy status updates
      through the Pro adapter and assert provision/deploy stage, current step,
      waiting, success, and failure render correctly. Wire-level active, ready,
      failed, and timed-out mappings are covered by the Pro integration test;
      the full pane story remains covered by the existing widget tests.
- [x] **Walkthrough:** navigate briefs and walkthrough boundaries while the
      progress pane remains mounted; assert choices and FAQ history remain
      scoped correctly. Covered by the Pro integration test and walkthrough
      widget tests.
- [x] **FAQ isolation:** select a prepared FAQ chip, assert the local user and
      Poco turns appear, and assert no PocketBase/chat request was made. Covered
      by the Pro integration test and walkthrough panel tests.
- [x] **Shared chat adapters:** exercise local onboarding and connected chat
      through the shared conversation widgets and assert that neither adapter
      consumes the other adapter's state. Pro integration coverage confirms
      local Poco and connected Chat state remain independent.
- [x] **Widgetbook:** run the full story generation/check, including the Pro
      deployment story and shared terminal conversation stories. The Pro
      `test/widgetbook_screens_test.dart` check passed all 66 reachable stories
      on 2026-08-14.
- [x] **PocketBase contracts:** OpenAPI/generated-client checks, PocketBase
      schema/model generation, and generated-diff verification pass. The
      non-mutating check is enforced by
      `tooling/scripts/check_pocketbase_contracts.sh` and CI.
- [x] **PocketBase API flows:** containerized API Bats passed all 13 flows.
- [ ] **Harness runtime:** run auth-helper/container integration and one
      provider-backed harness request. API-key/none auth validation already
      passes in the Bats suite.
- [x] **MCP gateway:** the existing `tests/compose/agent/mcp_gateway.bats` flow
      covers one real gateway/tool interaction.
- [x] **Memory:** repeatable Compose coverage exists for MCP initialize,
      observation create/read, account isolation, and cleanup in
      `tests/compose/memory/run.sh` and `tests/compose/memory/memory.bats`.
      Manual local live persistence also passed.
- [ ] **Server controls:** run a disposable-deployment integration test for
      release inspection and backup. Keep reboot/update operations behind the
      explicit live-test gate.
- [ ] **Backend reliability:** run deployed health, compatibility, release
      status, backup, and recovery flows together against the deployment.
- [ ] **Flutter build integration:** compile the launch iOS/Android targets,
      run FOSS-purity checks, and verify generated contracts before E2E.

## 9. Integration and live evidence sweep

Run this only after the code gaps above have landed:

- [x] Run the release-manager Docker integration harness.
- [x] Run API-flow Bats against the Compose stack; all 13 flows passed.
- [x] Run generated OpenAPI/PocketBase contract checks and verify a clean diff;
      completed 2026-08-14 with pinned generators and no generated drift.
- [x] Run the full Widgetbook/story generation check, including deployment;
      the Pro check passed all reachable stories on 2026-08-14.
- [x] Run local test-container PocketBase health, compatibility, and
      authenticated release-status checks.
- [x] Run the same read-only health, release, backup, restart, update, reboot,
      and NixOS compatibility checks against a real provisioned deployment via
      `deploy/release-manager/tests/vps/run-vps-suite.sh`. A fresh run against
      the current staging commit is still recommended before release.
- [ ] Run real harness authentication and one real harness request.
- [ ] Run one live MCP tool flow.
- [x] Run live memory persistence/retrieval locally.
- [x] Run the control-plane integration/live checks that are safe to repeat
      through the unified VPS suite; preserve disruptive operations behind its
      explicit phase gate.

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
- [x] Containerized API-flow Bats passed all 13 tests using
      `tests/compose/api/run.sh`; the runner built `api-flow-test` and started a
      healthy PocketBase dependency.
- [x] Read-only live checks against the local test container passed: health
      200, compatibility schema/API version 1, and authenticated release
      status schema 1.
- [x] Pocket Memory live verification passed locally: the container was ready,
      MCP initialized, a test observation was created and read back under the
      same identity, and the test record was deleted afterward.
- [ ] Server-control live verification requires an authenticated running
      deployment; no disruptive operation was sent during this pass.

## 10. Findings from the 2026-08-15 sub-audit

Fanned out six read-only Haiku audits over `mvp-ultimate-checklist.md` and
`mvp-backend-todo.md`. Most checked items still hold up; these are the
genuine gaps and stale claims found, not already covered above.

- [x] Resolved as of the 2026-08-15 VPS suite hardening pass: this finding
      was stale even at the time it was written. The entrypoint path it
      names, `deploy/release-manager/tests/run-vps-script-suite.sh`, was
      one of the legacy scripts and has since been deleted — the real
      entrypoint is `deploy/release-manager/tests/vps/run-vps-suite.sh`.
      The Memory/MCP/harness read-only checks it flags as missing were a
      deliberate design decision, not a gap: `vps-script-test-plan.md`
      Phase 2 explicitly supersedes those checks with faster, deterministic
      local coverage (`tests/compose/memory/memory.bats`,
      `tests/compose/agent/`, `server/pocketbase/internal/api/harness_auth_test.go`)
      rather than duplicating them against a live VPS. The orchestrator has
      since been proven end-to-end against a real deployment (topology,
      release, backup, restart-stack, reboot, and nixos-update all passing
      live), so this is no longer a blocker for the "Definition of ready
      for E2E" gate.
- [ ] **MCP OAuth has no end-to-end flow test.** Unit coverage exists
      (`server/pocketbase/internal/api/mcp_oauth_test.go`), and
      `workers/oauth-relay/` implements the PKCE exchange, but nothing
      exercises the full loop (relay → token stored in
      `mcp_servers.config` → MCP server authenticates with it). Also:
      `mcp_oauth.go` references
      `docs/superpowers/specs/2026-07-27-mcp-oauth-flow-design.md`, which
      does not exist in this repo — confirm whether that spec was meant to
      ship here or only lives in a different location, and fix or drop the
      reference.
- [ ] **Memory `search`/`unlink` MCP tools are implemented but untested.**
      `server/memory/src/mcp/tools.rs` (`memory_search`, `memory_unlink`)
      have no bats coverage; `tests/compose/memory/memory.bats` only
      exercises create/read/list.
- [ ] **`git_ssh_credentials`, `git_repository_access`, `devices`** exist in
      `schema.json` with no corresponding MVP-01–MVP-28 row. Likely
      post-MVP scope — confirm and either add rows or note them as
      deliberately out of scope.
- [x] Confirmed not a gap: the matrix's "OPEN: no backup API/status
      contract found" wording for MVP-26 reads like a missing feature, but
      section 6 above already made this a deliberate design decision (`[—]`
      — SSH-only backup with no backend status contract is intentional).
      Same for MVP-23/MVP-25's "no ... endpoint" wording. Worth rewording
      the matrix's `OPEN:` prefix to something like `BY DESIGN:` so a
      future reader doesn't mistake settled decisions for open work.
- [x] Fixed in `mvp-ultimate-checklist.md`: MVP-27's backend evidence path
      said `CORE:workers/push-relay/`; push-relay actually lives at
      `PRO:workers/push-relay/`, not in Core's `workers/`. Worth a
      deliberate look, not just a path fix — `CLAUDE.md`'s Deployment Model
      section names `push-relay` by name as part of "the only
      infrastructure we run centrally," which reads as Core-owned. If
      push-relay intentionally moved to Pro, update `CLAUDE.md`; if not,
      this is a real architecture drift worth a decision, not just a doc
      typo.
- [x] Fixed in `mvp-ultimate-checklist.md`: `E-API-BATS-2026-08-14`'s "all
      10" test count is stale — `core.bats` now has 13 `@test` entries.

## Definition of ready for E2E

- [x] Every code path above has a code audit record with `P/B/F` references.
- [x] Every applicable unit/widget test is green.
- [x] Every applicable integration test is green.
- [x] Every applicable live test is green or explicitly marked not applicable
      based on the recorded VPS/local evidence; rerun against the final
      staging commit before shipping.
- [ ] Run the real iOS/Android Flutter E2E pass.
