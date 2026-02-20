# 🦅 PocketCoder

**PocketCoder** is a personal research lab and an experiment in building a "Sovereign AI." It is a minimalist, local-first coding assistant designed with the philosophy of **Alpine Linux**: a tiny surface area that leverages the power of standard Unix tools.

I am building this as a solo developer because I believe that the most powerful tools shouldn't need a complex "Enterprise" footprint. Instead, PocketCoder uses high-leverage "giant's shoulders" like **PocketBase**, **Tmux**, and **OpenCode** to keep the custom glue code to an absolute minimum.

## 🧪 The Experiment
The goal is simple: *Can I build a secure, professional-grade coding environment that I can audit in a single afternoon?*

## 🛡 Personal Principles
- **Minimal Surface Area**: I prefer well-worn Unix tools over bespoke frameworks.
- **Sovereign Authority**: The reasoning engine is treated as a guest. All actions are gated by a human-inspectable log in PocketBase.
- **Extreme Portability**: The entire stack runs in a few lightweight Docker containers. It should feel as easy to self-host as your favorite static site.

## ⚠️ Disclaimer
PocketCoder is an active research project. As a solo developer, I’m building this in the open to share my progress. It is not a commercial product, and there are no support SLAs. If you find a bug, I'd love to hear about it, but please understand I'm moving at my own pace!

## 🚀 Quick Start (Local Setup)

1.  **Clone**: `git clone https://github.com/qtpi-bonding-org/pocketcoder.git`
2.  **Env**: `cp .env.example .env` (Add your Gemini API key)
3.  **Boot**: `docker-compose up -d`
4.  **Explore**: Access the PocketBase UI at `http://localhost:8090/_/`

## 🔗 Links
- [Detailed Architecture](docs/SYSTEM_ARCHITECTURE.md)
- [Security Architecture](docs/SECURITY.md)
- [Project Roadmap](PLAN.txt)
- [Project License](LICENSE) (AGPLv3)
- [Client App License](client/LICENSE) (MPL-2.0)
- [Contributing](CONTRIBUTING.md)
- [Development Guide](DEVELOPMENT.md)

---
*Built with heart by a solo dev in collaboration with **Gemini** (via Antigravity) and **Claude** (via Kiro). This project is as much an experiment in human-AI partnership as it is in software architecture.*

## Architecture: The Fractal Agent

PocketCoder is designed as a **Fractal Agent** system. It separates high-level reasoning from isolated execution environments.

- **The Brain (Poco)**: A sovereign coordinator that plans and orchestrates work.
- **The Conductor (CAO)**: A terminal-aware Python orchestrator that manages subagent delegation via the **SSH-TTY Bus**.
- **The Body (Sandbox)**: A secure, hardened environment where commands are executed in isolated Tmux panes.
- **The Gatekeeper (PocketBase)**: The stateful nervous system and ledger of record, gating every sensitive intent for user approval.
- **The Infrastructure (MCP Gateway & Proxy)**: A high-performance bridge that manages external tool servers and handles secure Docker interactions.

See [docs/SYSTEM_ARCHITECTURE.md](docs/SYSTEM_ARCHITECTURE.md) for the full technical deep-dive.

## Customize Your PocketCoder

PocketCoder is built to be extended. You "train" the system by modifying two distinct layers:

### 1. Teach the Brain (Skills) -> `Poco`
**"Skills are just Markdown for Poco."**
To give the main agent standardized procedural knowledge (e.g., "How to deploy to AWS" or "The team's Python style guide"), you add **Skills**.
- **Format**: Simple Markdown files (`.agent/skills/`).
- **Use Case**: SOPs, best practices, and procedural memory.
- **Role**: Guides the *planning* phase of the reasoning engine.

### 2. Equip the Body (Governance) -> `Subagents`
**"We gate Poco's Actions, but Subagent Capabilities."**
While Poco's direct shell/file actions are gated by human approval, subagents are **trusted inside their sandbox**. Their power is governed by the **MCP Governance Flow**:
- **Capability Approval**: Subagents request specific tools (e.g., `git-access`). The user approves the **Tool Server** itself in the database.
- **Dynamic Reification**: Once approved, the Relay bakes the tool into the **MCP Gateway**, granting the subagent autonomous access to that tool's functions.
- **Role**: Allows subagents to perform high-speed, parallel work without manual turn-by-turn gating.

*Think of it this way: You give Poco the **Manual** (Skills), and you grant the Subagents access to the **Tool Shed** (MCPs).*

## "Featherweight" High-Performance Stats
*(Strictly original PocketCoder code as of Feb 2026)*

| Component | Tech | Lines | Role |
| :--- | :--- | :--- | :--- |
| **backend** | Go | ~1,600 | Sovereign Authority, Asynchronous Relay, and API. |
| **proxy** | Rust | ~700 | Sensory bridge with high-performance TTY streaming. |
| **sandbox/cao** | Python/Bash| ~900 | The terminal-aware orchestrator and TUI bus. |
| **mcp-gateway** | Docker/Node | ~200 | Aggregates and secures external Tool Servers. |
| **CORE TOTAL**| | **~3,400** | **Lean, Fast, Fully Sovereign.** |
