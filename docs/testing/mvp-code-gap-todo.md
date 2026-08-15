# PocketCoder MVP — Code Gap TODO

This list tracks the implementation and verification gaps found during the
atomic MVP-01..MVP-28 audit. It is intentionally separate from the launch
checklist and covers both repositories. Complete the code, unit/widget,
integration, and applicable live levels before beginning the final E2E pass.

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
- [ ] Run/record those tests and add narrow-mobile coverage if absent.
- [ ] Add integration coverage for review-to-provision configuration handoff.

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
- [ ] Run/record every-state tests and verify the full deployment story is reachable.
- [ ] Add integration coverage for backend status-to-pane mapping.
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
- [ ] Add integration coverage for walkthrough state transitions.

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
- [ ] Add integration coverage for chip-to-conversation state updates.

## 5. Shared chat widget wiring

Related: MVP-07, MVP-11, MVP-12, MVP-13, MVP-14, MVP-21, MVP-22

- [ ] Make the shared terminal conversation widgets the presentation layer
      for both local onboarding and live chat.
- [ ] Keep separate adapters/state sources: local `PocoCubit` for onboarding;
      live `ChatCubit` for connected chat.
- [ ] Reuse shared rendering for Poco turns, user turns, terminal commands,
      status glyphs, expandable output, approvals, and composer behavior.
- [ ] Ensure historical chat and the current assistant turn render correctly
      without stale Poco messages leaking between steps.
- [ ] Add unit/widget tests for both adapters using the same widgets.
- [ ] Add integration coverage proving the live adapter does not use fake
      onboarding state and the onboarding adapter does not call the backend.
- [ ] Add/complete Widgetbook stories for the shared conversation states.

## 6. Server controls — implementation complete; verification remains

Related: MVP-23, MVP-24, MVP-25, MVP-26

- [x] Define the supported five-operation contract: restart PocketCoder,
      update PocketCoder, restart NixOS, update NixOS, and save backup.
- [ ] Add backend operation/status endpoints for controls that require the
      deployed PocketCoder server.
- [x] Complete the reviewed typed root-SSH command mapping in
      `client/packages/pocketcoder_flutter/lib/infrastructure/os_control/`; no
      arbitrary shell execution is exposed.
- [ ] Add a backup API/status path around the existing backup/restore scripts.
- [x] Add the shared `ServerControlCubit`, service, and terminal-styled view
      with explicit confirmation for disruptive operations.
- [x] Reuse Aeroform's existing secure-storage credential provider in Pro:
      `client/packages/pocketcoder_pro/lib/infrastructure/pocketcoder_update/aeroform_root_ssh_credentials_provider.dart`.
- [x] Replace the update-only service/screen with the unified
      `SshServerControlService` and `ServerControlScreen`.
- [ ] Add unit tests for command mapping, authorization, status, and failures.
- [ ] Add integration tests against a disposable deployment.
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
- [ ] Add integration tests against the memory container.
- [ ] Add live verification that memory persists and can be retrieved.

## 8. Integration and live evidence sweep

Run this only after the code gaps above have landed:

- [ ] Run the release-manager Docker integration harness.
- [ ] Run API-flow Bats against the Compose stack.
- [ ] Run generated OpenAPI/PocketBase contract checks and verify a clean diff.
- [ ] Run the full Widgetbook/story generation check, including deployment.
- [ ] Run deployed PocketBase health, compatibility, and release-status checks.
- [ ] Run real harness authentication and one real harness request.
- [ ] Run one live MCP tool flow.
- [ ] Run live memory persistence/retrieval.
- [ ] Run the control-plane integration/live checks that are safe to repeat.

## Definition of ready for E2E

- [ ] Every code path above has a code audit record with `P/B/F` references.
- [ ] Every applicable unit/widget test is green.
- [ ] Every applicable integration test is green.
- [ ] Every applicable live test is green or explicitly marked not applicable.
- [ ] Only then begin the real iOS/Android Flutter E2E pass.
