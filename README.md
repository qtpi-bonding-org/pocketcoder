# 🦅 PocketCoder

**PocketCoder** is an experimental, self-hosted AI assistant. It explores the intersection of personal sovereignty and AI agent capabilities, designed to live quietly in your pocket or on your VPS.

## 🧪 The Experiment
PocketCoder is a research project investigating a simple question: *Can we build a powerful, professional-grade coding assistant that is 100% self-hosted and user-controlled?*

To answer this, we are stitching together some of the best open-source technologies into a cohesive system:
- **OpenCode**: For high-level reasoning and agentic loops.
- **PocketBase**: For a lightweight, portable backend and permission system.
- **Tmux**: For resilient, recovering shell sessions.

## 🛡 Core Values
- **Minimal Surface Area**: We rely on battle-tested infrastructure (PocketBase, Tmux, Docker) with minimal custom glue code (~1,800 LOC). Less code means fewer bugs and a smaller attack surface.
- **Ownership**: You should own your data, your logs, and your API keys.
- **Privacy**: No telemetry. No hidden usage tracking. Just code.

## ⚠️ License & Use
PocketCoder is open-source software licensed under the **GNU Affero General Public License v3.0 (AGPLv3)**.

We chose this license to ensure that if PocketCoder is ever used to provide a network service, the improvements returned to the community remain open.

*   **Individuals & Researchers**: Free to use, modify, and explore.
*   **Commercial/Proprietary**: If you wish to embed this into a closed-source product, please reach out regarding a commercial license.

## 🚀 Getting Started

PocketCoder is designed to run anywhere Docker is available.

1.  **Clone the Repository**:
    ```bash
    git clone https://github.com/qtpi-bonding/pocketcoder.git
    cd pocketcoder
    ```
2.  **Configure Environment**:
    ```bash
    cp .env.example .env
    # Add your Gemini/OpenCode API keys to .env
    ```
3.  **Boot the Stack**:
    ```bash
    docker-compose up -d
    ```
4.  **Access the Dashboard**:
    Open `http://localhost:8080/_/` (PocketBase Admin) or use the Flutter client.

## 🔗 Links
- [License](LICENSE) (AGPLv3)

---
*Built on the shoulders of giants. Inspired by the pioneering work of OpenClaw and the power of OpenCode.*

## Architecture: The Sovereign Loop

PocketCoder operates on a **Physical Separation of Concerns**. The reasoning engine is isolated from the execution environment by a security relay.

```mermaid
graph TD
    User((👤 User))
    subgraph Client ["📱 Flutter App"]
        UI[User Interface]
    end

    subgraph ControlPlane ["Control Plane"]
        PB[(PocketBase)]
        Relay[Relay / Go]
    end

    subgraph Reasoning ["Reasoning"]
        OC[OpenCode]
    end

    subgraph Security ["Security"]
        Proxy[Proxy / Rust]
    end

    subgraph Execution ["Execution"]
        SB[Sandbox / Docker]
        Tmux[Tmux Session]
    end

    %% Flows
    User <--> UI
    UI <--> PB
    
    PB <-. Subscription .-> Relay
    Relay <--> OC
    
    OC <--> Proxy
    Proxy <--> SB
    SB <--> Tmux
```

## Codebase Stats: "Featherweight Industrial"
*(LOC counts as of Feb 2026)*

We prioritize high-leverage tools over custom code. The core system is auditable in an afternoon.

| **Component** | Tech | Lines | Role |
| :--- | :--- | :--- | :--- |
| **backend** | Go | ~900 | **Identity & Rules**: Gating, Auth, API Management |
| **relay** | Go | ~950 | **Control Plane**: Intent Analysis & OpenCode Orchestration |
| **proxy** | Rust | ~400 | **Execution Proxy**: Secure shell/tmux bridge |
| **sandbox** | Bash/TS | ~750 | **Runtime**: Isolated execution & key management |
| **TOTAL** | | **~3,000** | **Lean, Sovereign, Auditable** |
