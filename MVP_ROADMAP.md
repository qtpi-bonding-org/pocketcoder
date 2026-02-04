# PocketCoder MVP Roadmap 🚀

This roadmap outlines the path from initial setup to a lean, professional AI coding assistant.

## Phase 1: The Gatekeeper ✅
- [x] **Minimal Architecture**: Refactor from OpenClaw to PocketCoder.
- [x] **The Core (PocketBase)**: Define `intents` and `users` collections.
- [x] **The Whitelist**: Implement persistent, regex-based auto-authorization for safe commands.
- [x] **The Full Loop**: Prove an Intent can be created, auto-authorized, and executed in the Sandbox.
- [x] **Agent Identity**: Establish the `agent` role and secure authentication.

## Phase 2: The Execution Firewall 🚧
- [x] **Direct Tmux Driver**: Deeply integrated Rust driver for stateful command execution.
- [ ] **Shared Workspace**: Configure Docker Compose to share `pocketcoder_workspace` volume between OpenCode (Brain) and Sandbox (Hands).
- [ ] **Native File Access**: Allow OpenCode to use its native `read`, `write`, `ls`, `grep` tools on the shared volume for maximum speed and context quality.
- [ ] **The "Execution Only" Gateway**:
    -   **Disable** the native `bash` tool in OpenCode.
    -   **Replace** it with the Rust Gateway's `shell` tool.
    -   This ensures **only execution** is gated; code generation is free and fast.

## Phase 3: User Experience 🔐
- [ ] **Passkey Auth (Go)**: Implement WebAuthn in the backend for biometric "Intent Signing."
- [ ] **Flutter Ledger**: A minimal companion app to view the Intent ledger and swipe to authorize.
- [ ] **Real-time logs**: Stream Sandbox terminal output back to the Flutter app via PocketBase.

## Phase 4: Polish & Release 📦
- [ ] **Self-Hosting Guide**: One-click deployment (Docker Compose).
- [ ] **Documentation**: A humble, clear guide for the open-source community.

---

### 🛡️ Architectural Discussion: "The Execution Firewall"

**Decision: Ungated Writes, Gated Execution.**
We adopt a hybrid security model:
1.  **Filesystem (Read/Write)**: The AI has native, ungated access via a shared Docker volume. This allows it to refactor, write, and explore code at full speed with high-quality native tools (`read`, `grep`, `lsp`).
2.  **Execution (Bash)**: We strip the native `bash` tool and replace it with our **Gatekeeper Shell**.
    -   The AI can *write* a dangerous script, but it cannot *run* it without a signed Intent.
    -   This maximizes utility while preserving absolute safety.
