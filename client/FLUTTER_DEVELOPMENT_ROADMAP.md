# 🎯 Flutter Development Roadmap & Status

This document tracks the current state of the PocketCoder Flutter application and outlines the remaining tasks for a "V1" production-ready integration.

---

## 🏛️ Current Architectural State

We are moving towards a **Sovereign Data Architecture** (3-Tier):
1.  **Domain Models**: Type-safe `freezed` classes (Partially Aligned).
2.  **DAOs**: Thin wrappers for PocketBase collections with reactive `drift` caching (Currently implementing).
3.  **Repositories**: High-level services that consume DAOs and custom endpoints.

---

## 🚦 Status Summary

| Category | Status | Details |
| :--- | :--- | :--- |
| **Auth & Profile** | ✅ DONE | Basic PocketBase login/logout and session management. |
| **Model Alignment** | 🟡 PROGRESS | `Chat`, `Device`, `Subagent` are aligned. `Message`, `Permission` need work. |
| **Notifications** | 🟡 PROGRESS | Registration logic fixed. Receiving/Display logic needs verification. |
| **UI Feedback** | 🟡 PROGRESS | `cubit_ui_flow` pattern established. `VimToast` integration pending. |
| **DAOs & Persistence** | 🔴 PENDING | `BaseDao` created, but 14 specific DAOs need implementation. |
| **Custom Endpoints** | 🔴 PENDING | SSH keys, Artifacts, and Permission Evaluation calls not yet implemented. |

---

## 🛠️ Phase 1: Model & Data Layer Alignment (High Priority)

Before we build complex UI, the data must be 100% reliable.

- [ ] **Data Model Audit**:
    - [x] `Chat`: Aligned with schema.
    - [x] `Device`: Aligned with schema.
    - [x] `Subagent`: Aligned with schema.
    - [ ] `ChatMessage`: Add `delivery` field, verify `tokens` structure, ensure `agent_message_id` mapping.
    - [ ] `PermissionRequest`: Fix date parsing, add `challenge`, `source`, and `usage` fields.
    - [ ] `AiAgent`: Remove `mode`, verify relations (`prompt`, `model`) are handled correctly.
- [ ] **Implement Missing Models**:
    - [ ] `SshKey`: Required for device authentication.
    - [ ] `Usage`: For tracking AI costs/tokens.
    - [ ] `Proposal` & `Sop`: For the Evolution system.
    - [ ] `Healthcheck`: For system monitoring.
- [ ] **Core DAO Layer**:
    - [ ] Implement concrete DAOs for all collections (following `BaseDao` pattern).
    - [ ] Update repositories to use DAOs instead of direct `PocketBase` calls where possible.

---

## 🔌 Phase 2: Backend Integration & Features (Medium Priority)

Connecting the client to the "Brain" (OpenCode) and the Sandbox.

- [ ] **Custom API Endpoints** (via `Relay`):
    - [ ] `PermissionRepository.evaluatePermission()`: POST to `/api/pocketcoder/permission`.
    - [ ] `AuthRepository.getSshKeys()`: GET from `/api/pocketcoder/ssh_keys`.
    - [ ] `ChatRepository.getArtifact()`: GET from `/api/pocketcoder/artifact/{path}`.
- [ ] **Real-Time Synergy**:
    - [ ] **Hot Pipe**: Verify Tool execution state tracking (pending → running → completed).
    - [ ] **SSE Connection**: Implement direct SSE client to OpenCode for instant agent events (Permission asked, turn changed).
- [ ] **Push Notifications**:
    - [ ] Verify background handlers for FCM (Android) and UnifiedPush (FOSS).
    - [ ] Ensure local notifications are displayed consistently across platforms.

---

## 🎨 Phase 3: UI/UX Refinement (Polish)

Making it feel like a "Retro Terminal" coding assistant.

- [ ] **Standardize Feedback**:
    - [ ] Integrate `VimToast` into `AppFeedbackService`.
    - [ ] Ensure all cubits use `UiFlowListener` for consistent error/loading overlays.
- [ ] **Aesthetic Consistency**:
    - [ ] Audit all screens for "Green Terminal" design token usage.
    - [ ] Replace remaining hardcoded colors with `context.terminalColors`.

---

## 📝 Next Steps for Antigravity

1.  **Complete Model Alignment**: Audit `ChatMessage` and `PermissionRequest` against the latest PB schema.
2.  **Infrastructure Expansion**: Implement the missing domain models (SshKey, Usage, etc.).
3.  **The "Big Switch"**: Refactor the main repositories to use the DAO pattern for reactive, offline-first data.
