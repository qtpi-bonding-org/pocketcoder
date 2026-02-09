# PocketCoder MVP Roadmap 🚀

This roadmap outlines the path from initial setup to a lean, professional AI coding assistant.

## Phase 1: The Gatekeeper ✅
- [x] **Minimal Architecture**: Refactor from OpenClaw to PocketCoder.
- [x] **The Core (PocketBase)**: Define `intents` and `users` collections.
- [x] **The Whitelist**: Implement persistent, regex-based auto-authorization for safe commands.
- [x] **The Full Loop**: Prove an Intent can be created, auto-authorized, and executed in the Sandbox.
- [x] **Agent Identity**: Establish the `agent` role and secure authentication.

## Phase 2: The Execution Firewall ✅
- [x] **Direct Tmux Driver**: Deeply integrated Rust driver for stateful command execution.
- [x] **Shared Workspace**: Configured Docker Compose to share `workspace_data` volume between OpenCode (Brain) and Sandbox (Hands).
- [x] **Native File Access**: OpenCode uses native tools on the shared volume for speed, while execution is handled by the Bridge.
- [x] **The "Execution Only" Gateway**:
    -   **Intercepted** the native shell via `shell_wrapper.sh`.
    -   **Enforced** gating through the Rust Gateway and PocketBase.
    -   **Verified** that only execution is gated; file writes remain fast and native.


## Phase 3: The User Experience 🏗️
- [x] **Secure Access**: Standardized on robust password-based auth for simplicity and speed.
- [x] **Universal Gating**: Every tool request (bash, read, write) creates a "Draft" intent by default.
- [ ] **Live Terminal Mirror**: Stream real-time `tmux` pane output back to the Flutter app.
- [ ] **Artifact Ledger**: A dedicated F1 dashboard for "finalized" outputs (files, UIs, code blocks).
- [ ] **Enhanced Whitelisting**: Extend the regex-based auto-auth to non-bash tools (e.g., allow `read` on certain paths).

## Phase 4: Polish & Release 📦
- [ ] **Local-First Packaging**: One-click deployment script using `docker-compose`.
- [ ] **Zero-Config Setup**: Automatic user seeding and environment validation on first boot.
- [ ] **Documentation**: A humble, clear guide for self-hosters and contributors.

---

### 🛡️ Architectural Discussion: "Max Security"

**Decision: Zero-Trust by default.**
Contrary to earlier discussions, we have settled on a **Zero-Trust** model:
1.  **Total Gating**: Every single tool request from the AI—whether it is reading a file, writing one, or executing a command—is intercepted as a `permission` record.
2.  **Explicit Consent**: The human must authorize the "Intent" before the AI can proceed.
3.  **Efficiency via Whitelisting**: To avoid "Authorize Fatigue," we use a persistent Whitelist collection for common, safe patterns (like `git status` or `ls`).
4.  **Local Authority**: PocketCoder is a local-first appliance where the human is the final signing authority.
