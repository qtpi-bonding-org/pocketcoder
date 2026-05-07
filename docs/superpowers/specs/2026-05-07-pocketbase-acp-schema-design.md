# PocketBase Schema Design — ACP Layer

**Date:** 2026-05-07  
**Status:** Draft  
**Scope:** End-state schema for collections derived directly from ACP protocol types. Config layer (harnesses, models, prompts, MCP, Docker) is a separate document.

---

## Overview

The schema is split into two independent layers:

**ACP Layer** (this document) — collections written by the Interface service from ACP protocol callbacks. Fields map 1:1 verbatim to ACP SDK types from `@agentclientprotocol/sdk`. Interface writes these; Flutter reads them.

**Config Layer** (separate document) — collections read by the Interface service to configure ACP sessions. Harness selection, model selection, system prompts, MCP servers, Docker restart triggers. Normal relational DB design, no ACP coupling.

---

## ACP SDK Reference Types

All field names below are verbatim from `@agentclientprotocol/sdk` v0.21.0.

```
SessionId          string
SessionInfoUpdate  { title?, description? }
Role               "user" | "assistant"
ContentBlock       TextContent | ImageContent | ToolCallContent | ResourceLink | EmbeddedResource | Diff
Usage              { inputTokens?, outputTokens?, cacheReadTokens?, cacheWriteTokens? }
Cost               { inputCost?, outputCost?, totalCost? }
RequestId          string
RequestPermissionRequest  { sessionId, id, toolName, input, description?, permissionOptions? }
PermissionOption   { id, kind, title, description? }
PermissionOptionKind  "allow_always" | "allow_once" | "deny"
PermissionOptionId string
SelectedPermissionOutcome  { permissionOptionId }
Terminal           { id, name?, cwd? }
TerminalExitStatus { exitCode }
```

---

## Collections

### `chats`

Written when: Interface receives `SessionInfoUpdate` from `sessionUpdate()` callback, or creates a new session via `newSession()`.

**ACP-derived fields:**

| Field | PB Type | ACP Source | ACP Type |
|-------|---------|------------|----------|
| `acp_session_id` | text | `newSession()` response / `SessionInfoUpdate` | `SessionId` |
| `title` | text | `SessionInfoUpdate.title` | string |
| `description` | text | `SessionInfoUpdate.description` | string |
| `current_role` | select | `SessionInfoUpdate` / last `Role` seen | `Role` = `"user" \| "assistant"` |

**PocketBase infrastructure fields** (not ACP-derived):

| Field | PB Type | Purpose |
|-------|---------|---------|
| `id` | text (PK) | PocketBase record ID |
| `user` | relation → `users` | Chat owner |
| `archived` | bool | Soft delete |
| `created` | autodate | |
| `updated` | autodate | |

> Everything else (harness, model, prompt, MCP config) is in the Config Layer — not on this collection.

**Indexes:** `acp_session_id` (unique)

---

### `messages`

Written when: Interface receives `sessionUpdate()` callback containing new content or status updates.

**ACP-derived fields:**

| Field | PB Type | ACP Source | ACP Type |
|-------|---------|------------|----------|
| `role` | select | `sessionUpdate()` content | `Role` = `"user" \| "assistant"` |
| `content` | json | `sessionUpdate()` content blocks | `ContentBlock[]` |
| `acp_status` | select | session state at time of update | `"streaming" \| "completed" \| "failed" \| "cancelled"` |
| `usage` | json | `sessionUpdate()` usage update | `Usage` = `{ inputTokens?, outputTokens?, cacheReadTokens?, cacheWriteTokens? }` |
| `cost` | json | `sessionUpdate()` cost update | `Cost` = `{ inputCost?, outputCost?, totalCost? }` |

**`content` field structure** — verbatim `ContentBlock` union members Interface will encounter:

```typescript
// TextContent
{ type: "text", text: string, annotations?: Annotations }

// ToolCallContent
{ type: "tool_use", id: ToolCallId, name: string, input: unknown,
  status: "running" | "completed" | "failed" | "cancelled",
  output?: unknown, error?: string }

// Other ContentBlock members stored as-is if received
```

**PocketBase infrastructure fields:**

| Field | PB Type | Purpose |
|-------|---------|---------|
| `id` | text (PK) | PocketBase record ID |
| `chat` | relation → `chats` (cascade delete) | Parent chat |
| `created` | autodate | |
| `updated` | autodate | |

**Indexes:** `chat` (for list queries)

---

### `permissions`

Written when: Interface receives `requestPermission()` callback from Poco.  
Updated when: User approves/denies in Flutter UI.

**ACP-derived fields — request (written by Interface):**

| Field | PB Type | ACP Source | ACP Type |
|-------|---------|------------|----------|
| `acp_request_id` | text | `RequestPermissionRequest.id` | `RequestId` |
| `acp_session_id` | text | `RequestPermissionRequest.sessionId` | `SessionId` |
| `tool_name` | text | `RequestPermissionRequest.toolName` | string |
| `tool_input` | json | `RequestPermissionRequest.input` | unknown |
| `description` | text | `RequestPermissionRequest.description` | string |
| `permission_options` | json | `RequestPermissionRequest.permissionOptions` | `PermissionOption[]` = `{ id, kind, title, description? }[]` |

**ACP-derived fields — response (written by Flutter/user action):**

| Field | PB Type | ACP Source | ACP Type |
|-------|---------|------------|----------|
| `status` | select | derived from user action | `"pending" \| "allow_once" \| "allow_always" \| "deny"` |
| `selected_option_id` | text | `SelectedPermissionOutcome.permissionOptionId` | `PermissionOptionId` |

Interface reads `selected_option_id` to construct `RequestPermissionResponse` to send back to Poco.

**PocketBase infrastructure fields:**

| Field | PB Type | Purpose |
|-------|---------|---------|
| `id` | text (PK) | PocketBase record ID |
| `chat` | relation → `chats` | Parent chat |
| `approved_by` | relation → `users` | Who actioned it |
| `approved_at` | date | When actioned |
| `created` | autodate | |
| `updated` | autodate | |

**Indexes:** `acp_request_id` (unique), `acp_session_id`

**Access rules:**
- Create: agent or admin only (Interface writes on `requestPermission()` callback)
- Update: user, agent, or admin (user sets `status` + `selected_option_id`)
- List/View: authenticated

---

### `acp_terminals`

Written when: Interface receives `createTerminal()` callback from Poco and creates the terminal in sandbox.  
Updated when: terminal exits (`waitForTerminalExit()`) or is killed (`killTerminal()`).

**ACP-derived fields:**

| Field | PB Type | ACP Source | ACP Type |
|-------|---------|------------|----------|
| `acp_terminal_id` | text | `CreateTerminalResponse.terminal.id` | `Terminal.id` (string) |
| `acp_session_id` | text | owning session | `SessionId` |
| `name` | text | `CreateTerminalRequest.name` | string |
| `cwd` | text | `CreateTerminalRequest.cwd` | string |
| `exit_code` | number | `TerminalExitStatus.exitCode` | number |
| `status` | select | lifecycle state | `"running" \| "exited" \| "killed"` |

**PocketBase infrastructure fields:**

| Field | PB Type | Purpose |
|-------|---------|---------|
| `id` | text (PK) | PocketBase record ID |
| `chat` | relation → `chats` | Parent chat |
| `tmux_window_id` | number | Internal sandbox tracking (not ACP) |
| `created` | autodate | |
| `updated` | autodate | |

**Indexes:** `acp_terminal_id` (unique), `acp_session_id`

---

## What Is Explicitly Not in This Layer

These exist in the current schema and are moving to the Config Layer document:

| Current field/collection | Reason |
|--------------------------|--------|
| `chats.engine_type` | Harness selection — Config Layer |
| `chats.agent` relation | Agent config — Config Layer |
| `chats.tags`, `chats.preview` | UI concerns — Config Layer or client-side |
| `messages.user_message_status` | UI state — client-side |
| `messages.parent_id` | OpenCode-specific — drop |
| `messages.error_domain` | OpenCode-specific — fold into `content` |
| `permissions.patterns` | OpenCode-specific — drop |
| `permissions.challenge` | OpenCode-specific — drop |
| `permissions.source` | OpenCode-specific — drop |
| `permissions.message_id` | OpenCode-specific — drop |
| `permissions.call_id` | OpenCode-specific — drop |
| `ai_agents`, `ai_prompts`, `ai_models` | Config Layer |
| `model_selection` | Config Layer |
| `llm_providers` | Config Layer |
| `mcp_servers` | Config Layer |
| `tool_permissions` | Config Layer |
| `sandbox_agents` | Config Layer (replaces with `acp_terminals`) |
| `healthchecks` | Config Layer |

---

## Interface ↔ PocketBase Write Map

Summary of what Interface writes to each collection and when:

| ACP Callback | Collection Written | Operation |
|--------------|--------------------|-----------|
| `newSession()` response | `chats` | Create — set `acp_session_id` |
| `sessionUpdate()` — `SessionInfoUpdate` | `chats` | Update — `title`, `description`, `current_role` |
| `sessionUpdate()` — content | `messages` | Create/update — `content`, `role`, `acp_status` |
| `sessionUpdate()` — `UsageUpdate` | `messages` | Update — `usage`, `cost` on latest assistant message |
| `requestPermission()` | `permissions` | Create — full request fields, `status = "pending"` |
| `permissions.status` change (PB subscription) | → Poco via `RequestPermissionResponse` | Interface reads `selected_option_id`, calls back |
| `createTerminal()` | `acp_terminals` | Create — `acp_terminal_id`, `status = "running"` |
| `waitForTerminalExit()` resolves | `acp_terminals` | Update — `exit_code`, `status = "exited"` |
| `killTerminal()` | `acp_terminals` | Update — `status = "killed"` |
