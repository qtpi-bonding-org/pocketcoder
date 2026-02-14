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
- [Detailed Architecture](docs/architecture/ARCHITECTURE.md)
- [Security Architecture](docs/architecture/SECURITY.md)
- [Project Roadmap](docs/roadmap/MVP_ROADMAP.md)
- [Project License](LICENSE) (AGPLv3)
- [Client App License](client/LICENSE) (MPL-2.0)
- [Contributing](CONTRIBUTING.md)
- [Development Guide](DEVELOPMENT.md)

---
*Built with heart by a solo dev in collaboration with **Gemini** (Google's agentic AI assistant). This project is as much an experiment in human-AI partnership as it is in software architecture.*

## Architecture: The Fractal Agent

PocketCoder is designed as a **Fractal Agent** system. It separates high-level reasoning (The Brain) from isolated execution environments (The Body).

- **The Brain (Poco)**: A sovereign coordinator that plans and orchestrates work.
- **The Body (Sandbox)**: A secure environment where Sub-Agents execute tasks.
- **The Proxy (Immune System)**: A Rust gateway that relays thoughts to actions, enforcing protocol and user intent.
- **The State (Memory)**: PocketBase acts as the ledger of record.

See [BACKEND_STATUS.md](BACKEND_STATUS.md) for the current architectural state.

## Customize Your PocketCoder

PocketCoder is built to be extended. You "train" the system by modifying two distinct layers:

### 1. Teach the Brain (Skills) -> `Poco`
**"Skills are just Markdown for Poco."**
To give the main agent standardized procedural knowledge (e.g., "How to deploy to AWS" or "The team's Python style guide"), you add **Skills**.
- **Format**: Simple Markdown files (`skills/MY_SKILL.md`).
- **Use Case**: SOPs, best practices, and "memory" for the orchestrator.
- **Location**: `./skills/`

### 2. Equip the Body (Tools) -> `Subagents`
**"MCPs are for Subagents."**
To give the execution agents actual capabilities (e.g., `postgres-access`, `github-api`, `web-search`), you define **MCP Servers**.
- **Format**: Added directly to the sub-agent's definition file in `./sandbox/cao/agent_store/`.
- **Zero-Install**: No complex Docker builds required. Just specify the server (e.g., `uvx mcp-server-postgres`), and the sandbox spins it up ephemerally on demand.
- **Function**: Gives the "hands" the specific tools they need for the task.

*Think of it this way: You give Poco the **Manual** (Skills), and you give the Subagents the **Power Tools** (MCPs).*

## "Featherweight" High-Performance Stats
*(Strictly original PocketCoder code as of Feb 2026)*

| Component | Tech | Lines | Role |
| :--- | :--- | :--- | :--- |
| **backend** | Go | ~1,200 | Sovereign Authority, Asynchronous Relay, and API. |
| **proxy** | Rust | ~450 | Sensory bridge with Brain-Nudge support. |
| **sandbox** | Bash/Python| ~250 | The isolated environment glue. |
| **CORE TOTAL**| | **~1,900** | **Leaner, Faster, Fully Sovereign.** |
