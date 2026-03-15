# PocketCoder Goals & Vision

## The One-Liner

**Give anyone with a phone a sovereign AI coding assistant — no terminal required.**

---

## What PocketCoder Is

PocketCoder is a mobile-first control plane for agentic AI coding. It wraps OpenCode (the reasoning engine), Docker (the execution sandbox), and PocketBase (the state hub) into a stack that deploys to a user's own server and is managed entirely from a Flutter app.

The target user ranges from solo developers who want to orchestrate coding agents from their phone, to non-technical users who want a personal AI assistant without giving up control of their data. A side effect of the multi-user model: the owner can invite guests (a designer, a project manager, a curious family member) who get a PocketBase login and can watch the agent work, ask it questions, and review what it built — all from their phone, no terminal or git knowledge required. The barrier to entry for a guest is just a login.

## Core Beliefs

**Sovereignty is the product.** Users own their server, their data, their API keys, and their conversation history. PocketCoder never sees any of it. The only central service is a thin Cloudflare Worker that handles two things users can't self-host: OAuth relay (cloud providers require 3-legged OIDC, no PKCE support) and optional FCM push notifications (requires server-side Firebase credentials). Users who self-host ntfy and deploy manually need zero central infrastructure.

**Mobile is for orchestration, not syntax.** Nobody reads 500-line diffs on a 6-inch screen. PocketCoder is built for the parts of agentic coding that work on mobile: assigning tasks, reviewing plans, approving permissions, switching models, managing API keys, and monitoring progress.

**Minimize custom code.** PocketCoder is intentionally lightweight glue between battle-tested tools. PocketBase handles auth, realtime, and persistence. OpenCode handles reasoning. Docker handles isolation. Tmux handles process management. The less custom code, the fewer bugs, and the easier the audit.

**OpenCode is the brain.** PocketCoder is tightly coupled to OpenCode and its SDK. This is a deliberate choice — OpenCode's architecture (sessions, permissions, streaming events, provider abstraction) maps cleanly to what a mobile control plane needs. The interface service translates between PocketBase collections and OpenCode SDK calls.

**Security through architecture, not trust.** Every tool execution is gated by an explicit permission record in PocketBase before it runs. The agent blocks and waits until the user approves or denies — there is no timeout, no auto-approve, no bypass. This is why push notifications are critical: the agent may be waiting on you while you're away from your phone. This model is the secure alternative to tools like OpenClaw that route system-level commands through unauthenticated chat apps (WhatsApp, Telegram). PocketCoder provides that same mobile convenience, wrapped in a proper authenticated application backed by a zero-trust state ledger.

**Resilient to disconnection.** The user can close the app, lose signal, or be away for hours. PocketBase holds all state — messages, permissions, task status. Nothing is lost. When the user returns, everything is exactly where they left it. Agents that are blocked on permissions simply wait. Agents that completed their work have their results persisted. The phone is a window into the system, not the system itself.

---

## Architecture Summary

Two patterns govern everything:

1. **Runtime behavior (SDK via Interface)**: Actions that affect what OpenCode does *right now* — sending messages, switching models mid-chat, approving permissions. Flutter writes to PocketBase, the interface service subscribes and calls OpenCode's SDK. No restart.

2. **Environment/config (Go Hook + Restart)**: Actions that change what OpenCode *starts with* — API keys, MCP server configs. Flutter writes to PocketBase, a Go hook renders config files to shared volumes and restarts the affected container.

See [architecture-rules.md](./architecture-rules.md) for the full technical reference.

---

## What's Built

| Feature | Status | Pattern |
|---------|--------|---------|
| Chat with OpenCode (send/receive/stream) | Done | SDK via Interface |
| Permission system (approve/deny tool use) | Done | SDK via Interface |
| MCP server management (add/remove/approve) | Done | Go Hook + Restart |
| LLM API key management (any provider) | Done | Go Hook + Restart |
| Model switching (per-chat and global default) | Done | SDK via Interface |
| Provider catalog sync (browse available models) | Done | Sync (read-only) |
| Sandbox subagent key sharing | Done | Shared volume |
| Network isolation (zero-trust Docker networks) | Done | Infrastructure |
| Shell proxy (command validation layer) | Done | Infrastructure |
| Multi-agent orchestration (poco-agents) | Done | Infrastructure |
| Observability dashboard (SQLPage over SQLite) | Done | Infrastructure |
| Push notifications (FCM + ntfy/UnifiedPush) | Done | Go Hook + Cloudflare Worker |
| Deploy button (Linode OAuth + NixOS provisioning) | Done | Flutter IAP + Cloudflare Worker |

## What's Next — Feature Catalog

Everything below is a candidate feature. Priority and ordering are TBD. Features are categorized by what needs Flutter-native engineering vs. what's already covered.

### Already Built (Flutter + Backend)

These exist in some form today:

| Feature | Status | Notes |
|---------|--------|-------|
| Chat / session management | Working | Home screen lists chats, tap to resume, new chat button. Chats and OpenCode sessions are 1:1. `archived` field exists in schema but not yet wired in UI. |
| File viewing | Built, hidden | File viewer reads individual files via `GET /api/pocketcoder/files/{path}`. Nav button currently commented out. No directory listing yet. |
| Permission approval | Working | Real-time via PocketBase subscriptions. |
| Message streaming | Working | Event pump syncs OpenCode streaming parts into PB messages. |

### Already Covered by SQLPage

These are handled by the SQLPage observability dashboard and don't need Flutter engineering right now:

- **Cost & token tracking** — SQLPage queries OpenCode's SQLite DB directly
- **Container logs & health** — SQLPage + existing `/healthz` endpoints
- **Subagent monitoring** — poco-agents exposes status via MCP tools (list_agents, check_agent, snapshot)
- **Resource monitoring** — VPS providers have their own dashboards; SQLPage can surface Docker stats

SQLPage is accessible from a mobile browser. If any of these become high-traffic enough to warrant a native Flutter experience, they can be promoted later.

### Handled by the Agent (Not PocketCoder's Job)

PocketCoder is the OS/framework around the AI CLI. These are things the agent does, not things the UI needs to expose:

- **Git operations** — push, PR creation, deployments. The agent handles these via tool use. The user approves via the permission system. Non-technical users don't interact with git directly.
- **Code review link-outs** — if the agent pushes to GitHub, that's the agent's workflow. PocketCoder doesn't need to be a GitHub client.

### Needs Flutter Engineering

These are genuinely new features that require Flutter + backend work:

#### Diff Summary

OpenCode exposes a structured diff API: `GET /session/{sessionID}/diff?messageID=...` returns `FileDiff[]` with before/after content, addition/deletion counts, and file status. The interface service can sync this into PocketBase via Pattern 1 (SDK via Interface).

The mobile UX is a **summary view**: "Modified 3 files (+47, -12)" with filename list and status badges. Low engineering cost — just sync `FileDiff` metadata into PB and render a list in Flutter. If the user wants to see the full file, the file viewer already exists. No need for a full diff renderer or GitHub link-outs — the agent handles git, not the UI.

#### Agent Profile Management

Browse and configure subagent profiles from Flutter.

- Profiles are defined in the sandbox's `opencode.json` (agent section)
- poco-agents exposes a `profiles` MCP tool that reads them
- View available profiles and their models/descriptions
- Could sync profiles into a PocketBase collection or edit them via a Go hook

#### System Prompt / Instructions

Edit OpenCode's system instructions from mobile.

- Currently read-only mounted via `opencode.json`
- Could allow users to edit custom instructions that get appended to OpenCode's context
- Pattern 2 (Go Hook + Restart) if the instructions are in a config file, or Pattern 1 (SDK) if OpenCode supports runtime instruction updates

### Completed: Zero-Terminal Deploy

Fully implemented. A new user:

1. Downloads PocketCoder from the App Store
2. Taps "Deploy" (one-time IAP)
3. Authenticates with Linode via OAuth
4. PocketCoder provisions a VPS with a NixOS image, deploys the stack, configures DNS/TLS
5. Flutter auto-connects to the new PocketBase instance

**No terminal. No SSH. No config files.**

Infrastructure:
- Cloudflare Worker handles OAuth relay (3-legged OIDC) and FCM push relay
- NixOS custom image uploaded to Linode via API — declarative, reproducible
- Provisioning flow: VPS creation → Docker install → compose deploy → PocketBase bootstrap → certificate setup

### Long-Term: Full Server Lifecycle from Mobile

- **Restart VPS**: Linode API `POST /v4/linode/instances/{id}/reboot` — called from Flutter via Cloudflare Worker. Trivial.
- **Restart individual containers**: Already works via PocketBase → Docker Socket Proxy (`POST /containers/{name}/restart`). Extend to let Flutter trigger restarts for any container in the stack.
- **Full stack update** (`docker compose pull && up -d`): The Docker API has no compose-level operations — it only knows individual containers. Options:
  - **Updater sidecar**: A small container with docker CLI + socket access that exposes an authenticated HTTP endpoint. PocketBase calls it to run `docker compose pull && up -d`. Most flexible, but gives a container full socket access.
  - **Watchtower HTTP API**: Watches for new images and recreates containers on demand. Good for image updates, but doesn't handle compose file changes.
  - **Portainer webhooks**: Full stack redeploy capability, but adds a heavy dependency.
  - Decision deferred. Individual container restart covers most needs initially.
- **Backup/restore** PocketBase data
- **Elestio integration** as an alternative managed deployment option (revenue share model)

---

## Business Model

**AGPLv3 open source.** The code is free and stays free.

Revenue comes from convenience, not lock-in:

| Feature | Price | Why it costs |
|---------|-------|-------------|
| Deploy button (in-app purchase) | One-time fee | Covers the Cloudflare Worker infrastructure + provisioning automation |
| FCM notifications | $0.49/month | Requires a centralized Cloudflare Worker running the FCM relay with Firebase credentials; self-hosted ntfy is the free alternative |
| Linode referral | Passive | Referral link in the deploy flow |
| Elestio revenue share | Passive | Managed hosting option for users who don't want to self-host |

The centralized infrastructure is a single Cloudflare Worker that handles both OAuth and FCM relay. It can't live on the user's server or in the Flutter app because OAuth requires a trusted backend for the client secret, and FCM requires server-side Firebase credentials. This is the minimal possible central footprint.

Users who deploy manually (via `deploy.sh`) and use ntfy pay nothing. The app itself is free. Revenue is entirely opt-in convenience.

---

## Non-Goals

- **Replace desktop IDEs.** PocketCoder is not VS Code on a phone. It's the control plane, not the code editor.
- **Multi-tenant SaaS.** The architecture is single-machine by design. One VPS, one OpenCode container, one Docker Compose stack. But multiple PocketBase users can share the same machine — a family or small team, each with their own chats, API keys, and permissions, all running against the same OpenCode instance with separate sessions. PocketBase scopes the UI experience (your chats, your keys, your model preferences) via user/guest/admin roles, but the agent is shared infrastructure with access to the machine. The trust boundary is "who can log into PocketBase," not "what can each user do once inside." This is "multi-user on one box" — like a family sharing a Linux server — not multi-tenant isolation.
- **Vendor lock-in.** LLM agnostic (any provider with an API key). Cloud agnostic (Linode first, but the stack is just Docker Compose). If you want to migrate to a different VPS, copy the volumes and go.
- **Telemetry or data collection.** No analytics, no usage tracking, no phoning home. The Cloudflare Worker handles OAuth tokens and push notification delivery — it never sees API keys, conversation content, or code.
- **Manual git/deploy from the phone.** The user doesn't type `git push` on a 6-inch screen. The agent handles git operations (commits, pushes, PRs, deployments) as part of its task execution. The user's role is to assign the task and approve the permissions when the agent asks. The permission system already gates these actions — a git push is just another tool call that requires approval.

---

## Landscape (Feb 2026)

Two recent developments validate PocketCoder's thesis:

**OpenClaw** (100k+ GitHub stars in one week, Jan 2026) — an open-source agent that routes commands through WhatsApp, Telegram, Signal, and 20+ chat apps. Proved massive demand for "control your AI agent from your phone." But it's the security model PocketCoder was built to replace: unauthenticated chat bridges for system-level commands. No permission system, no audit trail, no isolation. The creator joined OpenAI in Feb 2026 and handed the project to a foundation.

**Claude Remote Control** (Feb 25, 2026) — Anthropic's official mobile control for Claude Code. Run `claude remote-control` in your terminal, connect from the Claude iOS/Android app. Your local session stays running, the phone is a window.

| | PocketCoder | Claude Remote Control | OpenClaw |
|---|---|---|---|
| Cost | ~$5/month (VPS) | $100-200/month (Max plan) | Free (but your chat app) |
| LLM lock-in | Any provider | Claude only | Any (via config) |
| Laptop required | No (runs on VPS) | Yes (must stay open) | No (self-hosted) |
| Multi-user | Yes (family/team) | One session at a time | Single user |
| Auth & permissions | PocketBase zero-trust | Anthropic account | Chat app login (no permission system) |
| Data sovereignty | Fully self-hosted | Traffic routes through Anthropic | Self-hosted, but commands via chat bridges |
| Setup | One-tap deploy button or `deploy.sh` | One terminal command | Docker + chat app config |

PocketCoder occupies the gap: the sovereignty and cost of self-hosting, the mobile UX that OpenClaw proved people want, and the security that neither OpenClaw nor chat bridges provide.

---

## Community

PocketCoder is built in the open under AGPLv3. The community stance is undecided — for now it's a solo research project. The code is public so others can learn from it, fork it, and build on it. Whether PRs and active community contribution become part of the picture depends on how the project evolves.
