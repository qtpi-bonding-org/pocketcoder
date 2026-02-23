# PocketCoder Backend: Schema & API Reference

This document provides a comprehensive overview of the PocketBase schema and custom API endpoints within the Sovereign Backend. This is the primary reference for Flutter client integration.

## 🏛️ Database Schema (Collections)

All collections are part of the standard PocketBase instance.

### 1. `users` (Auth Collection)
Standard PocketBase auth collection with additional fields.
*   **Fields**:
    *   `role` (Select): `admin`, `agent`, `user`

### 2. `ai_prompts`
Registry of system prompts for AI agents.
*   **Fields**:
    *   `name` (Text, Required)
    *   `body` (Text, Required)

### 3. `ai_models`
Registry of supported AI models and their identifiers.
*   **Fields**:
    *   `name` (Text, Required)
    *   `identifier` (Text, Required): e.g., `gpt-4o`, `claude-3-5-sonnet`

### 4. `ai_agents`
Registry of available AI personas.
*   **Fields**:
    *   `name` (Text, Required)
    *   `is_init` (Bool): If this is a baseline agent.
    *   `prompt` (Relation): Reference to `ai_prompts`.
    *   `model` (Relation): Reference to `ai_models`.
    *   `config` (Text): Bundled JSON configuration for OpenCode.

### 5. `chats`
Represents a conversation between a user and an AI agent.
*   **Fields**:
    *   `title` (Text, Required)
    *   `ai_engine_session_id` (Text): The OpenCode session ID.
    *   `engine_type` (Select): `opencode`, `claude-code`, `cursor`, `custom`
    *   `user` (Relation, Required): Reference to `users`.
    *   `agent` (Relation): Reference to `ai_agents`.
    *   `last_active` (Date)
    *   `preview` (Text): Short preview of the last message.
    *   `turn` (Select): `user`, `assistant`.
    *   `description` (Text)
    *   `archived` (Bool)
    *   `tags` (Text): JSON array of tags.
    *   `created` (Date)
    *   `updated` (Date)

### 6. `messages`
Individual message parts within a chat.
*   **Fields**:
    *   `chat` (Relation, Required): Reference to `chats`.
    *   `role` (Select, Required): `user`, `assistant`, `system`.
    *   `parts` (JSON): The rich content of the message (OpenCode format).
    *   `engine_message_status` (Select): `processing`, `completed`, `failed`, `aborted`.
    *   `user_message_status` (Select): `pending`, `sending`, `delivered`, `failed`.
    *   `ai_engine_message_id` (Text): The OpenCode message ID.
    *   `parent_id` (Text): Parent message reference for threading.
    *   `agent_name` (Text): Name of the agent that sent the message.
    *   `provider_name` (Text): LLM provider.
    *   `model_name` (Text): LLM model.
    *   `cost` (Number)
    *   `tokens` (JSON): Usage statistics.
    *   `error` (JSON): Error details if any.
    *   `finish_reason` (Text)
    *   `metadata` (JSON)
    *   `created` (Date)
    *   `updated` (Date)

### 7. `permissions`
Audit log and gating mechanism for tool executions.
*   **Fields**:
    *   `ai_engine_permission_id` (Text, Required): OpenCode permission request ID.
    *   `session_id` (Text, Required)
    *   `permission` (Text, Required): Name of the tool/verb.
    *   `patterns` (JSON): Targets/Nouns (files, directories).
    *   `metadata` (JSON): Additional context (e.g., the command string).
    *   `status` (Select, Required): `draft`, `authorized`, `denied`.
    *   `message` (Text): Context from the AI.
    *   `source` (Text): `relay-go`, `relay-api`.
    *   `message_id` (Text)
    *   `call_id` (Text)
    *   `challenge` (Text): Unique UUID for the request.
    *   `chat` (Relation): Reference to `chats`.
    *   `approved_by` (Relation): Reference to `users`.
    *   `approved_at` (Date)
    *   `created` (Date)
    *   `updated` (Date)

### 8. `subagents`
Tracking for delegated tasks/sub-sessions.
*   **Fields**:
    *   `subagent_id` (Text, Required)
    *   `delegating_agent_id` (Text, Required): RAW ID for OpenCode compatibility.
    *   `tmux_window_id` (Number)
    *   `chat` (Relation): Reference to `chats` (Lineage).
    *   `delegating_agent` (Relation): Reference to `ai_agents` (Relation).

### 9. `ssh_keys`
Managed SSH public keys for user devices.
*   **Fields**:
    *   `user` (Relation, Required): Reference to `users`.
    *   `public_key` (Text, Required)
    *   `device_name` (Text)
    *   `fingerprint` (Text, Required)
    *   `algorithm` (Text)
    *   `key_size` (Number)
    *   `comment` (Text)
    *   `expires_at` (Date)
    *   `last_used` (Date)
    *   `is_active` (Bool)
    *   `created` (Date)
    *   `updated` (Date)

### 10. `whitelist_targets`
Glob patterns for automated permission approval (Nouns).
*   **Fields**:
    *   `name` (Text, Required)
    *   `pattern` (Text, Required): Glob pattern (e.g., `/workspace/src/**`)
    *   `active` (Bool)

### 11. `whitelist_actions`
Allowed operations/verbs for automated permission approval.
*   **Fields**:
    *   `permission` (Text, Required)
    *   `kind` (Select): `pattern`, `strict`.
    *   `value` (Text): Glob or exact value to match.
    *   `active` (Bool)

### 12. `healthchecks`
System component status registry.
*   **Fields**:
    *   `name` (Text, Required)
    *   `status` (Select, Required): `starting`, `ready`, `degraded`, `offline`, `error`.
    *   `last_ping` (Date)

### 13. `proposals`
Draft governance documents authored by humans or AI.
*   **Fields**:
    *   `name` (Text, Required)
    *   `description` (Text)
    *   `content` (Text, Required)
    *   `authored_by` (Select, Required): `human`, `poco`.
    *   `status` (Select, Required): `draft`, `approved`.

### 14. `sops` (The Sovereign Ledger)
Sealed and signed Standard Operating Procedures. Once a proposal is approved, it is hashed and sealed here.
*   **Fields**:
    *   `name` (Text, Required)
    *   `description` (Text, Required)
    *   `content` (Text, Required)
    *   `signature` (Text, Required): SHA256 of the content.
    *   `approved_at` (Date)
    *   `proposal` (Relation): Lineage link to the original proposal.
    *   `sealed_at` (Date)
    *   `sealed_by` (Text)
    *   `version` (Number)

---

## 🚀 Custom API Endpoints

### 1. `POST /api/pocketcoder/permission`
Used by the Relay or external integrations to evaluate a tool permission request.
*   **Request (JSON)**:
    ```json
    {
      "permission": "string",
      "patterns": ["string"],
      "chat_id": "string",
      "session_id": "string",
      "opencode_id": "string",
      "metadata": {},
      "message": "string",
      "message_id": "string",
      "call_id": "string"
    }
    ```
*   **Response (JSON)**:
    ```json
    {
      "permitted": boolean,
      "id": "string",
      "status": "draft|authorized|denied"
    }
    ```

### 2. `GET /api/pocketcoder/ssh_keys`
Returns all active public keys as a newline-separated list for use by the `sshd` AuthorizedKeysCommand.

### 3. `GET /api/pocketcoder/artifact/{path...}`
Secure proxy for serving files from the sandbox `/workspace` volume.

---

## 📱 Flutter Integration Status & Alignment

The Flutter application (`client/`) is built on a Clean Architecture (Domain/Infrastructure/Presentation) using `flutter_bloc` and the `pocketbase` Dart SDK.

### 🔍 Current Alignment Analysis

| Feature | Backend Implementation (Go) | Flutter Status (Dart) | Alignment |
| :--- | :--- | :--- | :--- |
| **PocketBase SDK** | v0.23+ (Go) | v0.23.2 (Dart) | ✅ Matched |
| **Collection Names** | `chats`, `messages`, etc. | `pc_chats`, `pc_messages` | 🟠 Mismatch (Config) |
| **Message Parts** | OpenCode Rich JSON | Freezed `MessagePart` Union | ✅ Matched |
| **Realtime** | SSE -> PB Collections | `pb.realtime.subscribe('logs')` | ❌ Outdated |
| **Custom APIs** | `/api/pocketcoder/artifact` | `ChatRepository.getArtifact` | ✅ Matched |

### 🛠️ Required Alignment Tasks (Integration Phase)

#### 1. Entity Field Alignment
All models in Phase 1 must match the above schema precisely. This includes renaming fields and ensuring types (e.g., `JSON` -> `Map<String, dynamic>`) are correctly mapped in Dart.

#### 2. Collection Reference Update
Update `lib/infrastructure/core/collections.dart` to use the actual collection names used by the Go backend.

#### 3. Realtime Architecture Shift
Subscribing on the collection level instead of legacy topics.
