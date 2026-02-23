# Flutter Backend Integration Tasks

**Status:** Ready for implementation  
**Priority:** CRITICAL - Must complete before UI development  
**Estimated Effort:** 3-4 days

---

## Phase 1: Data Models & Field Fixes (Day 1-2)

### Task 1.1: Fix Chat Model
**File:** `lib/domain/chat/chat.dart`  
**Effort:** 30 min

**Checklist:**
- [ ] Verify `agentId` field exists (string, OpenCode session ID)
- [ ] Verify `agent` field exists (relation to ai_agents)
- [ ] Add `turn` field (select: "user" or "assistant")
- [ ] Add `preview` field (string, last message preview)
- [ ] Add `lastActive` field (DateTime)
- [ ] Run code generation: `flutter pub run build_runner build`
- [ ] Verify JSON serialization matches backend field names

**Test:**
```bash
# Verify model compiles
flutter analyze lib/domain/chat/chat.dart
```

---

### Task 1.2: Fix ChatMessage Model
**File:** `lib/domain/chat/chat_message.dart`  
**Effort:** 45 min

**Checklist:**
- [ ] Verify `agentMessageId` maps to `agent_message_id` in JSON
- [ ] Add `delivery` field (select: "draft", "pending", "sending", "sent", "failed")
- [ ] Verify `agent` field exists (string, agent name)
- [ ] Verify `providerId` field exists
- [ ] Verify `modelId` field exists
- [ ] Verify `tokens` field structure: `{prompt: N, completion: N, reasoning: N}`
- [ ] Verify `finishReason` field exists
- [ ] Run code generation
- [ ] Test JSON deserialization with sample backend response

**Test:**
```dart
// Test deserialization
final json = {
  'id': 'msg_123',
  'chat': 'chat_456',
  'role': 'assistant',
  'agent_message_id': 'opencode_msg_789',
  'delivery': 'sent',
  'agent': 'poco',
  'provider_id': 'openai',
  'model_id': 'gpt-4',
  'finish_reason': 'stop',
  'tokens': {'prompt': 100, 'completion': 50},
};
final msg = ChatMessage.fromJson(json);
assert(msg.agentMessageId == 'opencode_msg_789');
```

---

### Task 1.3: Fix PermissionRequest Model
**File:** `lib/domain/permission/permission_request.dart`  
**Effort:** 45 min

**Checklist:**
- [ ] Rename `opencodeId` to `agentPermissionId` (maps to `agent_permission_id`)
- [ ] Add `challenge` field (string, optional)
- [ ] Add `source` field (string, optional)
- [ ] Add `usage` field (string, optional, relation to usages)
- [ ] Verify `status` field values: "draft", "authorized", "denied"
- [ ] Run code generation
- [ ] Update all references to `opencodeId` → `agentPermissionId`

**Test:**
```dart
// Test field mapping
final json = {
  'id': 'perm_123',
  'agent_permission_id': 'opencode_perm_456',
  'session_id': 'session_789',
  'permission': 'file_write',
  'status': 'draft',
};
final perm = PermissionRequest.fromJson(json);
assert(perm.agentPermissionId == 'opencode_perm_456');
```

---

### Task 1.4: Fix AiAgent Model
**File:** `lib/domain/ai/ai_models.dart`  
**Effort:** 30 min

**Checklist:**
- [ ] Remove `mode` field (not in spec)
- [ ] Verify `isInit` field exists (bool)
- [ ] Verify `prompt` field is properly deserialized (relation)
- [ ] Verify `model` field is properly deserialized (relation)
- [ ] Verify `config` field exists (read-only, auto-generated)
- [ ] Run code generation

**Test:**
```dart
// Verify model structure
final agent = AiAgent(
  id: 'agent_123',
  name: 'poco',
  isInit: true,
  prompt: 'prompt_456',
  model: 'model_789',
);
assert(agent.isInit == true);
```

---

### Task 1.5: Create SshKey Model
**File:** `lib/domain/ssh/ssh_key.dart`  
**Effort:** 30 min

**Checklist:**
- [ ] Create new file with `@freezed` class
- [ ] Fields: `id`, `user` (relation), `publicKey`, `deviceName`, `fingerprint`, `lastUsed`, `isActive`, `created`, `updated`
- [ ] Add JSON serialization with `@JsonKey` for snake_case mapping
- [ ] Run code generation
- [ ] Add to `collections.dart` constant

**Template:**
```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'ssh_key.freezed.dart';
part 'ssh_key.g.dart';

@freezed
class SshKey with _$SshKey {
  const factory SshKey({
    required String id,
    required String user,
    @JsonKey(name: 'public_key') required String publicKey,
    @JsonKey(name: 'device_name') String? deviceName,
    required String fingerprint,
    @JsonKey(name: 'last_used') DateTime? lastUsed,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    DateTime? created,
    DateTime? updated,
  }) = _SshKey;

  factory SshKey.fromJson(Map<String, dynamic> json) => _$SshKeyFromJson(json);
}
```

---

### Task 1.6: Create Usage Model
**File:** `lib/domain/usage/usage.dart`  
**Effort:** 30 min

**Checklist:**
- [ ] Create new file with `@freezed` class
- [ ] Fields: `id`, `messageId`, `partId`, `model`, `tokensPrompt`, `tokensCompletion`, `tokensReasoning`, `cost`, `status`, `created`, `updated`
- [ ] Status enum: "in-progress", "completed", "error"
- [ ] Add JSON serialization with snake_case mapping
- [ ] Run code generation

---

### Task 1.7: Create Proposal Model
**File:** `lib/domain/proposal/proposal.dart`  
**Effort:** 30 min

**Checklist:**
- [ ] Create new file with `@freezed` class
- [ ] Fields: `id`, `name`, `description`, `content`, `authoredBy`, `status`, `created`, `updated`
- [ ] AuthoredBy enum: "human", "poco"
- [ ] Status enum: "draft", "approved"
- [ ] Add JSON serialization
- [ ] Run code generation

---

### Task 1.8: Create SOP Model
**File:** `lib/domain/sop/sop.dart`  
**Effort:** 30 min

**Checklist:**
- [ ] Create new file with `@freezed` class
- [ ] Fields: `id`, `name`, `description`, `content`, `signature`, `approvedAt`, `created`, `updated`
- [ ] Add JSON serialization
- [ ] Run code generation
- [ ] Note: Created automatically by backend, don't create directly

---

### Task 1.9: Create Subagent Model
**File:** `lib/domain/subagent/subagent.dart`  
**Effort:** 30 min

**Checklist:**
- [ ] Create new file with `@freezed` class
- [ ] Fields: `id`, `subagentId`, `delegatingAgentId`, `tmuxWindowId`
- [ ] Add JSON serialization with snake_case mapping
- [ ] Run code generation
- [ ] Note: Created automatically by backend, don't create directly

---

### Task 1.10: Create Healthcheck Model
**File:** `lib/domain/healthcheck/healthcheck.dart`  
**Effort:** 30 min

**Checklist:**
- [ ] Create new file with `@freezed` class
- [ ] Fields: `id`, `name`, `status`, `lastPing`, `created`, `updated`
- [ ] Add JSON serialization with snake_case mapping
- [ ] Run code generation

---

### Task 1.11: Update Collections Constants
**File:** `lib/infrastructure/core/collections.dart`  
**Effort:** 15 min

**Checklist:**
- [ ] Verify all collection IDs match backend exactly (use `pc_` prefix where applicable)
- [ ] Add `healthchecks` constant if missing
- [ ] Verify `usages` collection ID is correct
- [ ] Update `schemaCollections` list with all collections
- [ ] Run analysis to verify no typos

---

## Phase 2: Custom Endpoint Methods (Day 2-3)

### Task 2.1: Add Permission Evaluation to PermissionRepository
**File:** `lib/infrastructure/permission/permission_repository.dart`  
**Effort:** 45 min

**Checklist:**
- [ ] Add method signature:
  ```dart
  Future<PermissionResponse> evaluatePermission({
    required String permission,
    required List<String> patterns,
    required String chatId,
    required String sessionId,
    required String agentPermissionId,
    Map<String, dynamic>? metadata,
    String? message,
    String? messageId,
    String? callId,
  })
  ```
- [ ] Implement POST to `/api/pocketcoder/permission`
- [ ] Create `PermissionResponse` model
- [ ] Handle response: `{permitted: bool, id: string, status: string}`
- [ ] Add error handling with `tryMethod`
- [ ] Add logging

**Test:**
```bash
# Test with curl
curl -X POST http://localhost:8090/api/pocketcoder/permission \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{
    "permission": "file_write",
    "patterns": ["/workspace/src/**"],
    "chat_id": "chat_123",
    "session_id": "session_456",
    "opencode_id": "perm_789"
  }'
```

---

### Task 2.2: Add SSH Keys Method to AuthRepository
**File:** `lib/infrastructure/auth/auth_repository.dart`  
**Effort:** 30 min

**Checklist:**
- [ ] Add method signature:
  ```dart
  Future<String> getSshKeysForAuthorizedKeys()
  ```
- [ ] Implement GET to `/api/pocketcoder/ssh_keys`
- [ ] Return raw SSH keys as newline-separated string
- [ ] Add error handling
- [ ] Add logging

**Test:**
```bash
curl http://localhost:8090/api/pocketcoder/ssh_keys \
  -H "Authorization: Bearer {token}"
```

---

### Task 2.3: Add Artifact Access to ChatRepository
**File:** `lib/infrastructure/chat/chat_repository.dart`  
**Effort:** 30 min

**Checklist:**
- [ ] Add method signature:
  ```dart
  Future<Uint8List> getArtifact(String path)
  ```
- [ ] Implement GET to `/api/pocketcoder/artifact/{path}`
- [ ] Validate path safety (use `ApiEndpoints.isSafeArtifactPath()`)
- [ ] Return binary content
- [ ] Handle errors: 400 (empty path), 403 (path escape), 404 (not found)
- [ ] Add error handling

**Test:**
```bash
curl http://localhost:8090/api/pocketcoder/artifact/README.md \
  -H "Authorization: Bearer {token}"
```

---

### Task 2.5: Create UsageRepository
**File:** `lib/infrastructure/usage/usage_repository.dart`  
**Effort:** 45 min

**Checklist:**
- [ ] Create interface: `lib/domain/usage/i_usage_repository.dart`
- [ ] Implement repository with methods:
  - `getUsages(String messageId)` - GET usages filtered by message
  - `getUsageStats()` - GET all usages with aggregation
  - `trackUsage(Usage usage)` - POST new usage (admin/agent only)
- [ ] Add error handling
- [ ] Register as singleton in DI

---

### Task 2.6: Create HealthcheckRepository
**File:** `lib/infrastructure/healthcheck/healthcheck_repository.dart`  
**Effort:** 45 min

**Checklist:**
- [ ] Create interface: `lib/domain/healthcheck/i_healthcheck_repository.dart`
- [ ] Implement repository with methods:
  - `getHealthchecks()` - GET all healthchecks
  - `watchHealthchecks()` - Stream healthchecks
  - `getServiceStatus(String serviceName)` - GET specific service
- [ ] Add error handling
- [ ] Register as singleton in DI

---

### Task 2.7: Create SubagentRepository
**File:** `lib/infrastructure/subagent/subagent_repository.dart`  
**Effort:** 45 min

**Checklist:**
- [ ] Create interface: `lib/domain/subagent/i_subagent_repository.dart`
- [ ] Implement repository with methods:
  - `getSubagents()` - GET all subagents
  - `watchSubagents()` - Stream subagents
  - `getSubagent(String subagentId)` - GET specific subagent
- [ ] Add error handling
- [ ] Register as singleton in DI

---

## Phase 3: Real-Time & Advanced Features (Day 3-4)

### Task 3.1: Implement SSE Connection to OpenCode
**File:** `lib/infrastructure/realtime/opencode_sse_client.dart`  
**Effort:** 2 hours

**Checklist:**
- [ ] Create SSE client class
- [ ] Connect to `http://opencode:3000/event`
- [ ] Handle event types:
  - `server.heartbeat` - Update healthchecks
  - `permission.asked` - Create permission record
  - `message.updated` - Sync assistant message
  - `message.part.updated` - Trigger message sync
  - `session.idle` - Flip turn to user
  - `session.updated` - Handle session state
- [ ] Implement reconnection logic with exponential backoff
- [ ] Add error handling and logging
- [ ] Create stream interface for consumers

**Dependencies:**
- Add `http` package if not present
- Consider `web_socket_channel` for WebSocket fallback

---

### Task 3.2: Add Incremental Message Sync
**File:** `lib/infrastructure/chat/chat_repository.dart`  
**Effort:** 1.5 hours

**Checklist:**
- [ ] Modify `watchColdPipe()` to track last sync timestamp
- [ ] Implement incremental fetch: only fetch messages created after last sync
- [ ] Add message deduplication logic
- [ ] Implement pagination for large histories
- [ ] Add caching layer for offline support

---

### Task 3.3: Add Error Recovery & Reconnection
**File:** `lib/infrastructure/core/http_client.dart`  
**Effort:** 1.5 hours

**Checklist:**
- [ ] Add request/response interceptors
- [ ] Implement retry logic with exponential backoff
- [ ] Add request timeout configuration
- [ ] Handle token refresh on 401
- [ ] Add circuit breaker pattern for failing endpoints
- [ ] Add comprehensive error logging

---

## Verification & Testing

### Task 4.1: Unit Tests for Models
**File:** `test/domain/models/`  
**Effort:** 1 hour

**Checklist:**
- [ ] Test JSON serialization/deserialization for each model
- [ ] Test field name mapping (snake_case ↔ camelCase)
- [ ] Test enum values
- [ ] Test optional fields
- [ ] Test nested objects

---

### Task 4.2: Integration Tests for Repositories
**File:** `test/infrastructure/repositories/`  
**Effort:** 2 hours

**Checklist:**
- [ ] Test custom endpoint calls with mock responses
- [ ] Test error handling for each endpoint
- [ ] Test stream subscriptions
- [ ] Test pagination and filtering
- [ ] Test real-time updates

---

### Task 4.3: Manual Testing Checklist
**Effort:** 1 hour

**Checklist:**
- [ ] Login and verify token storage
- [ ] Fetch chat history
- [ ] Send message and verify creation
- [ ] Watch permissions stream
- [ ] Evaluate permission via custom endpoint
- [ ] Get SSH keys
- [ ] Resolve session
- [ ] Get artifact
- [ ] Verify all error cases handled

---

## Rollout Checklist

- [ ] All Phase 1 tasks complete and tested
- [ ] All Phase 2 tasks complete and tested
- [ ] All Phase 3 tasks complete and tested
- [ ] Code review completed
- [ ] No analyzer warnings
- [ ] All tests passing
- [ ] Documentation updated
- [ ] Ready for UI development

---

## Notes

- Run `flutter pub run build_runner build` after each model change
- Use `flutter analyze` to check for issues
- Test with actual backend before UI development
- Keep `FLUTTER_INTEGRATION_GAPS.md` updated as tasks complete
- Document any backend schema discrepancies discovered

---

## Timeline

| Phase | Tasks | Effort | Days |
|-------|-------|--------|------|
| 1 | Models & Fields | 5 hours | 1 |
| 2 | Custom Endpoints | 3.5 hours | 1 |
| 3 | Real-Time & Advanced | 5 hours | 1 |
| 4 | Testing & Verification | 4 hours | 1 |
| **Total** | **10 tasks** | **17.5 hours** | **3-4** |

