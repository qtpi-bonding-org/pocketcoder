# PocketCoder

**PocketCoder** is a personal research lab and an experiment in building a "Sovereign AI." It is a minimalist, local-first coding assistant designed with the philosophy of **Alpine Linux**: a tiny surface area that leverages the power of standard Unix tools.

I am building this as a solo developer because I believe that the most powerful tools shouldn't need a complex "Enterprise" footprint. Instead, PocketCoder uses high-leverage "giant's shoulders" like **PocketBase**, **Tmux**, and **OpenCode** to keep the custom glue code to an absolute minimum.

## 🧪 The Experiment: A Secure Bridge for Agentic Workflows

The AI ecosystem is moving fast, and we are seeing two distinct patterns emerge in how people interact with autonomous agents. PocketCoder is an experiment aimed at finding the secure middle ground between them.

**1. The "Antigravity" Workflow on the Go**

Recent tools like Google Antigravity have shown that for *certain parts* of development, a high-level "Mission Control" workflow is highly effective. You aren't typing syntax; you are reviewing agent plans, looking at task lists, and approving executions. While intense, nitty-gritty coding will always belong on a desktop, PocketCoder aims to bring the orchestration subset of your workflow to your phone. It allows you to assign tasks, review plans, and approve deployments securely while away from your keyboard.

**2. A Secure Alternative to OpenClaw**

For non-technical users and developers alike, the appeal of tools like OpenClaw is obvious: the ability to message a personal AI agent from your phone and have it execute real-world tasks. However, routing system-level commands through unauthenticated chat apps (like WhatsApp or Telegram) is a well-documented security nightmare. PocketCoder provides that same mobile convenience, but wraps it in a proper, authenticated application backed by a Zero-Trust state ledger.

### 🛡️ Core Principles

- **Scoped for Mobile:** We aren't trying to replace your desktop IDE or force you to read 500-line diffs on a 6-inch screen. PocketCoder is built for high-level agent orchestration, planning, and approval.
  
- **Sovereign Security:** No open chat bridges or unauthenticated webhooks. Every sensitive action your agent wants to take is explicitly gated by a human-inspectable log in PocketBase before it executes in an isolated Docker sandbox.
  
- **Unix-Philosophy "Glue":** PocketCoder isn't a massive, bespoke framework. It is intentionally lightweight glue that connects established, battle-tested tools (Docker, Tmux, OpenCode). You can audit the entire system in an afternoon.
  
- **LLM Agnostic:** The execution environment is completely decoupled from the brain. Whether you want to plug in Gemini, Claude, or run a local model via an API, PocketCoder remains your sovereign infrastructure.

## ⚠️ Disclaimer
PocketCoder is an active research project. As a solo developer, I’m building this in the open to share my progress. It is not a commercial product, and there are no support SLAs. If you find a bug, I'd love to hear about it, but please understand I'm moving at my own pace!

## "Featherweight" High-Performance Stats
*(Strictly original PocketCoder code as of Feb 2026)*

| Component | Tech | Lines | Role |
| :--- | :--- | :--- | :--- |
| **backend** | Go | ~1,600 | Sovereign Authority, Asynchronous Relay, and API. |
| **proxy** | Rust | ~700 | Sensory bridge with high-performance TTY streaming. |
| **sandbox/cao** | Python/Bash| ~900 | The terminal-aware orchestrator and TUI bus. |
| **mcp-gateway** | Docker/Node | ~200 | Aggregates and secures external Tool Servers. |
| **CORE TOTAL**| | **~3,400** | **Lean, Fast, Fully Sovereign.** |
