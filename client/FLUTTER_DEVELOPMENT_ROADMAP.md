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
| **UI Feedback** | ✅ DONE | `cubit_ui_flow` + `VimToast` + `UiFlowListener` standardized. MCP Notification strategy implemented. |
| **DAOs & Persistence** | ✅ DONE | Concrete DAOs implemented for major collections; Repositories are now reactive. |
| **Custom Endpoints** | ✅ DONE | SSH, Permission, Hot Pipe, MCP notification, and File bridge implemented. |

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
    - [x] `PermissionRepository.evaluatePermission()`: POST to `/api/pocketcoder/permission`.
    - [x] `AuthRepository.getSshKeys()`: GET from `/api/pocketcoder/ssh_keys`.
    - [x] `ChatRepository.getFile()`: GET from `/api/pocketcoder/files/{path}`.
- [ ] **Real-Time Synergy**:
    - [x] **Hot Pipe**: SSE streaming implemented for message snapshots.
    - [ ] **Tool State**: Verify detailed tool execution state tracking (pending → running → completed).
- [ ] **Push Notifications**:
    - [x] Integrate Ntfy/UnifiedPush as core FOSS-default.
    - [ ] Implement "Sovereign Mode" toggle in settings to prefer FOSS services (UnifiedPush) over proprietary ones (FCM).
    - [ ] Ensure local notifications are displayed consistently across platforms.

---

## 🔗 Backend Synchronization Matrix

This matrix maps native PocketBase custom endpoints and collections to their corresponding Flutter implementations.

| Endpoint / Collection | HTTP Method | Flutter Integration | Status |
| :--- | :--- | :--- | :--- |
| **`/api/chats/:id/stream`** | GET (SSE) | `CommunicationRepository.watchHotPipe` | ✅ DONE |
| **`/api/pocketcoder/permission`** | POST | `HitlRepository.evaluatePermission` | ✅ DONE |
| **`/api/pocketcoder/ssh_keys`** | GET | `AuthRepository.getAuthorizedKeys` | ✅ DONE |
| **`/api/pocketcoder/mcp_request`** | POST | `McpRepository.requestMcp` | 🔴 PENDING |
| **`/api/pocketcoder/files/{path}`** | GET | `ChatRepository.getFile` | ✅ DONE |
| **`/api/pocketcoder/logs/{container}`** | GET (SSE) | `ObservabilityRepository.watchLogs` | ✅ DONE |
| **`/api/pocketcoder/proxy/obs/*`** | ANY | `ObservabilityRepository.fetchSystemStats` | ✅ DONE |
| **`ai_agents` / `ai_models`** | CRUD | `AiConfigRepository` | ✅ DONE |
| **`chats` / `messages`** | CRUD | `CommunicationRepository` | ✅ DONE |
| **`mcp_servers`** | CRUD / Watch | `McpRepository` / `McpCubit` | ✅ DONE |
| **`permissions`** | CRUD | `HitlRepository` | ✅ DONE |
| **`healthchecks`** | CRUD | `HealthRepository` | ✅ DONE |
| **`sops` / `proposals`** | CRUD | `EvolutionRepository` | ✅ DONE |

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

1.  **Agent Management Pickers**: Implement the actual selection logic for Models and Prompts in `AgentManagementScreen`.
2.  **Sovereign Mode Toggle**: Add the UI and logic in Settings to toggle between proprietary cloud services and FOSS local alternatives at runtime.
