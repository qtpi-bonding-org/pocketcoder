# PocketCoder Architecture

This document provides a detailed overview of PocketCoder's architecture, outlining its core services, their interactions, and the design principles that govern the system. It aims to offer a clear understanding of how the various components work together to deliver a secure, self-hosted AI assistant.

## TL;DR - Current State

**Services:**
- ✅ **relay** (Go) - The asynchronous "Spinal Cord." Intercepts tool/permission requests, handles agent deployment, and orchestrates the event firehose via SSE.
- ✅ **pocketbase** (Go) - The central "Sovereign Authority." Handles auth, storage, and auto-authorizes safe operations.
- ✅ **proxy** (Rust) - The "Muscle & Senses." High-performance execution driver that nudges the brain when tasks complete.
- ✅ **sandbox** (Tmux) - Isolated "Reality." Stateful execution environment.
- ✅ **opencode** (Reasoning) - The "Brain." A native agentic engine that natively queues and processes pulses.

---

## System Overview

PocketCoder is a permission-gated AI coding assistant designed with a clear separation of concerns, orchestrating interactions between its core services:

1.  **Client (Flutter App):** The user interface for interacting with PocketCoder, displaying information, and allowing user intervention for permissions.
2.  **opencode (Reasoning Engine):** The external AI agent that performs high-level reasoning and decision-making, requesting permissions and command execution from the system.
3.  **pocketbase (Go Backend):** The central authority for identity, data persistence, real-time events, and initial permission arbitration. All state, audit logs, and agent configurations are stored here.
4.  **relay (Go):** The asynchronous orchestrator. It listens to the OpenCode SSE firehose and syncs all activity (thinking, tool-calls, text) directly to PocketBase in real-time. It no longer blocks on turns, but rather "records the game" as it happens.
5.  **proxy (Rust):** A high-performance sensory relay. It executes commands in the sandbox and "nudges" the Brain (OpenCode) immediately upon completion via the **Reflex Arc**.
6.  **sandbox (Docker/Tmux):** The stateful "Reality." An isolated Linux environment managed via Tmux, ensuring command persistence even if a container restarts.

These services form the "Sovereign Loop," where the reasoning engine (`opencode`) is strictly isolated from direct execution, with all critical actions and data flows mediated and audited through the control plane (`pocketbase` and `relay`) and the security relay (`proxy`).

### Service Diagram (Simplified)

```mermaid
graph TD
    User((👤 User))
    subgraph Client ["📱 Flutter App"]
        UI[User Interface]
    end

    subgraph ControlPlane ["🎛️ Control Plane (Go)"]
        PB[(pocketbase)]
        Relay[relay / Go]
    end

    subgraph Reasoning ["🧠 Reasoning"]
        OC[opencode]
    end

    subgraph Security ["⚡ Security & Sensation"]
        Proxy[proxy / Rust]
    end

    subgraph Execution ["🛠️ Execution"]
        SB[sandbox]
        Tmux[Tmux Session]
    end

    %% Flows
    User <--> UI
    UI <---> PB
    
    PB <--- Event Stream (SSE) ---> Relay
    Relay <--- HTTP / Radio ---> OC
    
    OC <--- Requests ---> Proxy
    Proxy --- Reflex Arc (Notify) ---> OC
    Proxy <---> SB
    SB <--> Tmux
```



---

## The Pulse & Reflex Arc (Event-Driven Coordination)

PocketCoder has evolved from a blocking "Request-Response" model to a biological "Pulse & Reflex" architecture.

### 1. The Pulse (Thinking & Tooling)
- **OpenCode** emits a continuous SSE stream ("Firehose") of events: *Thinking*, *StepStart*, *ToolCall*, *MessageUpdate*.
- **Relay** sits on the "Radio" and syncs these pulses to PocketBase instantly. 
- The **User UI** (Flutter) subscribes to PocketBase and displays the "Thoughts" in real-time without polling.

### 2. The Reflex Arc (Fast Handoff)
- When a sub-agent (CAO) finishes a task in the **Sandbox**, it sends a notification to the **Proxy**.
- The **Proxy (Muscle)** immediately hits the **OpenCode (Brain)** `/prompt_async` endpoint.
- This "Reflex" wakes up the Brain instantly. The Brain processes the worker's result and continues the plan.
- The **Relay** sees the resulting events on the stream and syncs them.

---

## Permission Flow: The Sovereign Authority

PocketCoder uses a **Whitelist-First** security model, where PocketBase acts as the "Sovereign Authority" for all agent intents.

### Whitelist-First Execution (Auto-Authorized)

1. **OpenCode** asks for permission (e.g., `bash: git status`).
2. **Relay** receives the request and POSTs to PocketBase `/api/pocketcoder/permission`.
3. **PocketBase** evaluates the intent against `whitelist_actions` (Verbs) and `whitelist_targets` (Nouns).
4. If a match is found:
    - PocketBase creates a `permissions` record with status `authorized`.
    - PocketBase returns `{ permitted: true }`.
    - **Relay** immediately tells **OpenCode** to proceed (`once`).
5. If NO match is found:
    - PocketBase creates a `permissions` record with status `draft`.
    - PocketBase returns `{ permitted: false, status: "draft" }`.
    - **Relay** waits for a realtime update on the `permissions` collection.
    - **User** approves manually via the UI.
    - **Relay** receives the `authorized` event and tells **OpenCode** to proceed.

---

## Database Schema

### `permissions` Collection (Intents)
- `opencode_id`: Unique ID from the reasoning engine.
- `session_id`: OpenCode session context.
- `chat`: Relation to the `chats` collection.
- `permission`: Type (bash, write, read, etc).
- `patterns`: List of target nouns (file paths, URLs).
- `status`: `draft`, `authorized`, `denied`.
- `message`: Descriptive request summary.
- `source`: Service that initiated the intent.
- `challenge`: Random UUID for cryptographic signing (future proofing).

### `whitelist_actions` / `whitelist_targets`
- Collections used by the Sovereign Authority to auto-approve intents based on patterns (e.g., `bash: git status` or `write: /workspace/**`).

---

## Service Responsibilities

### relay (Go)
- **Asynchronous Spinal Cord**: Orchestrates communication between PocketBase and OpenCode without blocking the event loop.
- **SSE Consumer**: Listens to the `/event` firehose and mirrors agent activity into the Sovereign Ledger (PB).
- **Agent Deployer**: Syncs prompt files, model configs, and agent rules from PocketBase to the OpenCode engine on-the-fly.

### pocketbase (Go)
- **Sovereign Authority**: Custom Go logic implements the `/api/pocketcoder/permission` endpoint for centralized intent arbitration.
- **Rule Engine**: Standard PocketBase API rules restrict data access for "Agents" vs "Humans".

### proxy (Rust)
- **Sensory Execution Proxy**: A high-performance Rust service that exposes an `/exec` endpoint.
- **Reflex Node**: Includes a `/notify` endpoint that triggers immediate brainHand-offs, bypassing standard polling delays.
- **TMUX Controller**: Directly communicates with the TMUX socket in the sandbox to run commands and monitor stateful sessions.

### sandbox (Docker/Tmux)
- **Isolated User-space**: Persistent terminal sessions managed by TMUX.
- **Key Manager**: Receives synced SSH keys via a shared volume to enable secure external access.

---

## Key Design Principles

1. **Physical Separation**: Reasoning (`opencode`) is networking-isolated from Execution (`sandbox`).
2. **Persistence**: Every intent and result is stored in `pocketbase` for auditability and recovery.
3. **Zero-Trust**: The reasoning engine (`opencode`) is treated as a guest. It cannot execute anything that hasn't been explicitly authorized by the user (or an auto-authorization rule) in `pocketbase`.
4. **Auditability**: All actions, permissions, and command executions are logged in `pocketbase` for a complete audit trail.
5. **Resilience**: Leveraging `tmux` in the `sandbox` for persistent sessions and `pocketbase` for state ensures operational resilience.

---

