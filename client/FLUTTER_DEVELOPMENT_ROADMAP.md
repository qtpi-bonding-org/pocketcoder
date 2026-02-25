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
| **Model Alignment** | ✅ DONE | All core models (Chat, Message, Agent, Proposal, SOP, Health) aligned. |
| **Notifications** | 🟡 PROGRESS | Ntfy/UnifiedPush integrated into Core. Receiving/Display logic verified. |
| **UI Feedback** | ✅ DONE | `cubit_ui_flow` + `VimToast` + `UiFlowListener` standardized across screens. |
| **DAOs & Persistence** | ✅ DONE | Concrete DAOs implemented for major collections; Repositories are now reactive. |
| **Custom Endpoints** | � PROGRESS | SSH keys and Permission Evaluation implemented. Artifacts pending. |

---

## 🛠️ Phase 1: Model & Data Layer Alignment (High Priority)

Before we build complex UI, the data must be 100% reliable.

- [x] **Data Model Audit**:
    - [x] `Chat`: Aligned with schema.
    - [x] `Device`: Aligned with schema.
    - [x] `Subagent`: Aligned with schema.
    - [x] `ChatMessage`: Aligned with schema.
    - [x] `PermissionRequest`: Aligned with schema.
    - [x] `AiAgent`: Aligned with schema.
- [x] **Implement Missing Models**:
    - [x] `SshKey`: Required for device authentication.
    - [x] `Usage`: For tracking AI costs/tokens.
    - [x] `Proposal` & `Sop`: Aligned with Evolution system.
    - [x] `Healthcheck`: Unified model implemented.
- [x] **Core DAO Layer**:
    - [x] Implement concrete DAOs for all major collections.
    - [x] Update repositories to use reactive `baseDao` pipes.

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
    - [x] Folded FOSS/UnifiedPush logic into Core.
    - [ ] Implement "Sovereign Mode" toggle in settings to switch between FCM and UnifiedPush at runtime.
    - [ ] Ensure local notifications are displayed consistently across platforms.

---

## 🎨 Phase 3: UI/UX Refinement (Polish)

Making it feel like a "Retro Terminal" coding assistant.

- [x] **Standardize Feedback**:
    - [x] Integrate `VimToast` into `AppFeedbackService`.
    - [x] Ensure all cubits use `UiFlowListener` for consistent error/loading overlays.
- [x] **Aesthetic Consistency**:
    - [x] Audit all screens for "Green Terminal" design token usage.
    - [x] Replace remaining hardcoded colors with `context.terminalColors`.

---

## 📝 Next Steps for Antigravity

1.  **The "Hot Pipe"**: Implement the running state tracking for background tools and turn-based permission gating.
2.  **SSE Connection**: Implement a robust SSE consumer in the `ChatRepository` for instant agent status updates.
3.  **Sovereign Mode Toggle**: Add the UI and logic in Settings to swap between Cloud (Proprietary) and Local (FOSS) services.
