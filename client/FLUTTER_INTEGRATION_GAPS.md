# Flutter Backend Integration Gaps Analysis

**Date:** February 17, 2026  
**Status:** Comparing current Flutter implementation against `FLUTTER_BACKEND_INTEGRATION.md`

---

## Executive Summary

The Flutter client has a solid foundation with proper architecture (clean layers, DI, repositories), but is **missing critical backend connections** needed before UI development can proceed. The gaps fall into three categories:

1. **Custom Endpoint Implementations** (HIGH PRIORITY) - Defined but not used
2. **Data Model Misalignments** (MEDIUM PRIORITY) - Field naming and structure issues
3. **Real-Time & Advanced Features** (MEDIUM PRIORITY) - Partially implemented

---

## 1. CUSTOM ENDPOINT IMPLEMENTATIONS (NOT IMPLEMENTED)

These endpoints are defined in `api_endpoints.dart` but **never called** from repositories.

### 1.1 Permission Evaluation Endpoint
**Status:** ❌ NOT IMPLEMENTED  
**Spec Location:** Section 4 - "Permission Evaluation"  
**Current State:** `PermissionRepository` only watches/updates existing permissions, doesn't evaluate new ones

**What's Missing:**
```dart
// MISSING: Method to call POST /api/pocketcoder/permission
Future<PermissionResponse> evaluatePermission({
  required String permission,
  required List<String> patterns,
  required String chatId,
  required String sessionId,
  required String opencodeId,
  Map<String, dynamic>? metadata,
  String? message,
  String? messageId,
  String? callId,
}) async {
  // Should POST to /api/pocketcoder/permission
  // Create audit record
  // Return {permitted: bool, id: string, status: string}
}
```

**Impact:** Permission requests from OpenCode relay won't be properly recorded/evaluated.

---

### 1.2 SSH Keys Sync Endpoint
**Status:** ❌ NOT IMPLEMENTED  
**Spec Location:** Section 4 - "SSH Keys Sync"  
**Current State:** No SSH key repository method exists

**What's Missing:**
```dart
// MISSING: Method to call GET /api/pocketcoder/ssh_keys
Future<String> getSshKeysForAuthorizedKeys() async {
  // Should GET /api/pocketcoder/ssh_keys
  // Returns raw SSH keys as newline-separated string
  // Used for authorized_keys file population
}
```

**Impact:** SSH key management for device authentication won't work.

---

### 1.3 Artifact/File Access Endpoint
**Status:** ❌ NOT IMPLEMENTED  
**Spec Location:** Section 4 - "Artifact/File Access"  
**Current State:** No artifact access logic exists

**What's Missing:**
```dart
// MISSING: Method to call GET /api/pocketcoder/artifact/{path}
Future<Uint8List> getArtifact(String path) async {
  // Should GET /api/pocketcoder/artifact/{path}
  // Returns file content (binary or text)
  // Validates path safety (no traversal)
}
```

**Impact:** Workspace file access for preview/display won't work.

---

## 2. DATA MODEL MISALIGNMENTS

### 2.1 Chat Model - Field Naming Issues
**Status:** ⚠️ PARTIALLY CORRECT

**Spec Says:**
```
chats collection fields:
- agent_id (string) - OpenCode session ID (NOT a relation)
- agent (relation) - Links to ai_agents
- turn (select) - "user" or "assistant"
- preview (string) - Last message preview
```

**Current Implementation:**
```dart
// client/lib/domain/chat/chat.dart - NEEDS VERIFICATION
// Check if these fields are correctly mapped:
// - agent_id vs agent (confusion between string ID and relation)
// - turn field (may be missing)
// - preview field (may be missing)
```

**Action Required:** Review `chat.dart` and ensure:
- `agentId` (string) for OpenCode session ID
- `agent` (relation) for ai_agents link
- `turn` field for user/assistant turn tracking
- `preview` field for last message preview

---

### 2.2 Message Model - Field Naming Issues
**Status:** ⚠️ PARTIALLY CORRECT

**Spec Says:**
```
messages collection fields:
- agent_message_id (string) - OpenCode message ID
- delivery (select) - "draft", "pending", "sending", "sent", "failed"
- agent (string) - Agent name from OpenCode
- provider_id (string) - Provider identifier
- model_id (string) - Model used
- tokens (json) - {prompt: N, completion: N, reasoning: N}
- finish_reason (string) - Why message ended
```

**Current Implementation in `chat_message.dart`:**
```dart
// FOUND: agent_message_id ✓ (but named opencodeId in code)
// MISSING: delivery field ❌
// FOUND: agent ✓
// FOUND: provider_id ✓
// FOUND: model_id ✓
// FOUND: tokens ✓
// FOUND: finish_reason ✓
```

**Action Required:**
- Add `delivery` field (select: draft/pending/sending/sent/failed)
- Verify `opencodeId` maps to `agent_message_id` in JSON

---

### 2.3 Permission Model - Field Naming Issues
**Status:** ⚠️ PARTIALLY CORRECT

**Spec Says:**
```
permissions collection fields:
- agent_permission_id (string) - OpenCode permission ID
- session_id (string) - Session identifier
- opencode_id (string) - NOT MENTIONED (use agent_permission_id)
- challenge (string) - Challenge token for verification
- source (string) - Where request came from
- usage (relation) - Links to usages
```

**Current Implementation in `permission_request.dart`:**
```dart
// FOUND: agent_permission_id ❌ (named opencodeId instead)
// FOUND: session_id ✓
// MISSING: challenge field ❌
// MISSING: source field ❌
// MISSING: usage relation ❌
```

**Action Required:**
- Rename `opencodeId` to `agentPermissionId` (maps to `agent_permission_id`)
- Add `challenge` field (string)
- Add `source` field (string)
- Add `usage` field (relation to usages)

---

### 2.4 AI Models - Field Naming Issues
**Status:** ⚠️ PARTIALLY CORRECT

**Spec Says:**
```
ai_agents collection fields:
- is_init (bool) - Is this the main/initial agent?
- prompt (relation) - Links to ai_prompts (max 1)
- model (relation) - Links to ai_models (max 1)
- config (string) - Auto-generated YAML bundle (don't set manually)
```

**Current Implementation in `ai_models.dart`:**
```dart
// FOUND: isInit ✓
// FOUND: prompt ✓ (but stored as string, should be relation)
// FOUND: model ✓ (but stored as string, should be relation)
// FOUND: config ✓
// MISSING: mode field ❌ (in current code but not in spec)
```

**Action Required:**
- Verify `prompt` and `model` are properly deserialized as relations
- Remove `mode` field (not in spec)
- Ensure `config` is read-only (auto-generated)

---

### 2.5 SSH Keys Model - Field Naming Issues
**Status:** ❌ NOT IMPLEMENTED

**Spec Says:**
```
ssh_keys collection fields:
- user (relation) - Links to users
- public_key (string) - SSH public key
- device_name (string) - Device identifier
- fingerprint (string) - Key fingerprint
- last_used (date) - Last usage timestamp
- is_active (bool) - Default: true
```

**Current State:** No SSH key model exists

**Action Required:** Create `ssh_key.dart` model with all fields

---

### 2.6 Whitelist Models - Field Naming Issues
**Status:** ⚠️ PARTIALLY CORRECT

**Spec Says:**
```
whitelist_targets:
- active (bool) - Default: true

whitelist_actions:
- permission (string) - Permission type
- kind (select) - "strict" or "pattern"
- value (string) - Pattern value or command ID
- active (bool) - Default: true
```

**Current Implementation:**
```dart
// whitelist_target.dart - NEEDS VERIFICATION
// whitelist_action.dart - NEEDS VERIFICATION
// Check if 'active' field is present
// Check if 'kind' and 'value' fields are present
```

**Action Required:** Verify all fields match spec exactly

---

### 2.7 Usages Model - Field Naming Issues
**Status:** ❌ NOT IMPLEMENTED

**Spec Says:**
```
usages collection fields:
- message_id (string) - Related message ID
- part_id (string) - Message part ID
- model (string) - Model used
- tokens_prompt (number) - Prompt tokens
- tokens_completion (number) - Completion tokens
- tokens_reasoning (number) - Reasoning tokens
- cost (number) - Monetary cost
- status (select) - "in-progress", "completed", "error"
```

**Current State:** No usages model exists

**Action Required:** Create `usage.dart` model with all fields

---

### 2.8 Proposals & SOPs Models - Field Naming Issues
**Status:** ❌ NOT IMPLEMENTED

**Spec Says:**
```
proposals:
- authored_by (select) - "human" or "poco"
- status (select) - "draft" or "approved"

sops:
- signature (string) - SHA256 hash of content
- approved_at (date) - When approved
```

**Current State:** No proposals or SOPs models exist

**Action Required:** Create `proposal.dart` and `sop.dart` models

---

### 2.9 Subagents Model - Field Naming Issues
**Status:** ❌ NOT IMPLEMENTED

**Spec Says:**
```
subagents:
- subagent_id (string) - Unique OpenCode subagent ID
- delegating_agent_id (string) - Parent agent's OpenCode session ID
- tmux_window_id (number) - Tmux window for execution
```

**Current State:** No subagents model exists

**Action Required:** Create `subagent.dart` model with all fields

---

### 2.10 Healthchecks Model - Field Naming Issues
**Status:** ❌ NOT IMPLEMENTED

**Spec Says:**
```
healthchecks:
- name (string) - Service name
- status (string) - "ready", "offline", etc.
- last_ping (date) - Last heartbeat
```

**Current State:** No healthchecks model exists

**Action Required:** Create `healthcheck.dart` model with all fields

---

## 3. REAL-TIME & ADVANCED FEATURES

### 3.1 Hot Pipe Event Handling
**Status:** ⚠️ PARTIALLY IMPLEMENTED

**Current State:**
```dart
// Subscribes to 'logs' realtime channel
// Handles: delta, system, finish events
// Missing: Tool state persistence, error handling
```

**What's Missing:**
- Tool execution state tracking (pending → running → completed/error)
- Error recovery and reconnection logic
- Event buffering for offline scenarios

---

### 3.2 Cold Pipe Message Sync
**Status:** ⚠️ PARTIALLY IMPLEMENTED

**Current State:**
```dart
// Fetches full message list on each update
// Subscribes to messages collection
// Missing: Incremental sync, pagination
```

**What's Missing:**
- Incremental sync (only fetch new/updated messages)
- Pagination support for large chat histories
- Message deduplication

---

### 3.3 Real-Time SSE Connection to OpenCode
**Status:** ❌ NOT IMPLEMENTED

**Spec Says:**
```
Flutter client should connect to OpenCode's SSE at:
http://opencode:3000/event

Event types:
- server.heartbeat
- permission.asked
- message.updated
- message.part.updated
- session.idle
- session.updated
```

**Current State:** No SSE connection exists

**Action Required:**
- Create SSE client for OpenCode relay
- Handle all event types
- Sync events to PocketBase

---

## 4. REPOSITORY INTERFACE GAPS

### 4.1 Missing Methods in Repositories

**PermissionRepository:**
```dart
// MISSING: Method to evaluate permission
Future<PermissionResponse> evaluatePermission({...}) // Uses custom endpoint
```

**ChatRepository:**
```dart
// MISSING: Method to get artifact
Future<Uint8List> getArtifact(String path) // Uses custom endpoint
```

**AuthRepository:**
```dart
// MISSING: Method to get SSH keys
Future<String> getSshKeysForAuthorizedKeys() // Uses custom endpoint
```

**New Repository Needed:**
```dart
// MISSING: UsageRepository for tracking AI usage
// MISSING: HealthcheckRepository for system monitoring
// MISSING: SubagentRepository for subagent management
```

---

## 5. COLLECTION CONSTANTS GAPS

**Status:** ⚠️ PARTIALLY CORRECT

**Current `collections.dart`:**
```dart
// FOUND: Most collections defined
// MISSING: healthchecks collection constant
// ISSUE: Collection IDs may not match backend exactly
```

**Action Required:**
- Verify all collection IDs match backend schema exactly
- Add `healthchecks` collection constant
- Add `pc_usages` collection constant (if missing)

---

## 6. PRIORITY IMPLEMENTATION ORDER

### Phase 1: Critical (Before UI Development)
1. ✅ Fix data model field naming (Section 2)
2. ✅ Create missing models (SSH keys, Usages, Proposals, SOPs, Subagents, Healthchecks)
3. ✅ Implement custom endpoint methods (Section 1)
4. ✅ Add missing repository methods

### Phase 2: Important (For Full Functionality)
5. ⚠️ Implement SSE connection to OpenCode
6. ⚠️ Add incremental sync for messages
7. ⚠️ Add error recovery and reconnection logic

### Phase 3: Nice-to-Have (Polish)
8. 📝 Add request/response interceptors
9. 📝 Add retry logic with exponential backoff
10. 📝 Add offline-first data sync

---

## 7. QUICK CHECKLIST

- [ ] Review and fix `chat.dart` field mappings
- [ ] Review and fix `chat_message.dart` field mappings
- [ ] Review and fix `permission_request.dart` field mappings
- [ ] Review and fix `ai_models.dart` field mappings
- [ ] Create `ssh_key.dart` model
- [ ] Create `usage.dart` model
- [ ] Create `proposal.dart` model
- [ ] Create `sop.dart` model
- [ ] Create `subagent.dart` model
- [ ] Create `healthcheck.dart` model
- [ ] Add `evaluatePermission()` to PermissionRepository
- [ ] Add `getSshKeysForAuthorizedKeys()` to AuthRepository
- [ ] Add `getArtifact()` to ChatRepository
- [ ] Create UsageRepository
- [ ] Create HealthcheckRepository
- [ ] Create SubagentRepository
- [ ] Implement SSE connection to OpenCode
- [ ] Add incremental sync logic
- [ ] Add error recovery logic

---

## 8. KNOWN GOTCHAS FROM SPEC

1. **Field Naming:** Backend uses snake_case (`agent_id`, `agent_message_id`, `agent_permission_id`)
2. **Subagents:** Uses `delegating_agent_id` (string) instead of relation
3. **Auto-Generated Fields:** Don't manually set `config`, `signature`, `challenge`
4. **SSH Keys Endpoint:** Returns raw SSH keys, not JSON
5. **Artifacts:** Read-only, no write endpoint
6. **Real-Time:** PocketBase realtime for DB changes, but OpenCode SSE for agent events

---

## Next Steps

1. Start with Phase 1 implementation
2. Verify each model against backend schema
3. Test custom endpoints with curl before UI development
4. Document any backend schema changes discovered during implementation
