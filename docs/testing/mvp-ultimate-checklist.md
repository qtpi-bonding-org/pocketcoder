# PocketCoder MVP — Ultimate Launch Checklist

This is the final gate for the MVP. It is intentionally divided into three
systems and five levels of confidence.

An item is MVP-complete only when every applicable level is checked:

1. **MVP feature check** — the user-facing behavior exists and is usable.
2. **Code inspection/audit** — the implementation follows the architecture,
   security, ownership, UI, and Cubit/adapters rules.
3. **Automated tests green** — relevant unit, widget, integration, contract,
   and CI tests pass.
4. **Live test** — the feature is exercised against real external
   infrastructure, when applicable.
5. **E2E test** — the real Flutter app drives the complete user journey,
   rather than only a Dart/service harness.

Use `—` for a genuinely non-applicable level. Do not use `—` to avoid a test
that is merely inconvenient.

## Evidence convention

Every checked item should be traceable without relying on the memory of the
agent who checked it. Record evidence using repository-relative paths and
stable symbols or test names, not line numbers alone:

`path/to/file.dart :: SymbolName`
`path/to/test.dart :: test name`

For each checked item, the audit note should include:

- **Evidence:** the implementation file/symbol and the relevant test or live
  test script.
- **Commit:** the commit inspected or tested.
- **Date:** when the evidence was checked.
- **Scope:** what was verified and what was deliberately not verified.

Line numbers may be added as a convenience, but they are not the identity of
the evidence because they change frequently. If an item is not implemented,
record the missing symbol or expected path in the evidence log rather than
checking it off. A later agent can then inspect the same locations and update
the item without starting from a blank search.

## Repository boundaries

This audit covers two repositories. The public/core repository is this one:
`/Users/aicoder/Documents/pocketcoder`. The proprietary application and Pro
deployment orchestration are in the sibling repository:
`/Users/aicoder/Documents/pocketcoder-pro`.

Use these path prefixes when reading the matrix:

- `CORE:` means a path under `/Users/aicoder/Documents/pocketcoder`.
- `PRO:` means a path under `/Users/aicoder/Documents/pocketcoder-pro`.

The shared `pocketcoder_flutter` package, server, workers, and public deploy
code remain Core/FOSS. Pro owns the app assembly, RevenueCat billing, Aeroform
deployment orchestration, deployment onboarding/review/progress presentation,
and proprietary app wiring. A Pro implementation is evidence that the feature
exists in the intended product boundary; it is not evidence that the public
Core package should contain that implementation. Integration and E2E status
still require their own evidence.

## What PocketCoder offers in the MVP

This is the product-level checklist, written in user language. It deliberately
does not classify features as provisioning, backend, or frontend yet. Each item
will later be broken down across those three areas and then evaluated using the
five confidence levels above.

- [ ] **A private PocketCoder server:** create a personal server that belongs
      to the user and is reachable from the PocketCoder app.
- [ ] **Guided setup:** choose the server resources and region, choose coding
      tools, and see what will be created before confirming.
- [ ] **Poco as a coding companion:** ask Poco what to do and receive clear,
      terminal-style explanations while work is being prepared or performed.
- [ ] **Coding agents and harnesses:** connect supported coding tools through
      an API key or account login and use them to work on the user's code.
- [ ] **Visible agent work:** see the commands, tool calls, output, approvals,
      and results instead of receiving an opaque success message.
- [ ] **Projects and files:** inspect, read, edit, and test code in the user's
      PocketCoder workspace.
- [ ] **Tools and integrations:** use configured MCP tools with clear
      permissions and approval boundaries.
- [ ] **Pocket Memory:** allow PocketCoder to retain useful observations and
      interpretations, then retrieve them as context later.
- [ ] **Ongoing chat work:** see whether Poco's current turn is active, waiting
      for approval, completed, or failed. The status appears inside the same
      chat transcript; there is no separate work object.
- [ ] **Server controls:** understand the state of the PocketCoder server and
      perform the supported restart, update, and backup actions safely.
- [ ] **A safe paid path:** understand what PocketCoder Pro unlocks, use the
      trial where offered, and retain user data if access expires.
- [ ] **A self-hosted/FOSS path:** users who do not use PocketCoder Pro can
      build and operate the open-source client and their own deployment.

## Atomic UX feature checklist

Each item below is a user-visible promise. The child checkboxes are the
implementation responsibilities needed to make that promise real. The
verification tiers are recorded in the three system sections below; a checked
implementation child does not by itself complete the user-facing promise.

## Atomic code-path and level matrix

This is the re-audit index for another agent. `CORE:` and `PRO:` identify the
repository root; the remainder of each path is repository-relative.
`MISSING` means the expected implementation was not found during the
2026-08-14 audit. `P`, `B`, and `F` mean Provision/Deploy, Backend, and
Frontend. Level status is ordered as code audit / unit or widget / integration
/ live / E2E. `—` means not applicable; `open` means not yet evidenced.
For readability, `lib/...` in this table means
`client/packages/pocketcoder_flutter/lib/...`.
Each row is also an atomic evidence record: `E-MVP-01` through `E-MVP-28`
correspond to the matching MVP ID. Re-auditors should attach test names,
commit SHAs, and live-run links to that row before advancing its level.

| ID | P / Deploy path | Backend path | Frontend path | Level status before E2E |
|---|---|---|---|---|
| MVP-01 | `deploy/nixos/bootstrap.sh`, `deploy/nixos/status.sh` | `server/pocketbase/internal/api/release_status.go` | `lib/application/system/status_cubit.dart`, `lib/presentation/boot/` | partial / partial / open / pass via live deploy / open |
| MVP-02 | `deploy/nixos/bootstrap.sh`, `deploy/release-manager/` | `server/pocketbase/internal/api/release_status.go` | `lib/presentation/deployment/`, `lib/presentation/onboarding/` | pass / pass / open / pass / open |
| MVP-03 | `deploy/nixos/caddy.nix`, `deploy/nixos/bootstrap.sh` | `server/pocketbase/internal/api/`, auth routes | `lib/application/system/auth_cubit.dart`, `lib/presentation/onboarding/adapters/onboarding_login_adapter.dart` | pass / pass / open / open / open |
| MVP-04 | `CORE:deploy/release/deployment-sizing.json`, `CORE:deploy/nixos/`; `PRO:client/packages/pocketcoder_pro/lib/presentation/deployment/adapters/config_adapter.dart` | `CORE:server/pocketbase/internal/api/` validation boundaries | `PRO:client/packages/pocketcoder_pro/lib/presentation/deployment/widgets/config_view.dart`, `PRO:client/packages/pocketcoder_pro/lib/application/config/config_cubit.dart` | pass / pass / open / pass via live provision / open |
| MVP-05 | `PRO:client/packages/pocketcoder_pro/lib/presentation/deployment/adapters/details_adapter.dart` | `CORE:server/pocketbase/internal/api/` validation boundaries | `PRO:client/packages/pocketcoder_pro/lib/presentation/deployment/details_screen.dart`, `PRO:client/packages/pocketcoder_pro/lib/presentation/deployment/widgets/details_view.dart` | pass / pass / open / open / open |
| MVP-06 | `PRO:client/packages/pocketcoder_pro/lib/application/config/config_cubit.dart` | `CORE:server/pocketbase/internal/api/` error/state responses | `PRO:client/packages/pocketcoder_pro/lib/presentation/deployment/adapters/config_adapter.dart`, `PRO:client/packages/pocketcoder_pro/lib/presentation/onboarding/pro_onboarding_setup_flow.dart` | pass / pass / open / open / open |
| MVP-07 | `PRO:client/packages/pocketcoder_pro/lib/application/deployment/deployment_cubit.dart` | `CORE:server/pocketbase/internal/agent/pocoprompt/`, `CORE:server/pocketbase/internal/api/agent.go` | `PRO:client/packages/pocketcoder_pro/lib/presentation/deployment/widgets/walkthrough_panel.dart`, `CORE:client/packages/pocketcoder_flutter/lib/application/system/poco_cubit.dart` | pass / pass / open / open / open |
| MVP-08 | `PRO:client/packages/pocketcoder_pro/lib/application/deployment/deployment_cubit.dart` | `CORE:server/pocketbase/internal/agent/agui/`, `CORE:server/pocketbase/internal/agent/coordinator/` | `PRO:client/packages/pocketcoder_pro/lib/application/walkthrough/walkthrough_cubit.dart`, `PRO:client/packages/pocketcoder_pro/lib/presentation/deployment/widgets/walkthrough_conversation_view.dart` | pass / pass / open / open / open |
| MVP-09 | `deploy/release/harnesses.json`, `deploy/scripts/discover-release-harnesses.sh` | `server/pocketbase/internal/harnessaccount/`, `internal/hooks/harness_provision.go` | `lib/application/provider/provider_cubit.dart`, `lib/presentation/onboarding/harness_choice*` | pass / pass / open / open / open |
| MVP-10 | harness image/runtime configuration in `deploy/release/` | `server/pocketbase/internal/harnessauth/`, `internal/api/harness_auth.go` | `lib/application/harness_auth/`, `lib/presentation/harness_auth/` | pass / pass / open / open / open |
| MVP-11 | harness runtime in `deploy/release/harnesses.json` | `server/pocketbase/internal/agent/coordinator/`, `internal/api/agent.go` | `lib/application/agent/chat_cubit.dart`, `lib/presentation/chat/adapters/chat_adapter.dart` | pass / pass / open / open / open |
| MVP-12 | runtime/logging support in `deploy/` | `server/pocketbase/internal/agent/agui/`, `internal/agent/executor/` | `lib/presentation/chat/widgets/terminal_command_card.dart`, `pocketcoder_chat_builders.dart` | pass / pass / open / open / open |
| MVP-13 | — | `server/pocketbase/internal/api/logs.go`, agent event output | `lib/presentation/chat/widgets/terminal_command_card.dart` | pass / pass / open / open / open |
| MVP-14 | — | `server/pocketbase/internal/agent/coordinator/`, permission API | `lib/application/agent/permission_cubit.dart`, `lib/presentation/chat/permission_card.dart` | pass / pass / open / open / open |
| MVP-15 | workspace/runtime mounts in `deploy/` | `server/pocketbase/internal/filesystem/` | `lib/application/files/`, `lib/presentation/files/` | pass / pass / open / open / open |
| MVP-16 | test/runtime containers in `deploy/` | `server/pocketbase/internal/filesystem/`, agent executor | `lib/presentation/files/`, `lib/presentation/chat/` | pass / pass / open / open / open |
| MVP-17 | `server/mcp-gateway/`, `deploy/` stack configuration | `server/pocketbase/internal/mcpserver/`, `internal/api/mcp.go` | `lib/application/mcp/`, `lib/presentation/mcp/` | pass / pass / open / open / open |
| MVP-18 | — | `server/pocketbase/internal/api/mcp_oauth.go`, permission boundaries | `lib/application/tool_permissions/`, `lib/presentation/tool_permissions/` | pass / pass / open / open / open |
| MVP-19 | `CORE:server/memory/Dockerfile`, persistent volume in compose | `CORE:server/memory/src/db/links.rs`, `CORE:server/memory/src/service.rs` | `CORE:server/memory/src/mcp/tools.rs` (retention remains agent-driven; dashboard is read-only) | partial / pass / open / open / open |
| MVP-20 | `CORE:server/memory/` runtime | `CORE:server/memory/src/search/`, `CORE:server/memory/src/mcp/tools.rs` | `CORE:server/sqlpage/dashboard/memory.sql`, `CORE:client/packages/pocketcoder_flutter/lib/presentation/observability/memory_dashboard_screen.dart` | pass / pass / open / open / open |
| MVP-21 | `deploy/nixos/status.sh`, release manager progress | `server/pocketbase/internal/agent/agui/`, release status API | `lib/application/agent/chat_state.dart`, `lib/presentation/chat/` | pass / pass / open / open / open |
| MVP-22 | runtime persistence/volumes in `deploy/` | `server/pocketbase/internal/agent/coordinator/`, chat API | `lib/application/agent/chat_cubit.dart`, `lib/presentation/chat/` | pass / pass / open / open / open |
| MVP-23 | `CORE:client/packages/pocketcoder_flutter/lib/domain/os_control/`, `CORE:client/packages/pocketcoder_flutter/lib/infrastructure/os_control/` | `OPEN: no deployed restart operation endpoint; Pro uses owner root SSH` | `CORE:client/packages/pocketcoder_flutter/lib/application/server_control/`, `CORE:client/packages/pocketcoder_flutter/lib/presentation/server_control/` | pass / partial / open / open / open |
| MVP-24 | `CORE:deploy/release-manager/`, `CORE:deploy/scripts/update-release.sh` | release/update API status | `CORE:client/packages/pocketcoder_flutter/lib/application/server_control/`, `PRO:client/packages/pocketcoder_pro/lib/app.dart` | pass / partial / open / open / open |
| MVP-25 | `CORE:deploy/nixos/` OS update/restart scripts | `OPEN: no separate NixOS control endpoint; Pro uses owner root SSH` | `CORE:client/packages/pocketcoder_flutter/lib/presentation/server_control/`, `PRO:client/packages/pocketcoder_pro/lib/infrastructure/pocketcoder_update/aeroform_root_ssh_credentials_provider.dart` | pass / partial / open / open / open |
| MVP-26 | `CORE:server/pocketbase/backup_db.sh`, restore script | `OPEN: no backup API/status contract found` | `CORE:client/packages/pocketcoder_flutter/lib/presentation/server_control/` | pass / partial / open / open / open |
| MVP-27 | `PRO:client/packages/pocketcoder_pro/lib/app.dart` RevenueCat entitlement wiring | `CORE:workers/push-relay/` entitlement boundary | `PRO:client/packages/pocketcoder_pro/lib/infrastructure/billing/revenue_cat_package_mapper.dart`, `PRO:client/apps/pocketcoder/lib/main.dart` | pass / pass / open / optional live / open |
| MVP-28 | public `deploy/` scripts and NixOS path | public PocketCoder server/API | `client/apps/pocketcoder_foss/` | pass / pass / open / — / open |

The matrix is intentionally stricter than the broad section summary. For
example, having `TerminalConversationTurn` in the repository does not mark
MVP-07 or MVP-12 complete until the real and guided adapters use it; having a
backup shell script does not mark MVP-26 complete without an API and Flutter
control path.

### A private PocketCoder server

#### MVP-01 — See whether a server already exists

- [ ] **Provision / Deploy:** the provider/deployment status can identify the
      user's existing server.
- [ ] **Backend:** the user's server identity and status are returned through a
      protected API.
- [ ] **Frontend:** Flutter displays whether the server is ready, provisioning,
      offline, or unavailable.

#### MVP-02 — Create a personal server

- [ ] **Provision / Deploy:** Aeroform creates the user's NixOS server and
      installs the verified PocketCoder release.
- [ ] **Backend:** the deployed server initializes its identity and health
      endpoints for that user.
- [ ] **Frontend:** the user can start creation with one clear deploy action.

#### MVP-03 — Enter the server without manual setup

- [ ] **Provision / Deploy:** HTTPS is configured and the deployed endpoint is
      reachable.
- [ ] **Backend:** the endpoint reports compatible release and authentication
      state.
- [ ] **Frontend:** Flutter saves the connection and opens PocketCoder without
      copied URLs, SSH, or manually entered tokens.

### Guided setup

#### MVP-04 — Choose the deployment configuration

- [ ] **Provision / Deploy:** the selected size, region, OS, and harnesses are
      passed to the deployment system.
- [ ] **Backend:** unsafe or incomplete configurations are rejected.
- [ ] **Frontend:** the user can make each required selection and understand
      what is selected.

#### MVP-05 — Review before spending money

- [ ] **Provision / Deploy:** the final configuration can be resolved into an
      actionable provider request.
- [ ] **Frontend:** the review screen summarizes the server, region, tools,
      and expected cost before confirmation.

#### MVP-06 — Go back without losing choices

- [ ] **Provision / Deploy:** previously selected deployment values remain
      valid when the flow returns to an earlier step.
- [ ] **Frontend:** back navigation preserves completed choices and does not
      reset the onboarding flow unexpectedly.

### Poco as a coding companion

#### MVP-07 — Explain what is happening

- [ ] **Provision / Deploy:** onboarding and deployment state can provide Poco
      with the current context.
- [ ] **Backend:** Poco messages are stored and delivered in the conversation.
- [ ] **Frontend:** Poco explains the current step in the shared terminal-style
      chat.

#### MVP-08 — Show the current assistant-turn state

- [ ] **Backend:** the current Poco turn can be active, waiting for approval or
      input, complete, or failed.
- [ ] **Frontend:** that state appears inside the current Poco turn; there is
      no separate task screen or work object.

### Coding agents and harnesses

#### MVP-09 — See and choose available harnesses

- [ ] **Provision / Deploy:** selected harness images and runtime configuration
      are installed on the user's server.
- [ ] **Backend:** the deployment reports the available harnesses and their
      connection state.
- [ ] **Frontend:** the user can see and choose a supported harness.

#### MVP-10 — Connect a harness

- [ ] **Backend:** API-key and supported account/device authentication flows
      persist connection state safely.
- [ ] **Frontend:** the user sees disconnected, connecting, connected, expired,
      and failed states with a clear reconnect path.

#### MVP-11 — Send a request to a harness

- [ ] **Backend:** the request is associated with the conversation and routed
      to the selected harness.
- [ ] **Frontend:** the user can send a request and see which harness is being
      used.

### Visible agent work

#### MVP-12 — See commands and tool activity

- [ ] **Backend:** commands, tool calls, approvals, output, and results are
      streamed or persisted in the current assistant turn.
- [ ] **Frontend:** the user sees terminal-style activity instead of an opaque
      success message.

#### MVP-13 — Expand long output when needed

- [ ] **Backend:** output is delivered without truncating the useful result.
- [ ] **Frontend:** long command output is hidden by default and expandable.

#### MVP-14 — Approve or deny an action

- [ ] **Backend:** approval-required actions pause safely until a decision is
      received.
- [ ] **Frontend:** the user can approve or deny the specific action in chat.

### Projects and files

#### MVP-15 — Work in the user's project workspace

- [ ] **Provision / Deploy:** the user's workspace is mounted and available to
      the selected harnesses.
- [ ] **Backend:** file operations are scoped to the user's workspace.
- [ ] **Frontend:** the user can see which project/workspace the conversation
      is using.

#### MVP-16 — Read, edit, and test code

- [ ] **Backend:** supported file read, edit, and test operations are exposed
      through authenticated APIs/tools.
- [ ] **Frontend:** the user can see the resulting files, commands, and test
      output in the conversation.

### Tools and integrations

#### MVP-17 — Use configured MCP tools

- [ ] **Provision / Deploy:** the MCP gateway and selected tool runtimes are
      available in the deployment.
- [ ] **Backend:** MCP operations are routed and authorized for the user.
- [ ] **Frontend:** the user can invoke a configured tool and see its result.

#### MVP-18 — Approve tool actions

- [ ] **Backend:** approval decisions are enforced and credentials are not
      exposed.
- [ ] **Frontend:** the user can approve or deny an individual tool action.

### Pocket Memory

#### MVP-19 — Remember useful context

- [ ] **Provision / Deploy:** the memory service starts with persistent storage.
- [ ] **Backend:** observations, interpretations, and their many-to-many links
      can be stored.
- [ ] **Frontend:** the conversation can cause useful context to be retained.

#### MVP-20 — Retrieve remembered context

- [ ] **Backend:** related memory can be listed, searched, and retrieved for a
      conversation.
- [x] **Frontend:** the existing authenticated SQLPage dashboard makes stored
      observations, interpretations, links, and interpretation details
      inspectable; response-context behavior remains agent/MCP-owned.

### Ongoing chat work

#### MVP-21 — Know whether Poco is still working

- [ ] **Backend:** the current assistant turn reports active, waiting for
      approval/input, complete, or failed.
- [ ] **Frontend:** the current turn shows the corresponding state without
      introducing task terminology.

#### MVP-22 — Keep the completed response in chat

- [ ] **Backend:** the assistant turn's commands, output, response, and final
      state remain available after the harness finishes.
- [ ] **Frontend:** reopening the conversation shows the completed turn.

### Server controls

#### MVP-23 — Restart PocketCoder

- [ ] **Provision / Deploy:** the deployed server exposes a safe PocketCoder
      restart operation.
- [ ] **Backend:** the operation is authorized, serialized, and reported.
- [ ] **Frontend:** the user confirms the interruption and sees the result.

#### MVP-24 — Update PocketCoder

- [ ] **Provision / Deploy:** a verified PocketCoder release can be installed
      and activated safely.
- [ ] **Backend:** the update operation reports progress/result and preserves
      user data.
- [ ] **Frontend:** the user sees what will change and whether rollback applies.

#### MVP-25 — Restart or update the NixOS console

- [ ] **Provision / Deploy:** the OS exposes the supported restart/update path.
- [ ] **Backend:** the operation is authorized and reports connection loss and
      recovery correctly.
- [ ] **Frontend:** the user receives a clear warning before disruption.

#### MVP-26 — Back up the user's save

- [ ] **Provision / Deploy:** a verified recoverable backup can be created.
- [ ] **Backend:** backup state and failure are reported without losing data.
- [ ] **Frontend:** the user can start a backup and see its result.

### A safe paid path

#### MVP-27 — Understand and use PocketCoder Pro

- [ ] **Provision / Deploy:** hosted provisioning is gated by the correct
      entitlement.
- [ ] **Backend:** entitlement state is verified and data remains accessible
      after expiry.
- [ ] **Frontend:** the trial, store-provided price, purchase, restore, expiry,
      and locked actions are clear.

### A self-hosted/FOSS path

#### MVP-28 — Build and operate PocketCoder without Pro

- [ ] **Provision / Deploy:** public scripts and documentation support the
      promised self-hosted path.
- [ ] **Backend:** the core server/API contract works without Pro-only central
      services where promised.
- [ ] **Frontend:** the FOSS client builds without proprietary dependencies and
      can be configured for a self-hosted endpoint.

## Implementation ownership reference

Each offer is split into the work required in the deployment, backend, and
frontend. A `—` means that layer does not own a meaningful part of the offer.
This is a reference map, not a second set of completion gates; the numbered
atomic checklist and the three system sections are authoritative.

### A private PocketCoder server

- **Provision / Deploy:** create the user's NixOS server, install the verified
  PocketCoder release, configure HTTPS, and return a usable endpoint.
- **Backend:** expose authenticated health, compatibility, release status, and
  deployment identity for that user's server.
- **Frontend:** guide creation, show deployment state, save the connection, and
  open the deployed PocketCoder experience.

### Guided setup

- **Provision / Deploy:** accept provider credentials, server size, region,
  harness choices, and the final deployment configuration.
- **Backend:** validate the submitted configuration and create the correct
  provider/deployment request without accepting unsafe combinations.
- **Frontend:** present the setup choices, review screen, confirmation, back
  navigation, and clear validation errors.

### Poco as a coding companion

- **Provision / Deploy:** provide the initial deployment/onboarding context
  Poco needs to explain what is happening.
- **Backend:** persist and stream Poco's messages and associate tool activity
  with the current assistant turn.
- **Frontend:** render Poco's explanations in the shared terminal-style chat,
  including the active turn's status without creating a separate work object.

### Coding agents and harnesses

- **Provision / Deploy:** install and configure the selected harness images and
  their required runtime configuration.
- **Backend:** own harness accounts, credentials, connection state, agent
  selection, and execution requests for the user's deployment.
- **Frontend:** show available harnesses, connect/reconnect states, selection,
  and clear account/API-key authentication flows.

### Visible agent work

- **Provision / Deploy:** provide the runtime and logging path that can expose
  commands, tool calls, approvals, output, and results.
- **Backend:** stream and persist the current assistant turn's commands,
  tool activity, approval requests, output, and final response.
- **Frontend:** show terminal-style activity, expandable output, approval
  controls, and working/waiting/done/failed state inside the chat.

### Projects and files

- **Provision / Deploy:** mount and initialize the user's workspace in the
  deployed runtime.
- **Backend:** enforce workspace ownership and provide file read, list, edit,
  and test operations through the supported API.
- **Frontend:** let the user inspect files, see agent results, and understand
  which workspace the conversation is using.

### Tools and integrations

- **Provision / Deploy:** include and configure the MCP gateway and selected
  tool runtimes in the user's deployment.
- **Backend:** route MCP operations, enforce permissions, and persist approval
  decisions without exposing credentials.
- **Frontend:** show configured tools, approval requests, results, and failure
  states without requiring an access-policy tutorial for every integration.

### Pocket Memory

- **Provision / Deploy:** start the memory service with the deployment and
  provide its persistent storage.
- **Backend:** store observations, interpretations, and many-to-many links;
  retrieve related memory for a conversation; support list and search.
- **Frontend:** use relevant memory as context and make it inspectable when
  that context materially affects the conversation.

### Ongoing chat work

- **Provision / Deploy:** keep the deployed runtime reachable while Poco is
  working and support reconnecting after temporary app/network loss.
- **Backend:** track the current assistant turn as active, waiting for
  approval/input, done, or failed, and preserve its result in chat history.
- **Frontend:** show that state inside the current Poco turn; do not create a
  separate task screen, task list, or task terminology.

### Server controls

- **Provision / Deploy:** expose safe operations for restarting PocketCoder,
  updating PocketCoder, restarting the NixOS console, updating NixOS, and
  creating a verified backup.
- **Backend:** authorize, serialize, execute, and report those operations while
  preserving user data and explaining rollback limitations.
- **Frontend:** show current server state, confirmation for disruptive actions,
  operation status, result, and recovery guidance.

### A safe paid path

- **Provision / Deploy:** enforce the Pro requirement for hosted provisioning
  and leave the user's deployed data intact if entitlement expires.
- **Backend:** verify entitlement where required and keep data accessible even
  when Pro-only actions are unavailable.
- **Frontend:** show the trial, store-provided price, purchase/restore state,
  expiry behavior, and exactly which actions are locked.

### A self-hosted/FOSS path

- **Provision / Deploy:** provide public scripts and documentation so a user
  can operate the supported open-source deployment themselves.
- **Backend:** keep the core PocketCoder server and APIs usable without Pro-only
  central services where the FOSS contract promises that support.
- **Frontend:** build a FOSS client without proprietary dependencies and make
  its self-hosted configuration understandable.

## 1. Provision + Deploy

The user can go from the Flutter app to a working PocketCoder deployment on a
real NixOS VPS.

**Feature refs:** MVP-01–MVP-08, MVP-21, MVP-23–MVP-27.

### Provisioning and deployment flow

**Feature refs:** MVP-01–MVP-06.

- [ ] MVP feature check: credentials, provider authorization, server size,
      region, harness selection, OS choice, review, and deploy flow are
      coherent.
- [ ] MVP feature check: provisioning shows the current deployment state,
      including failures and retry/abort behavior.
- [ ] MVP feature check: the deployed PocketCoder endpoint is reachable over
      HTTPS and the app can connect to it.
- [x] Code inspection/audit: Flutter calls Aeroform through the adapter/Cubit *(E-PROV-ADAPTER)*
      flow; there is no hidden SSH path or duplicated provisioning logic.
- [x] Code inspection/audit: NixOS release identity, attestation, artifact *(E-RELEASE-VERIFY)*
      digest, channel, and sequence are verified before activation.
- [x] Code inspection/audit: secrets are injected through the approved secret *(E-SECRETS)*
      path and never committed, logged, or embedded in the app.
- [x] Unit tests: release-manager Go tests and focused provisioning/deployment *(E-RM-UNIT)*
      unit tests are green.
- [ ] Integration tests: release schemas/contracts, Docker integration, and
      Flutter deployment integration tests are green.
- [x] Live test: real NixOS provision + deployment completed successfully. *(E-LIVE-PROVISION)*
- [x] Live test: installed release manager updated the same VPS from nightly *(E-LIVE-UPGRADE)*
      sequence 8 to 9 and passed health checks.
- [ ] E2E test: a real Flutter iOS/Android app performs credentials through
      successful deployment against the live service.
- [ ] E2E test: the app displays the real deployment result and can enter the
      deployed chat without manual URL or state injection.

### Deployment failure and recovery

**Feature refs:** MVP-06, MVP-21, MVP-23–MVP-27.

- [ ] MVP feature check: failed provisioning/deployment gives a useful Poco
      explanation and an actionable retry/abort path.
- [x] Code inspection/audit: partial resources and temporary test resources *(E-CLEANUP)*
      are cleaned up safely; no broad Docker or VPS cleanup is performed.
- [ ] Unit tests: bootstrap, health, artifact, revocation, and update failure
      handling tests are green.
- [ ] Integration tests: failure and recovery flows run through the deployment
      stack and release manager.
- [x] Live test: candidate publication, promotion, activation, and health *(E-LIVE-CANDIDATE)*
      verification completed on a real VPS.
- [ ] E2E test: the user can see and recover from a real failed deployment in
      the Flutter UI.

## 2. PocketCoder Backend

PocketBase, the harness runtimes, MCP gateway, memory, notifications, and the
versioned API behave correctly for one user's deployment.

**Feature refs:** MVP-09–MVP-22.

### PocketBase and API

**Feature refs:** MVP-01, MVP-03, MVP-15, MVP-16, MVP-21, MVP-22.

- [ ] MVP feature check: authentication, ownership, roles, chats, files,
      provider keys, harness accounts, schedules, and settings work for the
      intended user flows.
- [x] Code inspection/audit: PocketBase owns its record IDs; external IDs are *(E-PB-OWNERSHIP)*
      stored as fields; collection rules enforce per-user ownership.
- [x] Code inspection/audit: API boundaries use the current versioned routes, *(E-API-BOUNDARY)*
      generated contracts, and explicit dependency/runtime interfaces.
- [x] Unit tests: Go package tests and API boundary tests are green. *(E-PB-UNIT)*
- [ ] Integration tests: generated-contract, schema/model generation, and
      API-flow Bats tests are green.
- [ ] Live test: a provisioned deployment exposes healthy PocketBase APIs over
      HTTPS and reports the expected compatibility/release status.
- [ ] E2E test: the Flutter app authenticates and completes the core user
      actions against a real deployed PocketBase.

### Harness authentication and execution

**Feature refs:** MVP-09–MVP-11, MVP-21, MVP-22.

- [ ] MVP feature check: harnesses can be selected, connected, inspected, and
      used from the app.
- [ ] MVP feature check: API-key and no-credential paths work; account/device
      login has a clear user-facing state flow.
- [ ] MVP feature check: the agent turn has a durable result and remains in
      the conversation after the harness finishes.
- [x] Code inspection/audit: harness state transitions, challenge parsing, *(E-HARNESS-AUDIT)*
      log scrubbing, ownership, and attempt lifecycle are isolated behind the
      runtime interfaces.
- [x] Unit tests: focused `harnessauth` parser and harness runtime tests are *(E-HARNESS-UNIT)*
      green.
- [ ] Integration tests: API-flow Bats and auth-helper/container integration
      tests are green.
- [ ] Live test: real account/device-code authentication succeeds against the
      auth-helper container/provider.
- [ ] E2E test: a real Flutter user connects a harness and sends one real
      request through the conversation.

### MCP gateway and tools

**Feature refs:** MVP-17, MVP-18.

- [ ] MVP feature check: MCP servers/tools can be configured and used through
      the intended PocketCoder flow.
- [x] Code inspection/audit: gateway access is scoped to the deployment/user; *(E-MCP-AUDIT)*
      authorization and approval boundaries are explicit.
- [x] Unit tests: MCP API, permission, and tool authorization tests are green. *(E-MCP-UNIT)*
- [ ] Integration tests: OAuth, gateway, and end-to-end tool-flow tests are
      green.
- [ ] Live test: a real provisioned gateway reaches the selected MCP service
      and returns a valid response.
- [ ] E2E test: the Flutter app configures or invokes one MCP flow against the
      live deployment.

### Pocket Memory

**Feature refs:** MVP-19, MVP-20.

- [ ] MVP feature check: observations, interpretations, links, list/search,
      and retrieval work through the supported internal interface.
- [x] Read-only inspection surface: SQLPage's `memory.sql` dashboard is served
      through PocketBase's authenticated observability proxy; the Flutter app
      opens it in an authenticated WebView.
- [x] Code inspection/audit: many-to-many observation/interpretation links *(E-MEMORY-AUDIT)*
      remain the source of truth; interpretations cannot be detached from all
      observations; primitive storage operations are not exposed as MCP tools.
- [x] Unit tests: memory linkage, search, and persistence unit tests are green. *(E-MEMORY-UNIT)*
- [ ] Integration tests: memory container and deployed-stack integration tests
      are green.
- [ ] Live test: the memory service starts with the deployed stack and can
      persist and retrieve a test record.
- [ ] E2E test: a real chat flow stores and retrieves memory through the
      Flutter experience.

### Backend reliability and data safety

**Feature refs:** MVP-21–MVP-27.

- [ ] MVP feature check: health, release compatibility, metadata status,
      notifications, backups, and error responses are understandable.
- [x] Code inspection/audit: migrations, data-version boundaries, rollback *(E-ROLLBACK-AUDIT)*
      behavior, and release revocation rules are explicit.
- [ ] Unit tests: migration, rollback-boundary, authorization, status,
      notification, and failure-path tests are green.
- [ ] Integration tests: deployed health, release status, backup, and recovery
      flows are green.
- [ ] Live test: deployed health/status endpoints and release metadata agree
      with the active release.
- [ ] E2E test: the Flutter app surfaces a backend outage or incompatible
      release without a red error screen of death.

## 3. PocketCoder Frontend

The real Flutter app is coherent, usable, and connected to the backend without
test-only shortcuts.

**Feature refs:** MVP-04–MVP-08, MVP-12–MVP-16, MVP-21, MVP-27, MVP-28.

### Onboarding and deployment UI

**Feature refs:** MVP-01–MVP-08, MVP-21, MVP-23–MVP-27.

- [ ] MVP feature check: onboarding order is coherent from credentials through
      Poco explanation, Pro access, provider authorization, sizing, region,
      harnesses, OS, review, and deployment.
- [ ] MVP feature check: provisioning/deployment progress, current step,
      error, retry, abort, and completion states are understandable on mobile.
- [x] Code inspection/audit: screens use shared widgets, theme tokens, design *(E-FLUTTER-AUDIT)*
      system sizes, l10n, and Cubit UI-flow adapters; no inline duplicate UI
      implementation remains.
- [x] Unit/widget tests: Flutter analysis, widget tests, and Cubit/adapter *(E-FLUTTER-UNIT)*
      tests are green.
- [ ] Integration tests: generated contract checks and Widgetbook stories are
      green.
- [x] Live test: — (covered by the Provision + Deploy live test). *(E-FLUTTER-LIVE)*
- [ ] E2E test: real iOS and Android Flutter builds complete onboarding and
      deployment against the live service.

### Chat and Poco experience

**Feature refs:** MVP-07–MVP-22.

- [ ] MVP feature check: Poco explanation, one current message per step,
      chat history, FAQ chips, snippets, terminal commands, expandable output,
-      agent-turn status entries, and `$` / `>` composer behavior are coherent.
- [ ] MVP feature check: walkthroughs and briefs continue as bounded terminal
      sessions without confusing page transitions.
- [ ] Code inspection/audit: real chat and onboarding conversation reuse the
      same widgets while keeping separate state/adapters; no fake backend state
      leaks into live chat.
- [x] Unit/widget tests: chat, snippet, agent-turn status entry, composer, *(E-CHAT-UNIT)*
      transition, long-message, and narrow-layout tests are green.
- [ ] Integration tests: live-chat adapters and shared onboarding/chat widget
      flows are green, including Widgetbook coverage.
- [x] Live test: — (the backend/live deployment is covered in section 1 and 2). *(E-CHAT-LIVE)*
- [ ] E2E test: a real user sends a prompt, receives Poco/harness output, sees
      a command/tool state, and can continue the conversation.

### App reliability, distribution, and billing

**Feature refs:** MVP-27, MVP-28.

- [ ] MVP feature check: auth, Pro entitlement/paywall, connect/deploy actions,
      settings, errors, back navigation, and session recovery work on mobile.
- [x] Code inspection/audit: Pro and FOSS boundaries, RevenueCat configuration, *(E-BILLING-AUDIT)*
      platform-specific secrets, l10n, and generated files are correct.
- [x] Unit/widget tests: Flutter tests and paywall/entitlement tests are green. *(E-BILLING-UNIT)*
- [ ] Integration/build tests: iOS/Android compile checks, FOSS purity, and
      OpenAPI/generated contract checks are green.
- [ ] Live test: — unless testing App Store/Play services or RevenueCat
      production/sandbox behavior.
- [ ] E2E test: installable iOS and Android builds complete the core free/trial
      and Pro-gated flows on simulators or physical devices.

## Final release decision

- [ ] All applicable MVP feature checks pass.
- [ ] All three sections have completed code inspection/audit.
- [ ] Required local and CI tests are green on the `staging → main` PR.
- [ ] Applicable live tests pass, including the real NixOS provision/deploy and
      upgrade test.
- [ ] Real Flutter E2E passes on the launch platforms.
- [ ] No known blocker remains in the launch notes.

The MVP is not “done” merely because the backend live test passes. The final
release gate is the real Flutter app completing the user journey against the
real deployed backend.

## Evidence log

Checked on 2026-08-14:

- [x] `go test ./...` passes in `deploy/release-manager`.
- [x] `go test ./...` passes in `server/pocketbase`.
- [x] `go test ./...` passes in `server/harness-adapter`.
- [x] `cargo test` passes in `server/memory` (35 tests across unit,
      persistence, linkage, search, and service suites).
- [x] FOSS purity passes for `pocketcoder_flutter` and `pocketcoder_foss`.
      The four existing pending-license allowlist entries remain explicitly
      reported by the checker.
- [ ] Code-feature audit: the shared `TerminalConversationTurn` abstraction is
      now used by both guided onboarding and live chat, but the separate
      adapter/state-source integration and end-to-end proof remain open.
- [x] Pro code-feature audit: `PocketCoderProgressPane`, bounded
      walkthrough/brief state, contextual FAQ responses, shared terminal
      conversation rendering, and deployment Widgetbook stories exist in the
      sibling Pro repository. *(E-PRO-UI)* Integration/live/E2E wiring is
      still open.
- [x] Pro focused onboarding tests: walkthrough Cubit, panel, conversation,
      FAQ duplicate protection, and narrow-layout tests passed (13 tests).
      *(E-PRO-UI-TESTS)*
- [x] Code-feature audit: the unified five-operation ServerControl contract,
      reviewed root-SSH mappings, terminal UI, and Pro secure-storage wiring
      are present. Unit/widget, integration, live, and E2E verification remain
      open. *(E-PRO-CONTROLS)*
- [x] `flutter test --no-pub` passes in `client/packages/pocketcoder_flutter`
      (347 tests).
- [x] `flutter analyze --no-pub` reports no issues.
- [x] `dart test packages/pocketcoder_api` passes (43 tests).
- [x] Release schema and release contract tests pass with the pinned
      `check-jsonschema` dependency.
- [x] `git diff --check` passes.
- [ ] Docker release integration harness: blocked in this environment because
      the sandbox cannot access the Docker daemon socket; no Docker Desktop
      state was changed.
- [ ] API-flow Bats and deployed-stack integration tests: not run in this pass.
- [ ] Real Flutter iOS/Android E2E: not run; requires the user's simulator or
      device session and the live deployment.
- [x] Real NixOS provision/deploy and release-manager upgrade evidence remains
      recorded above.

### Evidence index

Checked against Core commit `58bd890236145d0fb375513bb2c4512945f491bd` and
Pro commit `7af137552f265713e98f2a186bb38e3e58fad2e1` on 2026-08-14 unless
noted otherwise:

| ID | Evidence | Scope |
|---|---|---|
| E-PROV-ADAPTER | `client/packages/pocketcoder_flutter/lib/presentation/onboarding/adapters/`; `client/packages/pocketcoder_flutter/lib/domain/deployment/` | Adapter/Cubit deployment boundary inspected; real Flutter E2E remains open. |
| E-RELEASE-VERIFY | `deploy/nixos/bootstrap.sh`; `deploy/release-manager/internal/contract/`; `deploy/release-manager/internal/manager/` | Attested release, digest, channel, sequence, and revocation paths inspected. |
| E-SECRETS | `.github/workflows/`; `deploy/nixos/bootstrap.sh`; secret injection call sites | No repository secret values found in the inspected paths; production secret rotation is outside this checklist. |
| E-RM-UNIT | `deploy/release-manager` — `go test ./...` | Release-manager unit/package tests passed. |
| E-LIVE-PROVISION | `deploy/release-manager/tests/run-live-nixos-upgrade-test.sh` and recorded live result | Real NixOS provision/deploy passed; recorded from the earlier live run. |
| E-LIVE-UPGRADE | `deploy/release-manager/tests/run-live-nixos-update-test.sh` | Real installed updater passed nightly sequence 8 → 9; recorded from the earlier live run. |
| E-CLEANUP | `deploy/release-manager/internal/transaction/`; `deploy/release-manager/internal/snapshot/` | Recovery and cleanup implementation inspected; Docker integration still needs a runnable daemon. |
| E-LIVE-CANDIDATE | live release candidate/promotion/activation result | Real candidate activation and health verification passed in the earlier live run. |
| E-PB-OWNERSHIP | `server/pocketbase/internal/api/errors.go`; `server/pocketbase/pb_migrations/schema.json`; ownership tests | PB IDs, external IDs, and owner boundaries inspected. |
| E-API-BOUNDARY | `api/openapi/pocketcoder.yaml`; `server/pocketbase/internal/api/`; `client/packages/pocketcoder_api/` | Versioned API and generated client boundary inspected. |
| E-PB-UNIT | `server/pocketbase` — `go test ./...` | PocketBase/backend Go tests passed. |
| E-HARNESS-AUDIT | `server/pocketbase/internal/harnessauth/`; `server/pocketbase/internal/harnessaccount/` | State, parsing, ownership, and lifecycle code inspected. |
| E-HARNESS-UNIT | `server/harness-adapter` and PocketBase harness tests | Harness unit tests passed; provider/device live auth remains open. |
| E-MCP-AUDIT | `server/pocketbase/internal/mcpserver/`; `server/pocketbase/internal/api/mcp.go` | MCP authorization and deployment scope inspected. |
| E-MCP-UNIT | PocketBase MCP/API tests; `server/memory` MCP contract tests | MCP unit/contract tests passed; live external MCP flow remains open. |
| E-MEMORY-AUDIT | `server/memory/src/db/links.rs`; `server/memory/src/mcp/tools.rs` | Many-to-many links and MCP exposure rules inspected. |
| E-MEMORY-UNIT | `server/memory` — `cargo test` | 35 memory tests passed. |
| E-MEMORY-UI | `server/sqlpage/dashboard/memory.sql`; `client/packages/pocketcoder_flutter/lib/presentation/observability/memory_dashboard_screen.dart` | Read-only memory inspection is available through the authenticated SQLPage dashboard; Flutter live/E2E coverage remains open. |
| E-MEMORY-PROXY | `server/pocketbase/internal/api/proxy.go :: createProxyHandler`; `server/pocketbase/internal/api/proxy_test.go :: TestMemoryDashboardIsAvailableToAuthenticatedUser` | Only `memory.sql` is available to ordinary authenticated users; other observability proxy paths remain admin-only. |
| E-ROLLBACK-AUDIT | `deploy/release-manager/internal/transaction/`; `internal/snapshot/`; `server/pocketbase/internal/api/release_status.go` | Snapshot, data-version, rollback, and release-status code inspected. |
| E-FLUTTER-AUDIT | `client/packages/pocketcoder_flutter/lib/presentation/**/adapters/`; `lib/design_system/`; `lib/l10n/` | Adapter/theme/l10n structure inspected; missing feature widgets remain open. |
| E-FLUTTER-UNIT | `client/packages/pocketcoder_flutter` — `flutter analyze --no-pub`, `flutter test --no-pub` | Analysis clean; 347 Flutter tests passed. |
| E-FLUTTER-LIVE | Provision/deploy live evidence above | No separate frontend-only live test claimed. |
| E-CHAT-UNIT | `client/packages/pocketcoder_flutter/test/presentation/chat/` | Chat/widget tests passed; shared conversation wiring remains open. |
| E-CHAT-LIVE | Backend/live evidence above | No separate chat-only live test claimed. |
| E-BILLING-AUDIT | `client/packages/pocketcoder_flutter/lib/presentation/billing/`; FOSS app boundary | Billing/FOSS code paths inspected; store E2E remains open. |
| E-BILLING-UNIT | billing/paywall Flutter tests | Paywall and entitlement tests passed. |
| E-PRO-DEPLOY | `PRO:client/packages/pocketcoder_pro/lib/application/deployment/deployment_cubit.dart`; `PRO:client/packages/pocketcoder_pro/lib/presentation/deployment/adapters/config_adapter.dart`; `PRO:client/packages/pocketcoder_pro/lib/presentation/deployment/adapters/details_adapter.dart` | Pro-owned Aeroform deployment, configuration, review, and readiness orchestration inspected. |
| E-PRO-UI | `PRO:client/packages/pocketcoder_pro/lib/application/walkthrough/walkthrough_cubit.dart`; `PRO:client/packages/pocketcoder_pro/lib/presentation/deployment/widgets/pocketcoder_progress_pane.dart`; `PRO:client/packages/pocketcoder_pro/lib/presentation/deployment/widgets/walkthrough_panel.dart`; `PRO:client/apps/pocketcoder/lib/widgetbook_screens.dart` | Pro-owned progress, walkthrough/brief/snippet, FAQ history, and deployment Widgetbook implementation inspected; these are not yet proof of complete live Flutter E2E. |
| E-PRO-UI-TESTS | `PRO:client/packages/pocketcoder_pro/test/application/walkthrough/walkthrough_cubit_test.dart`; `PRO:client/packages/pocketcoder_pro/test/presentation/deployment/pocketcoder_progress_pane_test.dart`; `PRO:client/packages/pocketcoder_pro/test/presentation/deployment/walkthrough_conversation_view_test.dart`; `PRO:client/packages/pocketcoder_pro/test/presentation/deployment/walkthrough_panel_test.dart`; `PRO:client/apps/pocketcoder/test/widgetbook_screens_test.dart` | Pro walkthrough Cubit, conversation, panel, progress, and Widgetbook tests are present. Focused walkthrough/panel/conversation run passed 13 tests on 2026-08-14; full Widgetbook/integration/live/E2E execution remains open. |
| E-CUBIT-FLOW | `CORE:client/packages/pocketcoder_flutter/pubspec.yaml`; `CORE:client/pubspec.yaml`; `PRO:client/packages/pocketcoder_pro/pubspec.yaml` | Core and Pro are aligned on `cubit_ui_flow` `1d31dce`; compatible `flutter_error_privserver` revision `dadb08a` is pinned so `AppCubit` compiles against the updated flow API. |
| E-PRO-BILLING | `PRO:client/packages/pocketcoder_pro/lib/app.dart`; `PRO:client/packages/pocketcoder_pro/lib/infrastructure/billing/revenue_cat_package_mapper.dart`; `PRO:client/packages/pocketcoder_pro/test/infrastructure/billing/revenue_cat_package_mapper_test.dart` | Pro RevenueCat configuration and package mapping inspected; production/store E2E remains open. |
| E-PRO-CONTROLS | `CORE:client/packages/pocketcoder_flutter/lib/domain/server_control/`; `CORE:client/packages/pocketcoder_flutter/lib/application/server_control/`; `CORE:client/packages/pocketcoder_flutter/lib/infrastructure/os_control/`; `CORE:client/packages/pocketcoder_flutter/lib/presentation/server_control/`; `PRO:client/packages/pocketcoder_pro/lib/app.dart`; `PRO:client/packages/pocketcoder_pro/lib/infrastructure/pocketcoder_update/aeroform_root_ssh_credentials_provider.dart` | Unified `SshServerControlService` exposes restart/update PocketCoder, restart/update NixOS, and save-backup operations. Pro retrieves the Aeroform-generated root SSH private key and pinned host identity from secure storage. Focused command-runner verification passed; disposable-deployment, live, and Flutter E2E verification remain open. |
