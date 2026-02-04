# PocketCoder MVP Roadmap 🚀

This roadmap outlines the path from our initial setup to a fully functional AI coding assistant.

## Phase 1: The Gatekeeper (Current Focus)
- [x] **Minimal Architecture**: Refactor from OpenClaw to PocketCoder.
- [x] **The Core (PocketBase)**: Define `intents` and `users` collections.
- [x] **The Whitelist**: Implement persistent, regex-based auto-authorization for safe commands.
- [x] **The Full Loop**: Prove an Intent can be created, auto-authorized, and executed in the Sandbox.
- [ ] **Agent Identity**: Ensure `opencode` authenticates as a scoped `agent` user in PocketBase.

## Phase 2: Professional Tooling & MCP
- [ ] **Unified Connector**: Refactor `connector/index.ts` to be a robust proxy for multiple MCP servers.
- [ ] **Sandbox Shell**: Implement a professional shell tool that uses the Sandbox's Tmux listener.
- [ ] **Filesystem Tool**: Implement a secure file read/write tool with Intent gating.
- [ ] **Autonomous Registry**: A way for the AI to "propose" adding a new MCP server (via shell command) and having it registered in the Connector.

## Phase 3: User Experience
- [ ] **Passkey Auth (Go)**: Implement WebAuthn in the backend for biometric "Intent Signing."
- [ ] **Flutter Ledger**: A minimal companion app to view the Intent ledger and swipe to authorize.
- [ ] **Real-time logs**: Stream Sandbox terminal output back to the Flutter app via PocketBase.

## Phase 4: Polish & Release
- [ ] **Self-Hosting Guide**: One-click deployment (Docker Compose) for VPS/Pikapods.
- [ ] **Documentation**: A humble, clear guide for the "open source spirit."

---

### 🛡️ Architectural Discussion: "Do we need permissioned installs?"

**Decision: No.**
Because we treat the AI as a scoped user, every action—including installing new tools—must go through the **Intent Gate**.
- If the AI wants to install a new MCP via `npm install -g mcp-whatever`, it must create an Intent.
- If the human authorizes the shell command, the tool is installed.
- The system remains "Air Tight" because the boundary is the **Command**, not just the **Configuration**.
- This keeps the system lean and avoids a redundant secondary permission layer.
