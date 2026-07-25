# Chat List & New Chat Flow — Design

## 1. Why this exists

The Flutter app's `/chats` landing route (`app_router.dart:76-88`) is a hardcoded
placeholder: `Text('Chat list — pending rebuild on AG-UI')`. There is no way
anywhere in the app to list existing chats or create a new one — no
`createChat`/`listChats` method exists in any repository. This is the app's
entire front door: after boot → onboarding, every user is redirected to
`/chats` and dead-ends there. The only way to reach a working conversation
today is a push-notification tap.

The conversation screen itself (`ChatScreen`, `ChatCubit`,
`AgentChatRepository`, streaming, permission/elicitation cards, tool calls)
is fully built and functional — it only needs a real `chatId` to navigate to.
This spec builds the missing layer: list chats, create a chat, get the user
into `ChatScreen`.

## 2. Current state (grounded)

- **Backend**: the `chats` PocketBase collection already supports this
  directly via the client SDK — no backend changes needed.
  - `createRule: "@request.auth.id != ''"` — any authenticated user can
    create a chat.
  - `listRule` scopes to `user = @request.auth.id || role = 'agent' ||
    role = 'admin'`.
  - Required fields: `title` (text), `user` (relation). Everything else
    (`last_active`, `preview`, `turn`, `description`, `archived`, `tags`,
    `poco_config`, `harness_model_override`) is optional.
  - The backend's schedule importer (`schedule_importer.go`, a 60s
    background poll) already creates `chats` records server-side for
    scheduled Goose runs — so chats can appear from outside the app's own
    UI actions while a user has the list open.
- **`Chat` domain model** (`lib/domain/models/chat.dart`) already exists,
  generated from schema, fields match exactly.
- **`lib/infrastructure/chat/`** exists as an empty directory — nothing
  built yet.
- **`ag_ui_widgets_flutter`** (the local package at
  `/Users/aicoder/Documents/ag_ui_widgets_flutter`, pinned in `pubspec.yaml`
  at the exact commit checked out locally — no drift) only provides
  single-conversation-timeline rendering (`Conversation` model, reducer,
  transport, the `AgUiChat` widget already used by `ChatScreen`). It has no
  chat-list/conversation-list component; the list screen is built from
  scratch on top of the plain PocketBase SDK.
- **Offline/realtime persistence is automatic and collection-agnostic**:
  `external_module.dart` initializes PocketBase once as
  `$PocketBase.database(...)` and caches the *entire* schema
  (`pb_schema.json`) into `pocketbase_drift` via `client.cacheSchema()`.
  Any `BaseDao<T>` subclass touching `chats` gets offline-first local
  storage and reactive `watchRecords()` for free — no per-collection setup.
  This is the same mechanism `McpServerDao`/`ToolPermissionDao` already use.

## 3. Architecture

New files, following the DAO → Repository → Cubit → Screen layering used
throughout the app (e.g. `mcp_daos.dart` → `McpServerRepository` →
`McpCubit` → `McpManagementScreen`), and the `AppCubit<T>` +
`cubit_ui_flow` state convention from `client/CLAUDE.md`, mirrored directly
off `AgentConfigCubit` (a cubit that both watches a collection stream *and*
performs one-shot mutations):

### 3.1 `ChatDao` (`lib/infrastructure/chat/chat_dao.dart`)

```dart
class ChatDao extends BaseDao<Chat> {
  ChatDao(PocketBase pb) : super(pb, Collections.chats, Chat.fromJson);
}
```

One-liner, same shape as `McpServerDao`/`SandboxAgentDao`.

### 3.2 `IChatListRepository` / `ChatListRepository`

`lib/domain/chat/i_chat_list_repository.dart`:

```dart
abstract class IChatListRepository {
  Stream<List<Chat>> watchChats();
  Future<Chat> createChat({String? title});
  Future<void> archiveChat(String id);
  Future<void> deleteChat(String id);
}
```

`lib/infrastructure/chat/chat_list_repository.dart`
(`@LazySingleton(as: IChatListRepository)`):

- `watchChats()` → `_dao.watch(filter: 'archived != true', sort: '-last_active')`.
- `createChat({String? title})` → wrapped in `tryMethod`
  (per `client/CLAUDE.md`'s repository convention — every public method
  wrapped, typed exception on failure): reads the current user id off
  `PocketBase.authStore.record?.id` (same pattern `SshTerminalCubit._syncPublicKey`
  uses), calls `_dao.save(null, {'title': title ?? 'New Chat', 'user': userId})`,
  returns the created `Chat`.
- `archiveChat(id)` → `_dao.save(id, {'archived': true})`.
- `deleteChat(id)` → `_dao.delete(id)`.
- Typed exception: new `ChatListException` in
  `lib/domain/exceptions/chat_list_exception.dart`, following the existing
  per-domain exception pattern (`McpException`, `AgentConfigException`, etc.).

### 3.3 `ChatListCubit` (`lib/application/chat/chat_list_cubit.dart`)

`@injectable class ChatListCubit extends AppCubit<ChatListState>`, mirroring
`AgentConfigCubit`:

- `watchChats()` — manual stream subscription (not `tryOperation`, since
  `watchChats()` returns a `Stream`, not a `Future`), explicitly emitting
  `state.copyWith(chats: chats, status: UiFlowStatus.success)` per emission
  and `UiFlowStatus.failure` on stream error, cancelled in `close()`.
- `Future<void> createAndOpen({String? title}) => tryOperation(...)` —
  calls `_repo.createChat(title: title)`, then returns
  `state.copyWith(status: UiFlowStatus.success, error: null,
  lastCreatedChatId: chat.id)` directly (`tryOperation`'s callback returns
  the full next state, not just a status — see `AgentConfigCubit`'s
  `saveConfig`/`deleteConfig` for the same shape). The screen reads
  `lastCreatedChatId` off the emitted state to navigate (§3.4);
  `tryOperation` itself returns `Future<void>`, not the id.
- `Future<void> archive(String id) => tryOperation(...)`.
- `Future<void> delete(String id) => tryOperation(...)`.

`ChatListState` (`lib/application/chat/chat_list_state.dart`,
`@freezed`, extends `IUiFlowState` per convention):

```dart
@freezed
abstract class ChatListState with _$ChatListState implements IUiFlowState {
  const factory ChatListState({
    @Default([]) List<Chat> chats,
    String? lastCreatedChatId,
    @Default(UiFlowStatus.initial) UiFlowStatus status,
    Object? error,
  }) = _ChatListState;
}
```

`lastCreatedChatId` is a one-shot signal: the screen's `BlocListener` reads
it to navigate, then the cubit clears it (`copyWith(lastCreatedChatId: null)`)
on the next emission so back-navigation doesn't re-trigger the push.

### 3.4 `ChatListScreen` (`lib/presentation/chat/chat_list_screen.dart`)

`PocketCoderShell` (matching every other pillar screen), `activePillar:
NavPillar.chats`, header action `+ NEW CHAT` via `extraHeaderActions:
[TerminalAction(label: ..., onTap: () => context.read<ChatListCubit>()
.createAndOpen())]` — the same `extraHeaderActions`/`TerminalAction`
mechanism `ChatScreen` already uses for its header buttons (`PocketCoderShell`
and `TerminalAction` are both existing, real widgets — no new header
pattern introduced).

Body, driven by `BlocConsumer<ChatListCubit, ChatListState>`:

- `BlocListener` — when `lastCreatedChatId` becomes non-null, `context.push
('${AppRoutes.chat}/$id')`, matching how `AppRoutes.chat` is already
consumed by the existing `/chat/:chatId` route.
- `status == loading && chats.isEmpty` → centered loading indicator
  (`TerminalLoadingIndicator`, already used elsewhere, e.g.
  `provider_screen.dart`).
- `status == success && chats.isEmpty` → **auto-creates the first chat**:
  a `didUpdateWidget`/`initState`-driven one-time call to
  `context.read<ChatListCubit>().createAndOpen()` the first time an empty
  list is observed post-load (guarded by a local `bool _autoCreateAttempted`
  so it only fires once, not on every rebuild) — no user tap needed, per
  the approved design.
- `chats.isNotEmpty` → `ListView.builder` of chat list items: title,
  `preview` (if non-null, else a localized "No messages yet" string via
  `MessageKey`), relative timestamp derived from `last_active` (a small
  pure helper, e.g. `formatRelativeTime(DateTime)`, not a new dependency —
  simple `Duration`-based buckets: "just now" / "Xm ago" / "Xh ago" /
  "Xd ago" / absolute date beyond 7 days). Long-press opens a
  `TerminalDialog`-based action sheet (matching the existing
  `TerminalDialog` widget) with Archive/Delete, calling
  `context.read<ChatListCubit>().archive(id)` /
  `.delete(id)`.

### 3.5 Router change (`app_router.dart`)

Replace the placeholder body at `AppRoutes.chats`'s `GoRoute` (lines 76-88)
with `const ChatListScreen()`. No other route changes — `/chat/:chatId`
is untouched.

## 4. Data flow

Screen mounts → `ChatListCubit.watchChats()` called from `initState` →
subscribes to `ChatListRepository.watchChats()` → `ChatDao.watch()` →
`pocketbase_drift`'s reactive `watchRecords()`, which is both offline-first
(reads local drift cache immediately) and live-synced against the backend
(so a scheduled-run-created chat, or an archive/delete from another device,
appears without manual refresh). Creating a chat is a single `create()` call
against a collection whose `createRule` already permits it directly — no
custom backend endpoint, no backend changes at all for this spec.

## 5. Error handling

Standard `tryOperation`/`tryMethod` per `client/CLAUDE.md`: repository
methods throw `ChatListException` (technical detail in the log, generic
localized message to the user); cubit mutations (`createAndOpen`, `archive`,
`delete`) surface failures via `UiFlowStatus.failure` + `error`, which
`cubit_ui_flow`'s existing toast/error plumbing (already wired at the
`MaterialApp`/`UiFlowListener` level, same as every other screen) picks up
automatically — no bespoke error UI in `ChatListScreen` itself.

One explicit edge case: if the auto-create-on-empty call itself fails (e.g.
offline with no cached chats), the screen shows the loading/empty state
with the standard error toast rather than looping — `_autoCreateAttempted`
stays `true` so it does not retry on every rebuild; the user can pull-to-
refresh or tap `+ NEW CHAT` manually to retry.

## 6. Testing

- **`chat_list_repository_test.dart`**: against a fake `ChatDao`/PocketBase
  (matching existing DAO test patterns) — `watchChats()` filters/sorts
  correctly, `createChat()` sends the right body with the current user id,
  `archiveChat`/`deleteChat` call through.
- **`chat_list_cubit_test.dart`**: `watchChats()` reduces stream emissions
  into `UiFlowStatus.success`/`failure` correctly; `createAndOpen()` sets
  `lastCreatedChatId`; a subsequent emission clears it.
- **`chat_list_screen_test.dart`** (widget test): empty state triggers
  exactly one `createAndOpen()` call (not on every rebuild); populated list
  renders title/preview/relative-time; long-press → archive/delete menu
  calls the right cubit methods.
- **Manual**: simulator walkthrough — onboarding → auto-created first chat
  → send a message → back to list → new chat's preview/timestamp visible
  → tap `+ NEW CHAT` → second chat created and opened → archive the first
  one from the list → confirm it disappears.

## 7. Out of scope

- Search/filter over chats.
- Renaming a chat's title from the list screen (title is set once at
  creation; renaming, if wanted, is a small follow-up on the conversation
  screen itself, not this spec).
- Anything from Spec 2 (SOP screen wiring, settings logout/server-url,
  sandbox-agent screen), Spec 3 (terminal/files/ssh-key screens), or the
  still-unscoped Spec 4 (questions/harness_auth/notification_rules).
