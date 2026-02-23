# Plan: Sovereign Data Architecture (3-Tier)

This plan outlines the refactoring of the PocketCoder data layer into a structured, type-safe, and offline-first system using `pocketbase_drift`.

## 🏛️ Architecture Overview
1.  **Domain Models**: `freezed` classes (Phase 1 complete).
2.  **DAOs (Data Access Objects)**: Concrete, per-collection classes that map raw PocketBase `RecordModel` JSON to Domain Models using a generic `BaseDao`.
3.  **Aggregate Repositories**: Feature-grouped services that orchestrate one or more DAOs (e.g., `CommunicationRepository` handles both `ChatDao` and `MessageDao`).

## 📁 Spiritual Domain Grouping
We will organize logic into 6 folders under both `lib/domain/` and `lib/infrastructure/`:

- **Communication**: `chats`, `messages`.
- **HumanInTheLoop**: `permissions`, `whitelist_targets`, `whitelist_actions`.
- **Evolution**: `proposals`, `sops`.
- **AiConfig**: `ai_agents`, `ai_models`, `ai_prompts`, `subagents`.
- **Auth**: `users`, `ssh_keys`.
- **Status**: `healthchecks`.

---

## 🛠️ Phase 1.5: Core Infrastructure (Current)

### 1. The `BaseDao<T>`
Create a generic base class in `lib/infrastructure/core/base_dao.dart` that:
- Accepts a collection name and a `fromJson` factory.
- Provides reactive `watchRecords` (Drift-powered).
- Provides standard CRUD (`getOne`, `getFullList`, `save`, `delete`).

### 2. Concrete DAOs
Implement 14 slim DAOs. Example:
```dart
@lazySingleton
class ChatDao extends BaseDao<Chat> {
  ChatDao(PocketBase pb) : super(pb, Collections.chats, Chat.fromJson);
}
```

### 3. Aggregate Repository Refactoring
Refactor `ChatRepository` -> `CommunicationRepository`.
- It will inject `ChatDao` and `MessageDao`.
- It will expose reactive streams of type-safe models to the UI.

---

## ✅ Verification
- Run `flutter test` to ensure existing logic remains intact.
- Verify `build_runner` generates dependency injection correctly.
- Manual test: Create a chat and message, verify SQLite storage via `pocketbase_drift`.

---

## 🚀 Execution Strategy
1. Create `BaseDao`.
2. Implement **Communication** DAOs and Refactor `CommunicationRepository`.
3. Check-In with USER before proceeding to the other 5 domains.
