# 🦅 The Sovereign Audit (Original Code Index)

This document is **programmatically generated**. It lists files explicitly tagged with `@pocketcoder-core`.
If a file isn't on this list, it's a third-party dependency (like PocketBase or CAO).

## 🏛️ Original Logic Index

| File | Tech | Role |
| :--- | :--- | :--- |
| `proxy/src/main.rs` | Rust | Sovereign Proxy. The "Muscle" that securely bridges the Brain to the Sandbox. |
| `backend/main.go` | Go | Main Orchestrator. Registers hooks, starts the relay, and boots PocketBase. |
| `backend/pkg/relay/relay.go` | Go | Sovereign Relay. The "Spinal Cord" that syncs Reasoning with Reality. |
| `sandbox/cao/src/cli_agent_orchestrator/providers/opencode.py` | Python | OpenCode Provider. Custom extension to sync CAO with OpenCode events. |
| `sandbox/sync_keys.sh` | Bash | Key Guard. Periodically pulls authorized keys from the PocketBase API. |
| `sandbox/entrypoint.sh` | Bash | Runtime Boot. Starts SSHD and ensures the tmux socket is shared. |
| `scripts/generate_audit.sh` | Bash | .*" | cut -d: -f2- | sed 's/^ //') |

---
*Total Original Footprint: 6 tagged files.*
