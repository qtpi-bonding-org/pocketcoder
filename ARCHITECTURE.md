# PocketCoder Architecture

This document provides a detailed overview of PocketCoder's architecture, outlining its core services, their interactions, and the design principles that govern the system. It aims to offer a clear understanding of how the various components work together to deliver a secure, self-hosted AI assistant.

## TL;DR - Current State

**Services:**
- ✅ **pocketbase** (Go) - The central "Sovereign Authority." Now includes the embedded **Go Relay** ("The Spinal Cord"), which handles event orchestration and permission gating.
- ✅ **proxy** (Rust) - The "Muscle." A high-performance, dumb execution driver. It executes authorized commands in the sandbox and nudges the brain upon completion.
- ✅ **sandbox** (Tmux) - Isolated "Reality." Stateful execution environment where all actual work occurs.
- ✅ **opencode** (Reasoning) - The "Brain" (Poco). A native agentic engine that plans, reasons, and requests actions.
- ✅ **cao** (Python) - The "Subagent Orchestrator." An MCP server running in the sandbox that allows Poco to spawn and manage specialist sub-agents.

---

## System Overview

PocketCoder is a permission-gated AI coding assistant designed with a clear separation of concerns, orchestrating interactions between its core services:

1.  **Client (Flutter App):** The user interface for interacting with **PocketBase**. It subscribes to real-time events to display thoughts, tool calls, and permission requests.
2.  **opencode (Poco):** The reasoning engine. It operates in a container but has no direct access to the host or the sandbox's shell. It "thinks" and issues tool calls.
3.  **pocketbase (Backend & Relay):**
    *   **Core:** Handles identity, data persistence, and rules.
    *   **Relay (Go Module):** The embedded orchestrator. It intercepts OpenCode's activities (via SSE), logs them to the database, and enforces the "Ask for Permission" protocol.
4.  **proxy (Rust):** A purely functional execution gateway. It accepts command requests (via HTTP) and executes them in the **sandbox** via Tmux. It trusts that the upstream request has already been permission-gated by the system (OpenCode/Relay).
5.  **sandbox (Docker/Tmux):** The isolated runtime environment.
    *   **Tools:** Contains all dev tools (git, node, python, etc.).
    *   **CAO:** Runs the `cli-agent-orchestrator` MCP server, enabling the creation of sub-agent hierarchies.

### Service Diagram

```mermaid
graph TD
    User((👤 User))
    subgraph Client ["📱 Flutter App"]
        UI[User Interface]
        SSE[Realtime Events]
    end

    subgraph ControlPlane ["🎛️ PocketBase (Go)"]
        PB[Database & Auth]
        Relay[Relay Module]
    end

    subgraph Reasoning ["🧠 OpenCode"]
        Poco[Poco (Main Agent)]
    end

    subgraph Security ["⚡ Proxy"]
        Proxy[Rust Proxy]
    end

    subgraph Execution ["🛠️ Sandbox"]
        SB[Tmux Sessions]
        CAO[CAO Subagents]
    end

    %% Flows
    User <--> UI
    UI <-- "Events" --> Relay
    
    Poco -- "SSE Firehose" --> Relay
    Poco -- "Tool Calls (Permitted?)" --> Proxy
    
    Relay -- "Permission Gate" --> PB
    
    Proxy -- "Executes" --> SB
    Proxy -- "Nudge (Reflex Arc)" --> Poco
    
    Poco -- "Spawn Subagent" --> CAO
    CAO -- "Orchestrate" --> SB
```

---

## The Pulse & Reflex Arc (Event-Driven Coordination)

PocketCoder uses a "Pulse & Reflex" architecture to maintain responsiveness without busy-waiting.

### 1. The Pulse (Thinking & Tooling)
- **OpenCode** emits a continuous stream of events (Thinking, ToolCall).
- **Relay (in PocketBase)** consumes this stream, logs it, and pushes updates to the frontend.
- **Permissioning:** When OpenCode attempts a sensitive action (like `bash` or `edit`), it pauses. The Relay creates a `permission` record. The User approves it via the UI. The Relay then signals OpenCode to proceed.

### 2. The Reflex Arc (Fast Handoff)
- When a command finishes in the **Sandbox**, the **Proxy** captures the result.
- Instead of waiting for OpenCode to poll, the Proxy hits the **Reflex Endpoint** (`/prompt_async`) on OpenCode.
- This immediately wakes up the agent to process the result and continue its train of thought.

---

## Permission Flow: The Sovereign Authority

Security is enforced via a **permissions** system managed by PocketBase.

1.  **Request:** OpenCode initiates a tool call (e.g., `bash: ls -la`).
2.  **Interception:** The tool call is intercepted (configured as `ask` in `opencode.json`).
3.  **Gatekeeper:** The Relay creates a pending permission request in PocketBase.
4.  **Arbitration:**
    *   **Auto-Approve:** If the action matches a whitelist rule (e.g., safe read-only commands), it is automatically approved.
    *   **User Review:** Otherwise, it waits in `draft` status. The User sees a prompt in the UI and clicks "Approve" or "Deny".
5.  **Execution:** Once approved, the tool call proceeds to the **Proxy** for execution in the Sandbox.

---

## Subagents (CAO Integration)

Poco is the "Manager," but he can hire help.

*   **CAO (CLI Agent Orchestrator):** An MCP server running inside the Sandbox.
*   **Capabilities:**
    -   **Spawn:** Poco can create new, isolated sub-agents (e.g., "terraformer", "researcher").
    -   **Context:** Sub-agents run in their own Tmux sessions, keeping their context separate from Poco's main thread.
    -   **Tools:** Sub-agents have access to tools installed in the Sandbox (Terraform, AWS CLI, etc.).
*   **Flow:** Poco calls `cao_handoff` -> CAO starts a sub-agent -> CAO manages sub-agent inputs/outputs -> Result returned to Poco.

---

## Service Responsibilities

### pocketbase (Go)
- **Identity & Data:** The single source of truth.
- **Relay Module:** Embeds the logic for orchestrating OpenCode interaction and managing permissions.
- **Rule Engine:** Enforces data access policies.

### proxy (Rust)
- **Dumb Execution:** Simply executes what it receives. It assumes the caller (OpenCode/Relay) has already handled permissions.
- **Reflex Node:** Triggers the "Brain" when commands complete.
- **Protocol:** Speaks HTTP to OpenCode and Socket to Tmux.

### sandbox (Docker)
- **The Workshop:** Contains all the tools and runtime binaries.
- **Persistence:** Tmux ensures long-running processes survive connection drops.

### opencode (Poco)
- **The Brain:** Pure reasoning. It sees the world through the Proxy and interacts via the Relay.

---

## Key Design Principles

1.  **Physical Separation:** Brain (OpenCode) != Body (Sandbox).
2.  **Sovereign Data:** All state lives in PocketBase, owned by the user.
3.  **Subagent Delegation:** Complex tasks can be delegated to specialist sub-agents via CAO.
4.  **Dumb Robustness:** The execution layer (Proxy/Sandbox) is kept simple and robust, focusing on reliability over logic.
