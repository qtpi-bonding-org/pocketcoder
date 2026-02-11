# 🦅 The Sovereign Audit (Original Code Index)

As part of the **PocketCoder** philosophy of radical transparency and auditability, this document provides a complete index of all original code written for this project.

If it's not on this list, it's a third-party dependency (like PocketBase, Tmux, or CAO) that I leverage to keep the surface area small.

## 🏛️ Identity & Gateway (Go)
| File | Role |
| :--- | :--- |
| `backend/main.go` | Orchestrator: Registers hooks, starts the relay, and boots PocketBase. |
| `backend/internal/hooks/permissions.go` | The Gatekeeper: Ensures sensitive actions start as "Drafts." |
| `backend/internal/hooks/agents.go` | Agent Bundler: Auto-creates markdown profiles for OpenCode. |
| `backend/internal/hooks/timestamps.go` | Housekeeping: Automated `created`/`updated` management. |
| `backend/internal/api/permission.go` | Authority API: Validates intent signatures and wildcard patterns. |
| `backend/internal/api/ssh.go` | Key Sync API: Returns authorized keys formatted for OpenSSH. |
| `backend/internal/filesystem/filesystem.go` | Artifact Server: Native PocketBase abstraction for /workspace access. |
| `backend/internal/utils/wildcard.go` | Logic Helper: Glob-style pattern matching for permissions. |

## 🧠 Reasoning Relay (Go)
| File | Role |
| :--- | :--- |
| `backend/pkg/relay/relay.go` | Spinal Cord: Listens to DB events and triggers OpenCode sessions. |
| `backend/pkg/relay/messages.go` | Protocol: Translates DB records into OpenCode message formats. |
| `backend/pkg/relay/permissions.go` | Permission Proxy: Handles the "Always Ask" loop with the agent. |
| `backend/pkg/relay/turns.go` | Batching Logic: Groups multiple turns into atomic units to prevent overflow. |

## 🛡️ Execution Proxy (Rust)
| File | Role |
| :--- | :--- |
| `proxy/src/main.rs` | The Muscle: Translates authorized high-level intents into `tmux` send-keys. |

## 🏗️ Sandbox & Logic (Bash/Python)
| File | Role |
| :--- | :--- |
| `sandbox/entrypoint.sh` | Runtime Boot: Starts SSHD and ensures the tmux socket is shared. |
| `sandbox/sync_keys.sh` | Key Guard: Periodically pulls authorized keys into `authorized_keys`. |
| `sandbox/cao/src/.../opencode.py` | OpenCode Provider: Custom extension for CAO to understand OpenCode events. |

## 📑 Build & Docs
| File | Role |
| :--- | :--- |
| `docs/sync.sh` | Doc Extraction: Automated polyglot doc generation and LOC counting. |
| `Dockerfile.docs` | Environment: The isolated pipeline for making this documentation. |

---
*Total Original Footprint: ~2,100 Lines of Code. Auditable in an afternoon.*
