# PocketCoder MVP — Target Feature Set

**Audience**: Technical early adopters (can run `deploy.sh`, SSH into a VPS, file GitHub issues)
**Deploy method**: `deploy.sh` + manually enter PocketBase URL in Flutter app
**Goal**: A usable, complete mobile control plane for OpenCode that a developer would actually use daily

---

## MVP Gate: What Must Work End-to-End

Every feature below must work as a complete flow — Flutter UI through PocketBase through backend and back. If any link in the chain is broken, it's not MVP-ready.

### 1. Onboarding & Connection

| Item | Status | What's needed |
|------|--------|---------------|
| Boot screen with health check | Done | - |
| Login with PocketBase URL + email/password | Done | - |
| Token refresh on app reopen | Done | - |

### 2. Chat (Core Loop)

| Item | Status | What's needed |
|------|--------|---------------|
| Create new chat | Done | - |
| List and resume past chats | Done | - |
| Send message → OpenCode processes → streamed response | Done | - |
| Message parts render (text, reasoning, tool use, file) | Done | - |
| Turn indicator (user/assistant) | Done | - |

### 3. Permissions (The Security Promise)

| Item | Status | What's needed |
|------|--------|---------------|
| Permission request appears in UI when agent needs approval | Done | - |
| Approve/deny with single tap | Done | - |
| Decision flows back to OpenCode and agent continues | Done | - |
| Agent questions (non-permission prompts) appear and are answerable | Done | - |

### 4. Notifications (MVP Gate)

| Item | Status | What's needed |
|------|--------|---------------|
| ntfy integration (UnifiedPush) | Done (Flutter) | - |
| FCM relay provider | Done (Go) | Cloudflare Worker not yet deployed |
| Device registration with PocketBase | Done (Flutter) | - |
| Permission request fires push notification | Done (Go hook) | `notifications.go` triggers on `permissions` create, checks user presence, dispatches to all devices |
| Presence suppression (don't push if user is in app) | Done (Go) | Checks PocketBase SSE broker for active connections |
| Deep link header (`pocketcoder://`) | Done (Go) | Set in ntfy `Click` header |
| Tap notification → opens app to relevant screen | Needs verification | Deep link URL is set; need to verify Flutter handles `pocketcoder://` scheme |

The entire notification backend is implemented — trigger, presence check, multi-device dispatch, both ntfy and FCM providers. The only question is whether the Flutter deep link handler works end-to-end.

### 5. LLM Configuration

| Item | Status | What's needed |
|------|--------|---------------|
| API key management (save/delete per provider) | Backend done | **Flutter UI needed** — no dedicated screen for managing `llm_keys` |
| Browse available providers and models | Backend done (provider sync) | **Flutter UI needed** — read `llm_providers` collection, show in a list |
| Model switching (global default) | Backend done | **Flutter UI needed** — write to `llm_config` collection |
| Model switching (per-chat) | Backend done | **Flutter UI needed** — model selector in chat screen |

This is the feature we just built on the backend. The interface service and Go hooks are tested. Flutter needs screens to expose it.

### 6. MCP Server Management

| Item | Status | What's needed |
|------|--------|---------------|
| View pending MCP server requests | Done | - |
| Approve/deny MCP server with config | Done | - |
| View active MCP servers | Done | - |

### 7. System Health

| Item | Status | What's needed |
|------|--------|---------------|
| Container health status | Done | - |
| Observability dashboard | Done | - |
| System checks screen | Done | - |

---

## MVP Stretch (Nice to Have, Not Blocking)

These would make the MVP better but aren't required for launch:

| Feature | Status | Notes |
|---------|--------|-------|
| Diff summary ("Modified 3 files +47 -12") | Not started | Low effort if we sync `FileDiff` metadata. Nice context in chat. |
| Artifact/file viewer (re-enable) | Built, hidden | Nav button commented out. Just needs to be re-enabled and linked from diff summary. |
| SSH terminal from Flutter | Done | Already works with xterm + dartssh2. Power user feature. |
| Whitelist management | Done | Already fully functional. |
| Theme switching | Infra exists | Minor UI work to expose toggle. |

---

## What's NOT in MVP

These are explicitly deferred past MVP:

- **Deploy button** — early adopters use `deploy.sh`
- **FCM notifications** — ntfy is sufficient for technical users
- **Agent profile management** — edit markdown files via SSH for now
- **System prompt editing** — edit `opencode.json` via SSH for now
- **SOP management** — hardcoded demo data, not critical
- **Cloud deployment UI** — Linode OAuth screens exist but execution deferred
- **Zero-terminal onboarding** — requires Cloudflare Worker + provisioning automation

---

## MVP Checklist Summary

```
DONE:
  [x] Boot screen + health check
  [x] Login with custom PocketBase URL
  [x] Chat: create, list, resume, stream
  [x] Permissions: approve/deny in real-time
  [x] Questions: answer agent prompts
  [x] MCP: approve/deny/view servers
  [x] System health: container status
  [x] Observability: container metrics
  [x] Whitelist: action rules + targets
  [x] SSH terminal
  [x] ntfy device registration

NEEDS WORK (Flutter only):
  [ ] LLM keys: Flutter screen for managing API keys
  [ ] LLM providers: Flutter screen for browsing providers/models
  [ ] LLM config: Flutter UI for model switching (global + per-chat)

VERIFY (backend done, need e2e test):
  [ ] Notifications: permission → ntfy push → phone → tap deep link → app opens to right screen
  [ ] Full e2e flow: deploy.sh → connect Flutter → chat → permission → approve → agent continues
  [ ] Restart resilience: container restart → reconnect → state preserved
  [ ] Multi-session: multiple chats with separate OpenCode sessions
```

---

## Estimated Scope

**Backend: Done.** All Go hooks, interface service features, PocketBase collections, notification dispatch, and Docker infrastructure are built and tested.

**Remaining work is Flutter only:**
1. **Three LLM management screens** — key CRUD, provider/model browser, model switcher. Standard PocketBase CRUD screens following the existing MCP management screen pattern. Backend is fully tested with 23 BATS integration tests.
2. **Verify notification deep linking** — the `pocketcoder://` scheme is set in the ntfy push. Need to confirm Flutter handles it and navigates to the right screen.
3. **Verify e2e flows** — deploy → connect → chat → permission → notification → approve on phone → agent continues.
