# PocketBase Schema Design — Config Layer

**Date:** 2026-05-07  
**Status:** Draft  
**Scope:** End-state schema for collections that configure ACP sessions. Interface reads these to construct `newSession()` calls and react to model/prompt changes. No ACP type coupling — normal relational DB design.

See companion doc: `2026-05-07-pocketbase-acp-schema-design.md` for the ACP layer.

---

## Overview

The config layer answers: *which harness runs, which model it uses, what prompt it gets, which tools it can use, which MCP servers it connects to, and what credentials it needs.*

Interface reads this layer to configure ACP sessions. Flutter reads it to render settings UI. PocketBase hooks write derived artefacts (env files, YAML catalogs) and trigger container restarts when config changes.

---

## Normalization

```
harnesses ──────────────────────┐
     │                          │
     └── harness_models ──── models
              │                  │
              │              provider (text field, not a collection)
              │
        poco_configs          sandbox_configs
              │                    │
        tool_permissions ──────────┘
              │
         mcp_servers
              │
         prompts ◄── skills
              │
        provider_keys   harness_auth
```

---

## Collections

---

### `harnesses`

The agent CLI runtimes. Each is an ACP `AgentSideConnection` implementation.

| Field | PB Type | Notes |
|-------|---------|-------|
| `id` | text (PK) | |
| `name` | text, required | Display name: `"OpenCode"`, `"Claude Code"`, `"Gemini CLI"` |
| `cli_id` | text, required, unique | Container env value: `"opencode"`, `"claude-code"`, `"gemini"` |
| `version` | text | Pinned version: `"1.2.15"` |
| `description` | text | |
| `acp_transport` | select, required | `"websocket" \| "stdio" \| "http"` — how Interface connects via ACP |
| `created` | autodate | |
| `updated` | autodate | |

**Access:** list/view = authenticated; create/update/delete = admin only  
**Index:** unique on `cli_id`

---

### `models`

Canonical LLM models. One row per model regardless of which harnesses support it.  
Provider is a plain text field — no separate collection needed since `harness + model → provider` is deterministic.

| Field | PB Type | Notes |
|-------|---------|-------|
| `id` | text (PK) | |
| `name` | text, required | Canonical name: `"claude-sonnet-4-5"`, `"gemini-2.0-flash"` |
| `display_name` | text | Human label: `"Claude Sonnet 4.5"`, `"Gemini 2.0 Flash"` |
| `provider` | text, required | `"anthropic"`, `"google"`, `"openai"` — matches `provider_keys.provider` |
| `context_window` | number | Token limit, optional |
| `description` | text | |
| `created` | autodate | |
| `updated` | autodate | |

**Access:** list/view = authenticated; create/update/delete = admin only

---

### `harness_models`

Many-to-many join between `harnesses` and `models`.  
Holds the harness-specific model identifier — the same model has different IDs per harness (e.g. OpenCode uses `anthropic/claude-sonnet-4-5`, Claude Code uses `claude-sonnet-4-5`).

| Field | PB Type | Notes |
|-------|---------|-------|
| `id` | text (PK) | |
| `harness` | relation → `harnesses`, required | |
| `model` | relation → `models`, required | |
| `harness_model_id` | text, required | The ID this harness uses when calling the model |
| `is_default` | bool | Default model for this harness |
| `created` | autodate | |
| `updated` | autodate | |

**Access:** list/view = authenticated; create/update/delete = admin only  
**Index:** unique on `(harness, model)`

**Examples:**

| harness | model | harness_model_id |
|---------|-------|-----------------|
| opencode | claude-sonnet-4-5 | `anthropic/claude-sonnet-4-5` |
| claude-code | claude-sonnet-4-5 | `claude-sonnet-4-5` |
| opencode | gemini-2.0-flash | `google/gemini-2.0-flash` |
| gemini | gemini-2.0-flash | `gemini-2.0-flash` |

---

### `provider_keys`

Was: `llm_keys`. User API credentials per LLM provider. Rendered to env files on disk when changed.

| Field | PB Type | Notes |
|-------|---------|-------|
| `id` | text (PK) | |
| `user` | relation → `users`, required | |
| `provider` | text, required | Matches `models.provider`: `"anthropic"`, `"google"`, `"openai"` |
| `env_vars` | json | `{ "ANTHROPIC_API_KEY": "sk-..." }` — flattened to env file |
| `created` | autodate | |
| `updated` | autodate | |

**Access:** list/view = own record or admin; create/update/delete = own record or admin  
**Index:** unique on `(user, provider)`

**Hook:** On create/update/delete → render `/workspace/.opencode/llm.env` + `/llm_keys/llm.env` → restart `pocketcoder-poco`

---

### `harness_auth`

Per-user per-harness authentication state. Covers both API-key harnesses and OAuth/subscription harnesses (e.g. Claude Code Max).

| Field | PB Type | Notes |
|-------|---------|-------|
| `id` | text (PK) | |
| `user` | relation → `users`, required | |
| `harness` | relation → `harnesses`, required | |
| `auth_type` | select, required | `"api_key" \| "oauth"` |
| `status` | select, required | `"unauthenticated" \| "pending" \| "authenticated" \| "expired"` |
| `auth_url` | text | OAuth URL surfaced to Flutter — user opens to complete login |
| `expires_at` | date | When token/session expires |
| `created` | autodate | |
| `updated` | autodate | |

**Access:** list/view/update = own record or admin; create = authenticated  
**Index:** unique on `(user, harness)`

**OAuth flow (e.g. Claude Code subscription):**
1. Poco container calls `claude login` → emits device auth URL
2. Interface captures URL → writes `auth_url`, `status = "pending"` to PocketBase
3. Flutter surfaces URL to user (deep link or browser open)
4. User completes OAuth on device
5. Claude Code CLI stores token on disk in Poco container
6. Interface polls for success → updates `status = "authenticated"`

**Note:** Token itself is stored on disk inside the Poco container, not in PocketBase. PocketBase only tracks state.

---

### `prompts`

Was: `ai_prompts`. System prompt templates assigned to agent configs.

| Field | PB Type | Notes |
|-------|---------|-------|
| `id` | text (PK) | |
| `name` | text, required | |
| `body` | text, required | Full system prompt text |
| `created` | autodate | |
| `updated` | autodate | |

**Access:** list/view = authenticated; create/update/delete = admin only  
**Hook:** On update → cascade re-bundle to all `poco_configs` and `sandbox_configs` referencing this prompt → restart `pocketcoder-poco`

---

### `skills`

Procedural knowledge/instructions agents can invoke via the `skill` tool. Stored in PocketBase so they can be managed without a deploy.

| Field | PB Type | Notes |
|-------|---------|-------|
| `id` | text (PK) | |
| `name` | text, required, unique | Invocation name: `"tdd"`, `"debugging"` |
| `description` | text | One-line summary shown to agent in tool listing |
| `body` | text, required | Markdown content — the full skill instructions |
| `tags` | text | Comma-separated: `"testing,quality"` |
| `active` | bool | Inactive skills are not exposed to agents |
| `created` | autodate | |
| `updated` | autodate | |

**Access:** list/view = authenticated; create/update/delete = admin only

---

### `poco_configs`

Was: `ai_agents` where `mode = "primary"`. Configuration for the Poco (primary) ACP agent. Interface reads this to construct `newSession()`.

| Field | PB Type | Notes |
|-------|---------|-------|
| `id` | text (PK) | |
| `name` | text, required, unique | |
| `harness_model` | relation → `harness_models`, required | Implies both harness and model. Interface reads `harness_model.harness.cli_id` and `harness_model.harness_model_id` for session config |
| `system_prompt` | relation → `prompts` | Passed in `newSession()` |
| `workspace_folders` | json | `WorkspaceFolder[]` passed in ACP `newSession()` |
| `acp_mcp_servers` | json | `McpServer[]` passed in ACP `newSession()` — static servers (poco-agents, opennotebook, pocomemory). Dynamic servers from `mcp_servers` collection are appended at runtime |
| `is_default` | bool | Default config for new chats |
| `created` | autodate | |
| `updated` | autodate | |

**Access:** list/view = authenticated; create/update/delete = admin only  
**Hook:** On update → re-render config bundle → restart `pocketcoder-poco`

---

### `sandbox_configs`

Was: `ai_agents` where `mode = "sandbox_agent"`. Configuration for sandbox sub-agents. Passed to sandbox via MCP or ACP session config.

| Field | PB Type | Notes |
|-------|---------|-------|
| `id` | text (PK) | |
| `name` | text, required, unique | |
| `harness_model` | relation → `harness_models`, required | Which harness + model the sandbox agent runs |
| `system_prompt` | relation → `prompts` | Sandbox agent's system prompt |
| `created` | autodate | |
| `updated` | autodate | |

**Access:** list/view = authenticated; create/update/delete = admin only

---

### `tool_permissions`

Tool-level ACL rules per agent config. `poco_config` and `sandbox_config` are mutually exclusive — exactly one must be set.

| Field | PB Type | Notes |
|-------|---------|-------|
| `id` | text (PK) | |
| `poco_config` | relation → `poco_configs`, nullable | Set if this rule is for Poco |
| `sandbox_config` | relation → `sandbox_configs`, nullable | Set if this rule is for a sandbox agent |
| `tool` | text, required | Tool name: `"bash"`, `"edit"`, `"skill"`, `"poco-agents_*"` |
| `pattern` | text, required | Glob/pattern: `"ls *"`, `"*"` |
| `action` | select, required | `"allow" \| "ask" \| "deny"` |
| `active` | bool | |
| `created` | autodate | |
| `updated` | autodate | |

**Access:** list/view = authenticated; create/update/delete = admin only  
**Index:** unique on `(poco_config, sandbox_config, tool, pattern)`  
**Hook:** On create/update/delete → re-render config → restart `pocketcoder-poco`

---

### `mcp_servers`

Dynamic MCP server approval workflow. Agents request, admin approves, hook renders config files and restarts gateway.

| Field | PB Type | Notes |
|-------|---------|-------|
| `id` | text (PK) | |
| `name` | text, required | Unique server name |
| `status` | select, required | `"pending" \| "approved" \| "denied" \| "revoked"` |
| `requested_by` | text | Session ID of requesting agent |
| `approved_by` | relation → `users`, nullable | |
| `approved_at` | date | |
| `config` | json | User-supplied runtime config parameters |
| `config_schema` | json | JSON Schema defining valid `config` fields |
| `catalog` | text | Catalog reference, default `"docker-mcp"` |
| `image` | text | Docker image, default `mcp/{name}:latest` |
| `acp_transport` | select | `"http" \| "sse" \| "stdio"` — maps to `McpServer` subtype passed to Poco in `newSession()` |
| `reason` | text | Denial reason |
| `created` | autodate | |
| `updated` | autodate | |

**Access:** list/view = authenticated; create = agent or admin; update/delete = admin only  
**Hook:** On status → `"approved"` or `"revoked"` → render `/mcp_config/docker-mcp.yaml` + `/mcp_config/mcp.env` → restart `pocketcoder-mcp-gateway` → notify Poco

---

### `healthchecks`

Service health state. Written by services, read by Flutter.

| Field | PB Type | Notes |
|-------|---------|-------|
| `id` | text (PK) | |
| `name` | text, required | Service name: `"poco"`, `"sandbox"`, `"mcp-gateway"`, `"pocketbase"` |
| `status` | select, required | `"starting" \| "ready" \| "degraded" \| "offline" \| "error"` |
| `last_ping` | date | |

**Note:** Seed data uses `"poco"` not `"opencode"`.

---

### `cron_jobs`

Scheduled prompts. On schedule, creates a message in the target chat which Interface picks up and sends to Poco via ACP.

| Field | PB Type | Notes |
|-------|---------|-------|
| `id` | text (PK) | |
| `name` | text, required | |
| `description` | text | |
| `cron_expression` | text, required | Standard 5-field cron |
| `prompt` | text, required | Message text to send to Poco |
| `session_mode` | select, required | `"existing" \| "new"` |
| `chat` | relation → `chats`, nullable | Target chat if `session_mode = "existing"` |
| `poco_config` | relation → `poco_configs`, nullable | Which Poco config to use if `session_mode = "new"` |
| `user` | relation → `users`, required | |
| `enabled` | bool | |
| `last_executed` | date | |
| `last_status` | text | |
| `last_error` | text | |
| `created` | autodate | |
| `updated` | autodate | |

---

## Additions to ACP Layer Collections

These fields on ACP layer collections are driven by the config layer:

**`chats`** additions:
| Field | PB Type | Notes |
|-------|---------|-------|
| `poco_config` | relation → `poco_configs` | Which Poco config this chat uses (set at chat creation) |
| `harness_model_override` | relation → `harness_models`, nullable | If user switches model mid-chat, overrides `poco_config.harness_model` |

Interface reads `chats.poco_config` to know which harness to connect to and which model to use. If `harness_model_override` is set, that takes precedence for `setSessionConfigOption()` calls.

---

## What Is Removed

| Old collection/field | Replacement |
|----------------------|-------------|
| `ai_agents` | Split into `poco_configs` + `sandbox_configs` |
| `ai_prompts` | Renamed `prompts` |
| `ai_models` | Replaced by `models` + `harness_models` |
| `llm_providers` | Removed — was synced from OpenCode; providers are implicit in `models.provider` |
| `llm_keys` | Renamed `provider_keys` |
| `model_selection` | Removed — model override is `chats.harness_model_override` |
| `sandbox_agents` | Moved to ACP layer as `acp_terminals` |
| `chats.engine_type` | Replaced by `chats.poco_config → poco_configs → harness_models → harnesses` |
| `chats.agent` | Replaced by `chats.poco_config` |

---

## Hook Summary

| Trigger | Output | Container Restarted |
|---------|--------|---------------------|
| `provider_keys` create/update/delete | `/workspace/.opencode/llm.env`, `/llm_keys/llm.env` | `pocketcoder-poco` |
| `mcp_servers.status` → approved/revoked | `/mcp_config/docker-mcp.yaml`, `/mcp_config/mcp.env` | `pocketcoder-mcp-gateway` |
| `tool_permissions` create/update/delete | Poco config bundle re-rendered | `pocketcoder-poco` |
| `poco_configs` update | Config bundle re-rendered | `pocketcoder-poco` |
| `prompts` update | Config bundle re-rendered for all referencing configs | `pocketcoder-poco` |
