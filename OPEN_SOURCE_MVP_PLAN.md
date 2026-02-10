# 🚀 PocketCoder Open-Source MVP Readiness Plan

This document outlines suggestions for preparing PocketCoder for its initial open-source release, based on a comprehensive code review. The project demonstrates strong engineering quality, but focusing on clarity, ease of setup, and maintainability will be crucial for open-source adoption.

---

## 🎯 Project Aim (as per `README.md`)

**PocketCoder** is an experimental, self-hosted AI assistant that explores the intersection of personal sovereignty and AI agent capabilities, designed to live quietly in your pocket or on your VPS. It aims to build a powerful, professional-grade coding assistant that is 100% self-hosted and user-controlled, leveraging **opencode**, **pocketbase**, and **tmux**.

---

## ✅ Overall Assessment

The PocketCoder project exhibits a **high level of engineering quality** and a thoughtful architectural design. It leverages modern technologies and patterns effectively across its various services (**client**, **pocketbase**, **proxy**, **relay**, **sandbox**). The core functionality appears robust, and the innovative use of `tmux` for command execution is particularly notable.

**However, for an Open-Source MVP release, attention to documentation, onboarding, and clarity around service roles will be paramount.**

---

## 🌟 Priorities for Open-Source MVP Readiness

1.  **Clarity & Understanding:** Ensure new users and contributors can quickly grasp the project's purpose, architecture, and component interactions.
2.  **Ease of Setup:** Minimize friction for getting the entire system up and running locally.
3.  **Maintainability:** Structure the code to facilitate future contributions and updates.
4.  **Robustness:** Verify core features and critical integrations.
5.  **Community Readiness:** Establish guidelines and support for external contributions.

---

## 📋 Detailed Suggestions & Action Plan

### A. Documentation & Onboarding

*   **1. Comprehensive `README.md` Update:**
    *   **Project Vision/Mission:** Ensure the existing mission statement is prominent.
    *   **Quick Start Guide:**
        *   **Crucial:** A step-by-step guide for local setup (e.g., `git clone`, `docker-compose up`, initial config). This is the single most important piece of documentation for an open-source MVP.
        *   Include post-setup steps like accessing the Flutter UI, initial authentication, etc.
    *   **Architectural Overview:**
        *   Refine the existing "Sovereign Loop" diagram for even clearer service responsibilities and data flows.
        *   **Literal Names:** Ensure `opencode`, `pocketbase`, `relay`, `proxy`, and `sandbox` are used consistently.
    *   **Service Descriptions:** Expand on the role of each service (**client**, **pocketbase**, **proxy**, **relay**, **sandbox**).
    *   **Tech Stack:** List all major technologies and their versions.
    *   **Troubleshooting:** Common issues and solutions.
*   **2. `INSTALL.md` / `DEVELOPMENT.md`:**
    *   Create dedicated, detailed documents for setting up a development environment for each major service (**client**, **pocketbase**, **proxy**, **relay**, **sandbox**).
    *   Explain how to run tests locally for each service.
*   **3. Internal Code Comments & Explanations:**
    *   Add high-level comments to complex sections, particularly where innovative or non-obvious patterns are used (e.g., **proxy**'s `tmux` sentinel, **relay**'s permission arbitration flow). Focus on *why* something is done.
    *   Clarify interactions between services in code where appropriate.

### B. Codebase Clarity & Modularity

*   **1. Go Backend Refactoring Plan (`backend/`):**
    *   **Goal:** Break down `backend/main.go` into smaller, more focused internal packages.
    *   **Current State:** `main.go` orchestrates PocketBase initialization, custom API endpoints (permission evaluation, artifact serving, SSH keys), AI agent assembly logic, and various PocketBase hooks.
    *   **Proposed Structure:**
        ```
        backend/
        ├── internal/
        │   ├── api/             # Custom HTTP handlers (e.g., permission, artifact, ssh)
        │   │   ├── permission.go
        │   │   ├── artifact.go
        │   │   └── ssh.go
        │   ├── agents/          # AI Agent assembly logic (getAgentBundle, updateAgentConfig)
        │   │   └── service.go
        │   ├── hooks/           # All PocketBase event hooks
        │   │   ├── permissions.go # OnRecordCreate "permissions" hook
        │   │   └── agents.go      # OnRecordAfterUpdateSuccess for agents, rules, prompts, models
        │   └── auth/            # User seeding logic
        │       └── seeding.go
        └── main.go              # Main application entry point, registers services/hooks
        ```
    *   **Action:**
        1.  Create the `internal/` subdirectories.
        2.  Move relevant functions and logic from `main.go` into new files within these subdirectories.
        3.  Update `main.go` to import and initialize these new internal packages, registering their handlers and hooks.
*   **2. Node.js Relay Refactoring Plan (`relay/`):**
    *   **Goal:** Modularize `relay/chat_relay.mjs` into smaller, more manageable ES modules.
    *   **Current State:** `chat_relay.mjs` is a single large file handling permission arbitration, AI agent deployment, and chat message processing.
    *   **Proposed Structure:**
        ```
        relay/
        ├── src/
        │   ├── services/
        │   │   ├── permissionService.mjs   # listenForPermissions, handlePermissionAsked, subscribeToPermissionUpdates, replyToOpenCode
        │   │   ├── agentDeploymentService.mjs # subscribeToAgentUpdates, deployAgent
        │   │   └── chatService.mjs         # ensureOpencodeSession, processUserMessage, pollOpenCodeResponse, saveAssistantResponse, pollInbox (if kept)
        │   ├── config.mjs              # Environment variable loading, PocketBase client initialization
        │   └── main.mjs                # Entry point, orchestrates starting services
        └── chat_relay.mjs              # (Rename to main.mjs after refactoring, or remove as an alias for main.mjs)
        ```
    *   **Action:**
        1.  Create the `src/` and `src/services/` subdirectories.
        2.  Extract functions into their respective service modules.
        3.  Create `config.mjs` for centralized setup.
        4.  Update the main entry point to import and initialize these service modules.
*   **3. Sandbox `listener.ts` Clarification:**
    *   **Goal:** Resolve the ambiguity around `sandbox/listener.ts`.
    *   **Current State:** `listener.ts` implements a `tmux` control mode API but is not started by `sandbox/entrypoint.sh`.
    *   **Action:**
        1.  **Option A (Activate):** If intended to be active, integrate its startup into `sandbox/entrypoint.sh` (e.g., using `bun run listener.ts &` if Bun is used in the sandbox).
        2.  **Option B (Deprecate/Remove):** If it's an unused alternative, either comment it out heavily with an explanation or remove it to reduce codebase clutter.
        3.  **Documentation:** Add a note in the `sandbox`'s documentation explaining this component and its role (or lack thereof).

### C. Testing Strategy

*   **1. Enhance Unit Tests:**
    *   Ensure comprehensive unit tests are in place for all critical business logic within each component.
    *   Prioritize `backend/`'s permission logic, `relay/`'s message processing, and `proxy/`'s `tmux` interaction driver.
*   **2. Formalize Integration Tests:**
    *   Review existing shell-based integration tests (`test/`).
    *   **Suggestion:** Consider integrating a more robust testing framework (e.g., Go's `testing`, Node.js's `jest`/`mocha` with `supertest`, Rust's built-in testing).
    *   Ensure these tests can be easily run in a CI/CD environment.
*   **3. Clear Test Instructions:**
    *   Document how to run tests for each component in its respective `DEVELOPMENT.md` or a top-level `TESTING.md`.

### D. Project Naming & Structure

*   **1. Rename `openclaw` to `pocketcoder`:**
    *   **Goal:** Global project rename for consistency and branding.
    *   **Action:** Rename the root directory, update all internal references (file paths, comments, variables, image paths in `README.md`, Dockerfile contexts) from `openclaw` to `pocketcoder`.
*   **2. Consistent Naming Conventions:**
    *   Review variable, function, and file names across components for consistency and clarity.

### E. License & Governance

*   **1. AGPLv3 Compliance:**
    *   **Goal:** Ensure full compliance with the AGPLv3 license.
    *   **Action:** Add license headers to all source code files. Ensure the `LICENSE` file is prominent and accurate.
*   **2. Contribution Guidelines:**
    *   Expand `CONTRIBUTING.md` (generalize from `sandbox/cao/` if needed) to cover all project components, including:
        *   Code style guides (e.g., Go fmt, Rust clippy, Flutter linting, Prettier).
        *   Commit message conventions.
        *   Pull Request (PR) process.
        *   Issue reporting guidelines.
*   **3. Code of Conduct:**
    *   Ensure a project-wide `CODE_OF_CONDUCT.md` is in place (generalize from `sandbox/cao/` if needed).

### F. Minor Technical Adjustments

*   **1. Environment Variable Documentation:**
    *   **Goal:** Provide a single, comprehensive source for all required environment variables.
    *   **Action:** Create a `.env.example` file in the project root listing all environment variables needed by `docker-compose.yml` and individual services, with clear descriptions and example values.
*   **2. Node.js Relay `pollInbox` Logic:**
    *   **Goal:** Reconcile `chat_relay.mjs`'s polling with PocketBase's real-time subscriptions.
    *   **Action:** If real-time subscriptions fully cover the need, remove `pollInbox` to simplify and avoid redundant requests. If it serves a specific catch-up/recovery purpose, add explicit comments explaining this.

---

## ✅ Open-Source MVP Release Checklist

This checklist summarizes the key steps to ensure PocketCoder is ready for its initial open-source release.

-   [ ] **Project Name Renamed:** Root directory and all internal references `openclaw` -> `pocketcoder`.
-   [ ] **`README.md` Updated:**
    -   [ ] Quick Start Guide available and verified working.
    -   [ ] Architectural Overview updated, reflecting `plugins/` removal.
    -   [ ] Component Descriptions clear.
    -   [ ] Tech Stack listed.
    -   [ ] AGPLv3 license clearly stated.
-   [ ] **`INSTALL.md` / `DEVELOPMENT.md` Created/Updated:** Detailed setup for each component.
-   [ ] **Internal Comments Added:** For complex logic and inter-component interactions.
-   [ ] **Go Backend Modularized:** `main.go` refactored into `internal/` packages.
-   [ ] **Node.js Relay Modularized:** `chat_relay.mjs` refactored into `src/services/` modules.
-   [ ] **Sandbox `listener.ts` Status Clarified:** Activated, removed, or clearly documented.
-   [ ] **Unit Tests Verified:** Sufficient coverage for critical logic across all components.
-   [ ] **Integration Tests Formalized:** Robust end-to-end tests in place.
-   [ ] **Test Instructions Documented:** How to run tests for each component.
-   [ ] **AGPLv3 Compliance Verified:** License headers/statements in place.
-   [ ] **`CONTRIBUTING.md` Comprehensive:** Covers code style, PR process, etc.
-   [ ] **`CODE_OF_CONDUCT.md` Present:** Project-wide code of conduct.
-   [ ] **`.env.example` Created:** Comprehensive list of environment variables.
-   [ ] **Node.js Relay `pollInbox` Reconciled:** Logic clarified or removed if redundant.

---
