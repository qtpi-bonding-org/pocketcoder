# Flutter Logic Layer Dead Code Audit

**Scope:** `lib/application/`, `lib/domain/`, `lib/infrastructure/` (hand-written logic only)  
**Date:** 2026-07-21  
**Status:** Migration from OpenCode/Interface → Goose (AG-UI) reasoning path in progress

---

## Executive Summary

The codebase contains **two parallel chat/permission stacks**:
1. **OLD OpenCode/Interface stack** — uses `IChatRepository`, `IHitlRepository`, coldpipe/hotpipe patterns, `opencodeId`
2. **NEW Goose/AG-UI stack** — uses `AgentChatRepository`, `AgentStreamClient`, `AgentActionsApi`, `Conversation`-based state

Both stacks are currently **wired into DI** and both are **referenced in `app.dart`**, suggesting migration is incomplete. The old stack is a candidate for pruning once the new stack fully takes over presentation layer.

---

## Dead Code Candidates

### OLD OPENCODE/INTERFACE CHAT STACK

| File | Candidate | Evidence | Confidence |
|------|-----------|----------|-----------|
| `application/chat/chat_cubit.dart` | `ChatCubit` (OLD) | References `opencodeId`, `coldPipe`, `hotPipe`, `HotPipeEvent`, `getOpencodeId()`. No references from NEW agent stack. Superseded by `application/agent/chat_cubit.dart`. Both versions have same class name — **name collision in DI**. | **HIGH** |
| `application/chat/chat_list_cubit.dart` | `ChatListCubit` | Uses `IChatRepository.fetchChatHistory()`. No equivalent in NEW agent stack. Only 2 total references (definition + DI registration). | **HIGH** |
| `domain/communication/i_chat_repository.dart` | `IChatRepository` | Interface defines `watchColdPipe()`, `watchHotPipe()`, `getOpencodeId()` — all OpenCode terminology. No usage in agent stack. Only used by OLD cubits. | **HIGH** |
| `infrastructure/communication/chat_repository.dart` | `ChatRepository` | Implements OpenCode patterns: subscribes to `pb.realtime` broker on `chats:$chatId` topic, emits `HotPipeEvent` union. Only instantiated via `@LazySingleton(as: IChatRepository)` for OLD stack. | **HIGH** |
| `infrastructure/communication/communication_daos.dart` | `ChatDao`, `MessageDao` | Exported but only used by OLD `ChatRepository`. `SandboxAgentDao` is separate (used by `SandboxAgentRepository`). | **HIGH** |

### OLD HITL (HUMAN-IN-THE-LOOP) PERMISSION/QUESTION STACK

| File | Candidate | Evidence | Confidence |
|------|-----------|----------|-----------|
| `application/permission/permission_cubit.dart` | `PermissionCubit` (OLD) | Uses `Cubit` not `AppCubit`; uses `IHitlRepository`; older pattern. Superseded by `application/agent/permission_cubit.dart` which extends `AppCubit`, uses `AgentChatRepository`, mirrors AG-UI conversational pattern. Both versions have same class name — **name collision in DI**. | **MEDIUM-HIGH** |
| `application/question/question_cubit.dart` | `QuestionCubit` | Uses `Cubit` not `AppCubit`; uses `IHitlRepository.watchQuestions()`; old HITL pattern. Likely superseded by `application/agent/elicitation_cubit.dart` (AG-UI terminology: "elicitation" replaces "questions"). | **MEDIUM-HIGH** |
| `domain/hitl/i_hitl_repository.dart` | `IHitlRepository` | Interface for runtime permission/question workflows: `watchPending()`, `authorize()`, `answerQuestion()`, `evaluatePermission()`. No usage in agent stack. Only used by OLD permission/question cubits. | **MEDIUM-HIGH** |
| `infrastructure/hitl/hitl_repository.dart` | `HitlRepository` | Implements `IHitlRepository`; only instantiated via `@LazySingleton(as: IHitlRepository)` for OLD stack. Calls `PocketCoderApi.evaluatePermission()` with `opencodeId` parameter. | **MEDIUM-HIGH** |

### OLD API CLIENT

| File | Candidate | Evidence | Confidence |
|------|-----------|----------|-----------|
| `infrastructure/core/api_client.dart` | `PocketCoderApi` class | Has `evaluatePermission()` method with `opencodeId` parameter — OpenCode-specific. Only imported by `ChatRepository` (OLD) and `HitlRepository` (OLD). No usage in agent stack. If those repos are removed, this class is orphaned. | **MEDIUM-HIGH** |

---

## Zombie DI Wiring

### Name Collisions (Both Versions Registered)

**Problem:** Two cubits with identical class names are registered as factories. When presentation calls `getIt<ChatCubit>()` or `getIt<PermissionCubit>()`, the resolution order is ambiguous.

#### ChatCubit Collision
```
bootstrap.config.dart (line ~340):
  gh.factory<_i278.ChatCubit>(
      () => _i278.ChatCubit(gh<_i405.IChatRepository>()));  // OLD
  
  gh.factory<_i1066.ChatCubit>(
      () => _i1066.ChatCubit(gh<_i763.AgentChatRepository>()));  // NEW
```

**Usage in app.dart (line 8, 44):**
```dart
import 'package:pocketcoder_flutter/application/chat/chat_cubit.dart';  // OLD
...
BlocProvider(
  create: (context) => getIt<ChatCubit>()..initialize(),
),
```

The import binds to OLD `ChatCubit`, but GetIt has registered both. This works because the import name binds at compile time, but it creates code smell — both are available in DI simultaneously.

#### PermissionCubit Collision
```
bootstrap.config.dart (line ~355):
  gh.factory<_i955.PermissionCubit>(
      () => _i955.PermissionCubit(gh<_i20.IHitlRepository>()));  // OLD
  
  gh.factory<_i225.PermissionCubit>(
      () => _i225.PermissionCubit(gh<_i763.AgentChatRepository>()));  // NEW
```

**Usage in app.dart (line 9, 47):**
```dart
import 'package:pocketcoder_flutter/application/permission/permission_cubit.dart';  // OLD
...
BlocProvider(
  create: (context) => getIt<PermissionCubit>(),
),
```

### Other OLD DI Registrations (Orphaned)
- `ChatListCubit` factory — only 2 references (definition + DI); unclear if presentation uses it
- `QuestionCubit` factory — only 2-3 references total; unclear presentation dependency
- `IHitlRepository` — lazySingleton registration for unused repository
- `IChatRepository` — lazySingleton registration for unused repository

---

## Evidence of Migration State

### Parallel Architecture (NEW Stack Exists, OLD Still Wired)

**NEW Goose/AG-UI Stack (LIVE):**
- ✅ `application/agent/chat_cubit.dart` — uses `AgentChatRepository`, watches reduced `Conversation`
- ✅ `application/agent/permission_cubit.dart` — uses `AgentChatRepository`, accesses `sessionState.permission`
- ✅ `application/agent/elicitation_cubit.dart` — uses `AgentChatRepository`, handles "elicitation" (NEW terminology for questions)
- ✅ `application/agent/session_controls_cubit.dart` — uses `AgentChatRepository`
- ✅ `infrastructure/agent/agent_chat_repository.dart` — real implementation
- ✅ `infrastructure/agent/agent_stream_client.dart` — AG-UI stream client
- ✅ `infrastructure/agent/agent_actions_api.dart` — actions API

**OLD OpenCode/Interface Stack (ORPHANED BUT STILL WIRED):**
- ❌ `application/chat/chat_cubit.dart` — uses `IChatRepository`, coldpipe/hotpipe
- ❌ `application/chat/chat_list_cubit.dart`
- ❌ `application/permission/permission_cubit.dart` — uses `IHitlRepository`
- ❌ `application/question/question_cubit.dart`
- ❌ `infrastructure/communication/chat_repository.dart`
- ❌ `infrastructure/hitl/hitl_repository.dart`

### Zero Cross-Pollination
- Agent stack cubits **never reference** `IChatRepository` or `IHitlRepository`
- Agent stack **never references** `opencodeId`, `coldPipe`, or `hotPipe` terms
- OLD stack **never references** `AgentChatRepository` or `AgentStreamClient`
- No shared business logic between stacks (complete replacement, not gradual migration)

---

## Root Cause Analysis

1. **Incomplete Migration**: The NEW agent stack was added (recent commits: `4fa61187b`, `dac5ee779`) but the OLD stack was not removed from DI
2. **Presentation Layer Coupling**: `app.dart` still instantiates OLD cubits, suggesting presentation hasn't fully migrated (out of scope for this audit, but noted)
3. **DI Misconfiguration**: Both versions of duplicately-named cubits are registered, creating resolution ambiguity

---

## Recommendations

### Phase 1: Verify Presentation Layer
- Audit presentation layer (noted as out of scope here) to confirm which ChatCubit/PermissionCubit are actually used
- If presentation has migrated to agent stack, proceed to Phase 2

### Phase 2: Remove OLD Stack
1. Delete `application/chat/chat_cubit.dart` and `application/chat/chat_list_cubit.dart`
2. Delete `application/permission/permission_cubit.dart` (keep agent/permission_cubit.dart)
3. Delete `application/question/question_cubit.dart` (keep agent/elicitation_cubit.dart)
4. Delete `domain/communication/i_chat_repository.dart`
5. Delete `infrastructure/communication/chat_repository.dart`
6. Delete `domain/hitl/i_hitl_repository.dart`
7. Delete `infrastructure/hitl/hitl_repository.dart`
8. Remove `ChatDao` and `MessageDao` from `infrastructure/communication/communication_daos.dart` (keep `SandboxAgentDao`)
9. Delete `PocketCoderApi.evaluatePermission()` method or entire class if no other callers
10. Remove corresponding DI factory registrations from `bootstrap.config.dart`

### Phase 3: Update app.dart
- Remove imports for OLD chat/permission cubits
- Remove OLD cubit BlocProviders
- Verify no presentation widgets still reference OLD cubits

---

## Summary Table: Candidates for Removal

**Total Dead Code Candidates: 8 classes across 6 files + 1 partial file**

| Category | Count | Files |
|----------|-------|-------|
| Cubits (Application Layer) | 4 | chat_cubit, chat_list_cubit, permission_cubit, question_cubit |
| Interfaces (Domain Layer) | 2 | i_chat_repository, i_hitl_repository |
| Implementations (Infrastructure Layer) | 2 | chat_repository, hitl_repository |
| API Clients | 1 | api_client (PocketCoderApi) |
| DAOs (Partial) | 2 of 3 | ChatDao, MessageDao (keep SandboxAgentDao) |

**Name Collisions Needing Resolution: 2**
- ChatCubit (app/chat vs app/agent)
- PermissionCubit (app/permission vs app/agent)

