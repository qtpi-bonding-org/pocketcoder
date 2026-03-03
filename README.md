# PocketCoder

**PocketCoder** is a personal research lab and an experiment in building a "Sovereign AI." It is a minimalist, local-first coding assistant designed with the philosophy of **Alpine Linux**: a tiny surface area that leverages the power of standard Unix tools.

I am building this as a solo developer because I believe that the most powerful tools shouldn't need a complex "Enterprise" footprint. Instead, PocketCoder uses high-leverage "giant's shoulders" like **PocketBase**, **Tmux**, and **OpenCode** to keep the custom glue code to an absolute minimum.

## 🧪 The Experiment: A Secure Bridge for Agentic Workflows

The AI ecosystem is moving fast, and we are seeing two distinct patterns emerge in how people interact with autonomous agents. PocketCoder is an experiment aimed at finding the secure middle ground between them.

**1. The "Antigravity" Workflow on the Go**

Recent tools like Google Antigravity have shown that for *certain parts* of development, a high-level "Mission Control" workflow is highly effective. You aren't typing syntax; you are reviewing agent plans, looking at task lists, and approving executions. While intense, nitty-gritty coding will always belong on a desktop, PocketCoder aims to bring the orchestration subset of your workflow to your phone. It allows you to assign tasks, review plans, and approve deployments securely while away from your keyboard.

**2. A Secure Alternative to OpenClaw**

For non-technical users and developers alike, the appeal of tools like OpenClaw is obvious: the ability to message a personal AI agent from your phone and have it execute real-world tasks. However, routing system-level commands through unauthenticated chat apps (like WhatsApp or Telegram) is a well-documented security nightmare. PocketCoder provides that same mobile convenience, but wraps it in a proper, authenticated application backed by a Zero-Trust state ledger.

### How PocketCoder Compares (March 2026)

| | **PocketCoder** | **Claude Remote Control** | **OpenClaw** |
|:---|:---|:---|:---|
| **Cost** | ~$10/mo (VPS only) | $100–200/mo (Max plan) + VPS if headless | ~$10/mo (VPS) |
| **Permission approval from phone** | Built-in, real-time approve/deny | [Not implemented](https://github.com/anthropics/claude-code/issues/29438) — must watch screen | No permission system |
| **Push notifications on block** | ntfy (free) + FCM, with presence suppression | [Not implemented](https://github.com/anthropics/claude-code/issues/29438) — community workarounds via ntfy | N/A |
| **Laptop required** | No — runs on VPS (laptop mode also works) | [DIY via SSH + tmux](https://github.com/anthropics/claude-code/issues/29479), not officially supported | No — self-hosted |
| **LLM provider** | Any (bring your own API key) | Claude only | Any |
| **Multi-user** | Yes (family/team via PocketBase) | Single session | Single user |
| **Auth model** | PocketBase zero-trust ledger | Anthropic account | Chat app login |
| **Data sovereignty** | Fully self-hosted, no telemetry | Traffic routes through Anthropic | Self-hosted, but commands via chat bridges |
| **Security model** | Every tool call gated by explicit approval | Permission modes, no mobile override | [No approval by default](https://www.crowdstrike.com/en-us/blog/what-security-teams-need-to-know-about-openclaw-ai-super-agent/) — bolted-on after [security incidents](https://www.giskard.ai/knowledge/openclaw-security-vulnerabilities-include-data-leakage-and-prompt-injection-risks) |
| **Mobile app** | Native Flutter (iOS + Android + F-Droid) | Claude iOS/Android app | 20+ chat apps (WhatsApp, Telegram, etc.) |
| **MCP management** | Approve/deny/view from phone | Via terminal only | Via config files |

### 🛡️ Core Principles

- **Scoped for Mobile:** We aren't trying to replace your desktop IDE or force you to read 500-line diffs on a 6-inch screen. PocketCoder is built for high-level agent orchestration, planning, and approval.
  
- **Sovereign Security:** No open chat bridges or unauthenticated webhooks. Every sensitive action your agent wants to take is explicitly gated by a human-inspectable log in PocketBase before it executes in an isolated Docker sandbox.
  
- **Unix-Philosophy "Glue":** PocketCoder isn't a massive, bespoke framework. It is intentionally lightweight glue that connects established, battle-tested tools (Docker, Tmux, OpenCode). You can audit the entire system in an afternoon.
  
- **LLM Agnostic:** The execution environment is completely decoupled from the brain. Whether you want to plug in Gemini, Claude, or run a local model via an API, PocketCoder remains your sovereign infrastructure.

## ⚠️ Disclaimer
PocketCoder is an active research project. As a solo developer, I’m building this in the open to share my progress. It is not a commercial product, and there are no support SLAs. If you find a bug, I'd love to hear about it, but please understand I'm moving at my own pace!

## 🚀 Quick Start

The only system prerequisite is **Docker**. Everything else is completely containerized.

1. **Deploy the Infrastructure**  
   Run the deployment script from the root directory. This will auto-generate secure passwords in a local `.env` file and prompt you for your Gemini API key:
   ```bash
   ./deploy.sh
   ```

2. **Launch the Client**  
   You can run the Flutter frontend in an incognito web browser, iOS simulator, or Android device/emulator using the provided helper scripts:
   ```bash
   # Run in a clean incognito Chrome instance
   ./client/scripts/run_chrome_incognito.sh
   
   # Or run on an iOS Simulator
   ./client/scripts/run_ios.sh
   
   # Or run on an Android Device/Emulator
   ./client/scripts/run_android.sh
   ```

## "Featherweight" High-Performance Stats
*(Strictly original PocketCoder code — generated by `scripts/generate_audit.sh`)*

| Language | LoC | Component |
| :--- | ---: | :--- |
| Go | 5,384 | PocketBase backend & relay |
| Rust | 558 | Proxy |
| TypeScript | 322 | OpenCode MCP tools & plugins |
| Python | +1,781 vs upstream | CAO fork (vs [awslabs/cli-agent-orchestrator](https://github.com/awslabs/cli-agent-orchestrator)) |
| Dart | 33,098 | Flutter client (non-generated) |
| Bash | 919 | Shell scripts (infra — separate tally) |
| **CORE TOTAL** | **~41,143** | **Lean, Fast, Fully Sovereign.** |

## System Requirements

| | Minimum | Recommended |
| :--- | :--- | :--- |
| **RAM** | 2 GB | 4 GB |
| **CPU** | 1 vCPU | 2 vCPU |
| **Disk** | 20 GB | 40 GB |
| **OS** | Any Linux with Docker | Ubuntu 22.04+ |

Idle memory footprint is ~750 MiB across all containers. Active agent workloads will spike higher.

## Idle Performance Profile
*(Recorded via `docker stats --no-stream` on idle state)*

| CONTAINER ID | NAME | CPU % | MEM USAGE / LIMIT | MEM % | NET I/O | BLOCK I/O | PIDS |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 83b9557a8244 | pocketcoder-sandbox | 0.38% | 334.3MiB / 7.655GiB | 4.26% | 145kB / 395kB | 80.6MB / 23MB | 48 |
| 386cb090d97f | pocketcoder-pocketbase | 0.11% | 20.8MiB / 7.655GiB | 0.27% | 3.01MB / 3.2MB | 184kB / 227MB | 20 |
| 5490325ebae6 | pocketcoder-opencode | 1.13% | 287.1MiB / 7.655GiB | 3.66% | 2.22MB / 1.91MB | 766kB / 5.76MB | 17 |
| 311ee7332b16 | pocketcoder-interface | 0.88% | 26.3MiB / 7.655GiB | 0.34% | 1.33MB / 664kB | 426kB / 0B | 16 |
| 3243ca2d6495 | pocketcoder-sqlpage | 0.42% | 25.26MiB / 7.655GiB | 0.32% | 1.25kB / 0B | 21MB / 0B | 16 |
| 5a6c4b15e336 | pocketcoder-docker-proxy-write | 0.00% | 30.27MiB / 7.655GiB | 0.39% | 48.8kB / 42.4kB | 13MB / 12.3kB | 13 |
| b21a1246046b | pocketcoder-mcp-gateway | 0.00% | 26.06MiB / 7.655GiB | 0.33% | 524kB / 14.8kB | 111kB / 0B | 24 |
