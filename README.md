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
| Go | 3,324 | PocketBase backend & relay |
| Rust | 596 | Proxy |
| TypeScript | 1,375 | OpenCode tools, plugins & Interface bridge |
| Python | +0 vs upstream | CAO fork (vs [awslabs/cli-agent-orchestrator](https://github.com/awslabs/cli-agent-orchestrator)) |
| Dart | 32,279 | Flutter client (non-generated) |
| Bash | 15,090 | Shell scripts (infra — separate tally) |
| **CORE TOTAL** | **~37,574** | **Lean, Fast, Fully Sovereign.** |

## System Requirements

PocketCoder runs in three configurations. Pick the one that fits your VPS budget:

| | **Core Only** | **+ Knowledge** | **Full Stack** |
| :--- | :--- | :--- | :--- |
| **Containers** | 7 | 11 | 12 |
| **Idle RAM** | ~400 MB | ~1.2 GB | ~1.2 GB |
| **Min RAM** | 2 GB | 4 GB | 4 GB |
| **Rec. RAM** | 4 GB | 4 GB | 8 GB |
| **CPU** | 1 vCPU | 2 vCPU | 2 vCPU |
| **Disk** | 20 GB | 30 GB | 30 GB |
| **Command** | `docker compose up -d` | `--profile knowledge` | `--profile knowledge --profile foss` |

Active agent workloads (OpenCode running tasks, subagent spawns) will spike CPU and memory above idle.

**OS:** Any Linux with Docker (Ubuntu 22.04+ recommended). Also runs on macOS via Docker Desktop for local development.

## Idle Performance Profile

*(Recorded via `docker stats --no-stream` — full stack, all profiles enabled)*

### Core Services (always running)

| Service | Role | CPU % | Memory | PIDs |
| :--- | :--- | ---: | ---: | ---: |
| pocketcoder-opencode | AI engine (OpenCode) | 0.95% | 289 MB | 17 |
| pocketcoder-interface | PB ↔ OpenCode bridge | 0.79% | 34 MB | 17 |
| pocketcoder-pocketbase | Backend + auth | 0.00% | 24 MB | 16 |
| pocketcoder-mcp-gateway | MCP server router | 0.00% | 21 MB | 21 |
| pocketcoder-sandbox | Isolated execution env | 0.00% | 6 MB | 31 |
| pocketcoder-sqlpage | Observability dashboard | 0.25% | 5 MB | 15 |
| pocketcoder-docker-proxy-write | Scoped Docker API proxy | 0.08% | 4 MB | 13 |
| | **Core subtotal** | **~2%** | **~383 MB** | |

### Knowledge Stack (`--profile knowledge`)

| Service | Role | CPU % | Memory | PIDs |
| :--- | :--- | ---: | ---: | ---: |
| pocketcoder-open-notebook | Knowledge base UI + API | 0.41% | 336 MB | 43 |
| pocketcoder-surrealdb | Vector + graph database | 0.00% | 208 MB | 64 |
| pocketcoder-poco-memory | Agent memory MCP server | 0.01% | 162 MB | 24 |
| pocketcoder-open-notebook-mcp | Notebook MCP bridge | 0.19% | 55 MB | 1 |
| | **Knowledge subtotal** | **~1%** | **~761 MB** | |

### Notifications (`--profile foss`)

| Service | Role | CPU % | Memory | PIDs |
| :--- | :--- | ---: | ---: | ---: |
| pocketcoder-ntfy | Self-hosted push notifications | 0.00% | 12 MB | 9 |

### Totals

| Configuration | Containers | Idle RAM | Idle CPU |
| :--- | ---: | ---: | ---: |
| Core only | 7 | ~383 MB | ~2% |
| Core + Knowledge | 11 | ~1,144 MB | ~3% |
| Full stack (all profiles) | 12 | ~1,156 MB | ~3% |

## Third-Party Licenses

PocketCoder's optional knowledge/memory stack uses SurrealDB, which is licensed under BSL 1.1 (not OSI-approved open source). SurrealDB is used as an unmodified runtime dependency. All PocketCoder code remains AGPLv3. If SurrealDB's licensing is a concern, the knowledge and memory features can be disabled via Docker Compose profiles.
