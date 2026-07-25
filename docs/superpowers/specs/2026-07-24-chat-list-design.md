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
@lazySingleton
class ChatDao extends BaseDao<Chat> {
  ChatDao(PocketBase pb) : super(pb, Collections.chats, Chat.fromJson);
}
```

One-liner, same shape as `McpServerDao`/`SandboxAgentDao` — including the
`@lazySingleton` annotation both of those actually carry (`mcp_daos.dart:7`,
`communication_daos.dart:7`); omitting it means `injectable` never registers
`ChatDao` in the `get_it` container and `ChatListRepository`'s constructor
injection fails codegen.

### 3.2 `IChatListRepository` / `ChatListRepository`

`lib/domain/chat/i_chat_list_repository.dart`:

```dart
abstract class IChatListRepository {
  Stream<List<Chat>> watchChats();
  Future<bool> hasAnyChats();
  Future<Chat> createChat({String? title});
  Future<void> archiveChat(String id);
  Future<void> deleteChat(String id);
}
```

`lib/infrastructure/chat/chat_list_repository.dart`
(`@LazySingleton(as: IChatListRepository)`, constructor-injects `ChatDao`
and `IAuthRepository`):

- `watchChats()` → `_dao.watch(filter: 'archived != true', sort: '-last_active')`.
- `hasAnyChats()` → a **network-authoritative, one-shot** check used only to
  decide whether to auto-create the first chat (§3.3/§3.4): `_dao.getFullList(
  filter: 'archived != true', requestPolicy: RequestPolicy.networkOnly)
  .then((l) => l.isNotEmpty)`. Deliberately bypasses the local drift cache
  (`RequestPolicy.networkOnly`, from `pocketbase_drift`'s
  `service.dart:1340-1345` enum) — a cold/empty local cache on a fresh
  install must not be mistaken for "this user truly has zero chats," which
  is exactly the race a cache-inclusive check would hit.
- `createChat({String? title})` → wrapped in `tryMethod`
  (per `client/CLAUDE.md`'s repository convention — every public method
  wrapped, typed exception on failure): reads the current user id off
  `IAuthRepository.currentUserId` (the same getter `AuthRepository.addSshKey`
  already uses to populate a `user` field on create — `auth_repository.dart:
  100-108`), calls `_dao.save(null, {'title': title ?? 'New Chat', 'user': userId})`,
  returns the created `Chat`.
- `archiveChat(id)` → `_dao.save(id, {'archived': true})`.
- `deleteChat(id)` → `_dao.delete(id)`.
- Typed exception: new `ChatListException` in
  `lib/domain/exceptions/chat_list_exception.dart`, following the
  `AgentConfigException`-style shape (`implements Exception`, own file) —
  the codebase has two competing exception conventions (see also the
  centrally-defined `McpException extends DomainException` in
  `lib/domain/exceptions.dart:77`); this spec follows the per-file
  `AgentConfigException` shape since `ChatListCubit` itself mirrors
  `AgentConfigCubit`. Note `ChatException` already exists
  (`lib/domain/exceptions.dart`, used by the conversation view's
  `AgentChatRepository`) — `ChatListException` is a distinct new type for
  the list/create/archive/delete surface, not a reuse or rename. **Also add
  a case for it to `AppExceptionKeyMapper.map()`**
  (`lib/infrastructure/feedback/exception_mapper.dart:12-19`): a
  `ChatListException() => const MessageKey.error('chatList.error')` switch
  arm (matching the existing `_mapChatException`-style shape), plus the
  corresponding `chatListError` key in `app_en.arb` (dot-notation
  `chatList.error` → camelCase `chatListError`, per `client/CLAUDE.md`'s
  localization convention). Without this case, `map()`'s exhaustive switch
  falls through to `_ => null` and `UiFlowListener` falls back to the raw
  `error.toString()` instead of a generic localized message (see §5).

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
- `Future<void> checkEmptyAndMaybeAutoCreate() => tryOperation(...)` — calls
  `_repo.hasAnyChats()`; if `false`, runs the same create-and-signal logic
  as `createAndOpen()` (setting `lastCreatedChatId`); if `true`, returns
  `state.copyWith(status: UiFlowStatus.success, error: null)` with no
  further action — the ordinary `watchChats()` subscription is already
  populating `chats` for that case. See §3.4 for why this replaces a
  widget-lifecycle-based auto-create trigger.

`ChatListState` (`lib/application/chat/chat_list_state.dart`,
`@freezed`, extends `IUiFlowState` per convention):

```dart
@freezed
abstract class ChatListState with _$ChatListState implements IUiFlowState {
  const factory ChatListState({
    @Default([]) List<Chat> chats,
    String? lastCreatedChatId,
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    Object? error,
  }) = _ChatListState;
}
```

(`UiFlowStatus` has exactly four values — `idle, loading, success, failure`
— per `cubit_ui_flow`'s `all_contracts.dart:4-9`; every sibling state, e.g.
`AgentConfigState`, defaults to `idle`, not `initial`.)

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

The cubit is provided via the established `BlocProvider(create: (_) =>
getIt<ChatListCubit>()..watchChats()..checkEmptyAndMaybeAutoCreate())`
cascade — the same pattern `agent_config_screen.dart:37` and
`provider_screen.dart:33` already use for post-construction side effects.
This is deliberately **not** a `StatefulWidget`/`initState`/
`didUpdateWidget` mechanism: `initState` runs before the cubit's stream has
emitted anything, so gating on `state.status` there is meaningless, and
`didUpdateWidget` only fires on the widget's own external constructor
params changing — `ChatListScreen` is instantiated as `const
ChatListScreen()` with none, so it would never fire meaningfully here.

Both cascaded calls run independently and concurrently: `watchChats()`
subscribes to the live list stream (drives `chats` in state as emissions
arrive, including a possibly-stale-empty first emission from a cold local
cache); `checkEmptyAndMaybeAutoCreate()` makes its own one-shot,
network-authoritative decision via `hasAnyChats()` (§3.2) and is what
actually triggers chat creation — **not** a `chats.isEmpty` check against
the (possibly cache-stale) `watchChats()` stream. This is what avoids the
double-create race a stream-emission-based trigger would hit: a returning
user with a cold local drift cache would otherwise see one empty emission
before remote sync fills in their real chats, and a naive
"`status == success && chats.isEmpty`" trigger would spuriously create an
extra chat for them.

Body, driven by `BlocConsumer<ChatListCubit, ChatListState>`:

- `BlocListener` — when `lastCreatedChatId` becomes non-null, `context.push
('${AppRoutes.chat}/$id')`, matching how `AppRoutes.chat` is already
consumed by the existing `/chat/:chatId` route. (`AppNavigation.toChat`
exists at `app_router.dart:319-320` but uses `context.go`, which would drop
the list screen from the back-stack; this spec deliberately uses `push`
instead so returning users can navigate back to the list, and does not
reuse that helper.)
- `chats.isEmpty` (regardless of `status`) → centered loading indicator
  (`TerminalLoadingIndicator`, already used elsewhere, e.g.
  `provider_screen.dart`) — covers both the initial load and the brief
  window before `checkEmptyAndMaybeAutoCreate()`'s create-and-navigate
  completes for a genuinely new user.
- `chats.isNotEmpty` → `ListView.builder` of chat list items: title,
  `preview` (if non-null, else `context.l10n.chatListNoMessages` — a new
  ARB key; per `client/CLAUDE.md`, `MessageKey` is reserved for
  cubit/service-originated programmatic strings, not inline widget display
  text, which every other screen sources from generated `context.l10n.xxx`
  getters, e.g. `chat_screen.dart:121,158,189`), relative timestamp derived
  from `last_active` (a small pure helper, e.g. `formatRelativeTime(DateTime)`,
  not a new dependency — simple `Duration`-based buckets: "just now" /
  "Xm ago" / "Xh ago" / "Xd ago" / absolute date beyond 7 days). Long-press
  opens a `TerminalDialog`-based action sheet (matching the existing
  `TerminalDialog` widget) with Archive/Delete, calling
  `context.read<ChatListCubit>().archive(id)` / `.delete(id)`.

New ARB keys needed in `lib/l10n/app_en.arb` (all inline UI text, via
`context.l10n`, not `MessageKey`): `chatListNewChat` ("+ NEW CHAT" header
action label), `chatListNoMessages` ("No messages yet" preview fallback),
`chatListArchive`/`chatListDelete` (action-sheet labels).

### 3.5 Router change (`app_router.dart`)

Replace the placeholder body at `AppRoutes.chats`'s `GoRoute` (lines 76-88)
with `const ChatListScreen()`. No other route changes — `/chat/:chatId`
is untouched.

## 4. Data flow

Screen mounts → `BlocProvider` creates `ChatListCubit` and cascades
`watchChats()` + `checkEmptyAndMaybeAutoCreate()` (§3.4). `watchChats()`
subscribes to `ChatListRepository.watchChats()` → `ChatDao.watch()` →
`pocketbase_drift`'s reactive `watchRecords()`, which is both offline-first
(reads local drift cache immediately) and live-synced against the backend
(so a scheduled-run-created chat, or an archive/delete from another device,
appears without manual refresh). `checkEmptyAndMaybeAutoCreate()` runs its
own one-shot `networkOnly` fetch to authoritatively decide whether to
create the user's first chat, independent of whatever `watchChats()` has
emitted so far. Creating a chat is a single `create()` call against a
collection whose `createRule` already permits it directly — no custom
backend endpoint, no backend changes at all for this spec.

## 5. Error handling

Standard `tryOperation`/`tryMethod` per `client/CLAUDE.md`: repository
methods throw `ChatListException` (technical detail in the log); cubit
mutations (`createAndOpen`, `archive`, `delete`,
`checkEmptyAndMaybeAutoCreate`) surface failures via `UiFlowStatus.failure`
+ `error`, which `UiFlowListener` (already wired at the app-shell level,
same as every other screen) picks up automatically — no bespoke error UI in
`ChatListScreen` itself. This "generic localized message" behavior is
**conditional on the mapper addition from §3.2**: `UiFlowListener` resolves
the toast text via `AppExceptionKeyMapper.map()`, whose `switch` is
exhaustive over known exception types with `_ => null`; without a
`ChatListException` case added there, `map()` returns `null` and
`UiFlowListener` falls back to the raw `error.toString()` instead of a
generic message.

One explicit edge case: if `checkEmptyAndMaybeAutoCreate()`'s `hasAnyChats()`
network call fails (e.g. genuinely offline on first launch, no cached
chats to fall back to), the cubit emits `UiFlowStatus.failure` and the
screen stays on the loading/empty state with the standard error toast —
it does not retry automatically, since `checkEmptyAndMaybeAutoCreate()`
only ever runs once per `BlocProvider` cascade. The user can pull-to-
refresh (re-running `watchChats()`'s underlying fetch) or, once back
online, the ordinary `+ NEW CHAT` header action still works as a manual
path that doesn't depend on the auto-create check at all.

## 6. Testing

- **`chat_list_repository_test.dart`**: against a fake `ChatDao`/PocketBase
  (matching existing DAO test patterns) — `watchChats()` filters/sorts
  correctly, `hasAnyChats()` uses `RequestPolicy.networkOnly` and returns
  the right bool for empty/non-empty results, `createChat()` sends the
  right body using `IAuthRepository.currentUserId`, `archiveChat`/
  `deleteChat` call through.
- **`chat_list_cubit_test.dart`**: `watchChats()` reduces stream emissions
  into `UiFlowStatus.success`/`failure` correctly; `checkEmptyAndMaybeAutoCreate()`
  creates-and-sets `lastCreatedChatId` when `hasAnyChats()` is `false`, and
  does neither when `true`; a subsequent emission clears
  `lastCreatedChatId`.
- **`chat_list_screen_test.dart`** (widget test): populated list renders
  title/preview/relative-time; long-press → archive/delete menu calls the
  right cubit methods; `BlocListener` navigates exactly once per
  `lastCreatedChatId` change.
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
