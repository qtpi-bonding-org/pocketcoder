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
- [Project Roadmap](docs/roadmap/MVP_ROADMAP.md)
- [License](LICENSE) (AGPLv3)
- [Contributing](CONTRIBUTING.md)
- [Development Guide](DEVELOPMENT.md)

---
*Built with heart by a solo dev in collaboration with **Gemini** (Google's agentic AI assistant). This project is as much an experiment in human-AI partnership as it is in software architecture.*

## Architecture: The Event-Driven Loop

PocketCoder uses a **Pulse & Reflex** nervous system. The "Brain" (Reasoning) is isolated from "Reality" (Sandbox) by a sensory security relay.

- **The Pulse**: All agent thoughts and tool calls are streamed instantly via SSE and recorded in the Sovereign Ledger.
- **The Reflex**: Sub-agents in the Sandbox "nudge" the Brain via the Proxy, eliminating handoff delays.

```mermaid
graph TD
    User((👤 User))
    subgraph Client ["Client Interface"]
        UI[Flutter App]
    end

    subgraph ControlPlane ["Control Plane (Go)"]
        PB[(PocketBase)]
        Relay[Relay / Spinal Cord]
    end

    subgraph Reasoning ["Reasoning"]
        OC[OpenCode / Brain]
    end

    subgraph Security ["Security & Senses"]
        Proxy[Proxy / Muscle]
    end

    subgraph Execution ["Execution (Isolated)"]
        SB[Sandbox / Reality]
        Tmux[Tmux Session]
    end

    %% Flows
    User <--> UI
    UI <--> PB
    
    PB <--- Event Sync ---> Relay
    Relay <--- HTTP/SSE ---> OC
    
    OC <--> Proxy
    Proxy -- Reflex Arc --> OC
    Proxy <--> SB
    SB <--> Tmux
```

## "Featherweight" High-Performance Stats
*(Strictly original PocketCoder code as of Feb 2026)*

| Component | Tech | Lines | Role |
| :--- | :--- | :--- | :--- |
| **backend** | Go | ~1,200 | Sovereign Authority, Asynchronous Relay, and API. |
| **proxy** | Rust | ~450 | Sensory bridge with Brain-Nudge support. |
| **sandbox** | Bash/Python| ~250 | The isolated environment glue. |
| **CORE TOTAL**| | **~1,900** | **Leaner, Faster, Fully Sovereign.** |
