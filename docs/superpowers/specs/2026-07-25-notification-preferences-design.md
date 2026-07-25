# Notification-Type Preferences — Design Spec

## 1. Why

README.md's "Still missing" list names three gaps this session is closing: file browser (spec'd, planned, in progress), diff summaries (spec'd, planned, in progress), and "a settings UI for notification-type preferences (the backend already enforces them)". This spec covers the third.

Grounding in the actual backend (`services/pocketbase/internal/hooks/notifications.go`):

- `notification_rules` is a real PocketBase collection (`schema.json`, `pc_notification_rules`): one row per user (`CREATE UNIQUE INDEX idx_notification_rules_user ON notification_rules (user)`), with a single `rules` JSON field. `isNotificationTypeEnabled` (`notifications.go:194-234`) reads `rules[notifType]`; a missing key, missing record, or unparseable JSON all default to **enabled** (opt-out model, not opt-in).
- A `NotificationRule` freezed model already exists (`lib/domain/models/notification_rule.dart`) and `Collections.notificationRules` is already registered (`lib/domain/models/collections.dart:11`) — but there is no repository, cubit, or screen consuming it. This is a real, currently-inert gap, not speculative work.
- While grounding this spec, a second, more significant gap surfaced: **the app never sends a push notification when an agent finishes replying in a chat.** The only two call sites of `SendPushNotification` in the whole backend are the generic (uncalled) `POST /api/pocketcoder/push` endpoint and `schedule_importer.go:111`'s `"schedule"` type for finished scheduled tasks. The turn-completion path in `coordinator/run.go` (`runLoop`, after `conn.Prompt` returns) never notifies, despite `IsUserOnline` (`notifications.go:237-252`, an SSE-presence check) existing specifically to *suppress* notifications for users actively watching a chat — infrastructure built for, but never wired to, this exact case. Given the product's own pitch ("message an AI agent from your phone... watch it work"), this is the single most valuable notification type and is included in this spec's scope (confirmed with the user).

## 2. Scope

**In scope:**
- Backend: fire a new `"chat_reply"` notification when an agent turn finishes with `StopReasonEndTurn` (`run.go`), reusing the existing `SendPushNotification`/presence-suppression pipeline unchanged.
- Backend: no schema changes — `notification_rules` already supports arbitrary type keys.
- Flutter: `NotificationRuleRepository` (get-or-create against the singleton-per-user row, mirroring `DeviceRepository`'s pattern) + `NotificationRuleCubit`/`State` (mirroring `ToolPermissionsCubit`/`State`) + `NotificationSettingsScreen` with four toggles: **Chat Replies**, **Scheduled Tasks**, **Task Complete**, **Task Errors**.
- New `AppRoutes.configureNotifications` entry in `settings_screen.dart`'s Account section.

**Explicitly out of scope / known limitation:**
- `task_complete` and `task_error` toggles will be **inert but correct**: the rules-map lookup already works for any string key, so toggling them off will correctly suppress a notification of that type *if one is ever sent* — but nothing in the backend sends those two types today (only `"chat_reply"` (new) and `"schedule"` (existing) actually fire). These two toggles are included per explicit user decision to reserve the UI surface now rather than re-touch this screen later; the spec does not invent new callers for them.
- No changes to `devices` collection, device registration flow, or the FCM/ntfy dispatch providers — this spec only touches the *rules* (what to send) layer, not the *dispatch* (how to send) layer.
- No notification history/log UI — toggles only.

## 3. Backend: `chat_reply` on turn completion

### 3.1 New callback type and threading (`coordinator/run.go`)

Add a new callback type next to the existing `OnSessionCreated` (`run.go:51`):

```go
type OnRunFinished func(context.Context, acpsdk.StopReason) error
```

Extend `StartPrompt`'s signature (`run.go:651`) to accept it:

```go
func (c *Coordinator) StartPrompt(chatID, prompt string, resolve ResolveSession, profileFn ProfileFunc, created OnSessionCreated, finished OnRunFinished) (string, error) {
	if err := c.Reserve(chatID); err != nil {
		return "", err
	}
	runID := uuid.NewString()
	runCtx, cancel := context.WithCancel(context.Background())
	accepting := &atomic.Bool{}
	h := &runHandle{runID: runID, cancel: cancel, accepting: accepting}
	c.registerRun(chatID, h)
	go c.runLoop(runCtx, chatID, runID, prompt, h, resolve, profileFn, created, finished)
	return runID, nil
}
```

Thread `finished` through `runLoop`'s signature (`run.go:668`):

```go
func (c *Coordinator) runLoop(runCtx context.Context, chatID, runID, prompt string, h *runHandle, resolve ResolveSession, profileFn ProfileFunc, created OnSessionCreated, finished OnRunFinished) {
```

Call it right after the existing `bridge.Finished` publish loop at the end of `runLoop` (`run.go:744-746`), guarded to fire only on a genuine agent reply — not on a user-initiated cancel. The coordinator package has no logger of its own, and a failed/slow notification dispatch must never fail or delay run teardown, so the callback's error is deliberately swallowed (fire-and-forget, matching `schedule_importer.go:111`'s existing `go SendPushNotification(...)` style):

```go
	for _, e := range bridge.Finished(resp.StopReason) {
		hub.Publish(e)
	}
	if finished != nil && resp.StopReason != acpsdk.StopReasonCancelled {
		_ = finished(runCtx, resp.StopReason)
	}
}
```

`StopReasonCancelled` is excluded because cancellation is always user-initiated via `POST .../session/cancel` (`api/agent.go:170`), which requires the user to already be actively looking at that chat — a notification would be redundant. All other terminal reasons (`end_turn`, `max_tokens`, `max_turn_requests`, `refusal`) represent the agent stopping on its own and are treated as "the agent replied."

### 3.2 Call site (`api/agent.go:93-102`)

Add a fifth closure argument to the existing `service.StartPrompt(...)` call, capturing `app`, `re.Auth.Id`, and `chatID` exactly as the existing `created` closure already does two lines above it:

```go
		runID, err := service.StartPrompt(chatID, prompt,
			func(context.Context) (string, error) { return gooseSessionForChat(app, chatID, re.Auth.Id) },
			func(ctx context.Context) (coordinator.SessionProfile, error) { return buildSessionProfile(app, chatID) },
			func(ctx context.Context, sessionID string) error {
				err := saveGooseSession(ctx, app, chatID, re.Auth.Id, sessionID)
				if err == nil {
					app.Logger().Debug("Goose session mapping created", "chat_id", chatID)
				}
				return err
			},
			func(ctx context.Context, stopReason acpsdk.StopReason) error {
				go hooks.SendPushNotification(app, re.Auth.Id, "PocketCoder", "Your agent replied", "chat_reply", chatID)
				return nil
			})
```

`internal/hooks` is already imported by `internal/api` (`api/schedules.go:40` imports it for the same `SendPushNotification` function) — no new import cycle. The `go` prefix matches `schedule_importer.go:111`'s existing fire-and-forget dispatch style; `hooks.SendPushNotification` internally re-checks `isNotificationTypeEnabled` (so the `"chat_reply"` toggle is honored) and `IsUserOnline` (so a user actively streaming that chat's SSE connection is correctly suppressed — the exact mechanism this notification type was missing before).

### 3.3 Backend tests

New test in `internal/agent/coordinator/run_test.go` (existing file — has prior `StopReason`-related coverage per this session's earlier grounding): assert `StartPrompt`'s `finished` callback is invoked exactly once with `StopReasonEndTurn` on a normal successful prompt, and is **not** invoked when the run is cancelled mid-flight (simulate via the existing cancel test helper, assert `finished` was never called). Both cases use the coordinator test harness's fake `Dial` already present in the file (no new test infrastructure).

## 4. Flutter: settings UI

### 4.1 Repository (`lib/domain/notifications/i_notification_rule_repository.dart`, `lib/infrastructure/notifications/notification_rule_repository.dart`)

```dart
abstract class INotificationRuleRepository {
  Stream<Map<String, bool>> watchRules();
  Future<void> setTypeEnabled(String type, bool enabled);
}
```

New DAO, mirroring `ToolPermissionDao` (`lib/infrastructure/tool_permissions/tool_permission_daos.dart`) exactly:

```dart
@lazySingleton
class NotificationRuleDao extends BaseDao<NotificationRule> {
  NotificationRuleDao(PocketBase pb)
      : super(pb, Collections.notificationRules, NotificationRule.fromJson);
}
```

Repository, mirroring `DeviceRepository`'s get-or-create idiom (`lib/infrastructure/notifications/device_repository.dart:16-51`) — since `notification_rules` is a singleton-per-user row, both methods look it up by `user = "$userId"` first:

```dart
@LazySingleton(as: INotificationRuleRepository)
class NotificationRuleRepository implements INotificationRuleRepository {
  final NotificationRuleDao _dao;
  final PocketBase _pb;

  NotificationRuleRepository(this._dao, this._pb);

  @override
  Stream<Map<String, bool>> watchRules() {
    final userId = _pb.authStore.record?.id;
    if (userId == null) return Stream.value(const {});
    return _dao
        .watch(filter: 'user = "$userId"')
        .map((rows) => rows.isEmpty ? const {} : _asBoolMap(rows.first.rules));
  }

  @override
  Future<void> setTypeEnabled(String type, bool enabled) async {
    return tryMethod(
      () async {
        final userId = _pb.authStore.record?.id;
        if (userId == null) return;

        final existing =
            await _dao.getFullList(filter: 'user = "$userId"');
        final current = existing.isEmpty
            ? <String, bool>{}
            : _asBoolMap(existing.first.rules);
        final merged = {...current, type: enabled};

        if (existing.isEmpty) {
          await _dao.save(null, {'user': userId, 'rules': merged});
        } else {
          await _dao.save(existing.first.id, {'rules': merged});
        }
      },
      RepositoryException.new,
      'setTypeEnabled',
    );
  }

  Map<String, bool> _asBoolMap(dynamic raw) {
    if (raw is! Map) return const {};
    return raw.map((key, value) => MapEntry(key.toString(), value == true));
  }
}
```

`RepositoryException` (already defined, `lib/domain/exceptions.dart:67-74`) is reused rather than adding a new exception type — this matches `DeviceRepository`, the closest existing precedent in the same `notifications/` domain folder, which also uses the generic `RepositoryException` rather than a bespoke one.

`watchRules()` is intentionally not wrapped in `tryMethod` (mirrors `ToolPermissionDao.watch`, which returns a raw `Stream` with errors surfaced through the stream itself, consumed by the cubit's `onError` handler — see 4.2).

### 4.2 Cubit (`lib/application/notifications/notification_rule_cubit.dart`, `notification_rule_state.dart`)

Mirrors `ToolPermissionsCubit`/`ToolPermissionsState` (`lib/application/tool_permissions/`) exactly — sealed union, not `AppCubit<T>`, since this screen has one clear loading/loaded/error shape with no `IUiFlowState`-driven toast feedback needed beyond the existing `error` state (matches `ToolPermissionsState`'s precedent, which also skips `AppCubit<T>`):

```dart
@freezed
sealed class NotificationRuleState with _$NotificationRuleState
    implements IUiFlowState {
  const NotificationRuleState._();

  const factory NotificationRuleState.initial() = _Initial;
  const factory NotificationRuleState.loading() = _Loading;
  const factory NotificationRuleState.loaded(Map<String, bool> rules) = _Loaded;
  const factory NotificationRuleState.error(String message) = _Error;

  @override
  UiFlowStatus get status => when(
        initial: () => UiFlowStatus.idle,
        loading: () => UiFlowStatus.loading,
        loaded: (_) => UiFlowStatus.success,
        error: (_) => UiFlowStatus.failure,
      );

  @override
  Object? get error => maybeWhen(error: (msg) => msg, orElse: () => null);
  @override
  bool get isIdle => status == UiFlowStatus.idle;
  @override
  bool get isLoading => status == UiFlowStatus.loading;
  @override
  bool get isSuccess => status == UiFlowStatus.success;
  @override
  bool get isFailure => status == UiFlowStatus.failure;
  @override
  bool get hasError => error != null;
}
```

```dart
@injectable
class NotificationRuleCubit extends Cubit<NotificationRuleState> {
  final INotificationRuleRepository _repository;
  StreamSubscription? _subscription;

  NotificationRuleCubit(this._repository)
      : super(const NotificationRuleState.initial());

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }

  void watchRules() {
    emit(const NotificationRuleState.loading());
    _subscription?.cancel();
    _subscription = _repository.watchRules().listen(
      (rules) => emit(NotificationRuleState.loaded(rules)),
      onError: (e) {
        logError('NotificationRules: Failed to watch rules', e);
        emit(NotificationRuleState.error(e.toString()));
      },
    );
  }

  Future<void> setTypeEnabled(String type, bool enabled) async {
    try {
      await _repository.setTypeEnabled(type, enabled);
    } catch (e) {
      logError('NotificationRules: Failed to update $type', e);
      emit(NotificationRuleState.error(e.toString()));
    }
  }
}
```

### 4.3 Screen (`lib/presentation/notifications/notification_settings_screen.dart`)

Mirrors `ToolPermissionsScreen`'s structure (`BlocProvider` + `BiosFrame` + `BlocBuilder` + `state.maybeWhen`) with a static list of the four known types instead of a dynamic list, since types here are fixed (not user-creatable, unlike tool-permission rules):

```dart
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  static const _types = [
    ('chat_reply', _NotifType.chatReply),
    ('schedule', _NotifType.schedule),
    ('task_complete', _NotifType.taskComplete),
    ('task_error', _NotifType.taskError),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<NotificationRuleCubit>()..watchRules(),
      child: UiFlowListener<NotificationRuleCubit, NotificationRuleState>(
        child: const _NotificationSettingsView(),
      ),
    );
  }
}
```

The view builds one `Switch` per type inside a single `BiosSection`, defaulting a switch to **on** whenever its key is absent from the loaded `rules` map (`rules[key] ?? true`) — matching the backend's opt-out default in `isNotificationTypeEnabled` exactly, so a freshly-registered user (no `notification_rules` row yet) sees everything on. Labels use new ARB keys:

```json
"notificationSettingsScreenTitle": "NOTIFICATIONS",
"notificationSettingsChatReplyLabel": "CHAT REPLIES",
"notificationSettingsScheduleLabel": "SCHEDULED TASKS",
"notificationSettingsTaskCompleteLabel": "TASK COMPLETE",
"notificationSettingsTaskErrorLabel": "TASK ERRORS"
```

### 4.4 Routing (`app_router.dart`) and settings entry point

New route pair, mirroring `configureToolPermissions` exactly (`app_router.dart:132-133,230,270`):

```dart
// AppRoutes
static const String configureNotifications = '/configure/notifications';
// RouteNames
static const String configureNotifications = 'configureNotifications';
// GoRoute registration, alongside the existing configureToolPermissions/configureSkills block
GoRoute(
  path: AppRoutes.configureNotifications,
  name: RouteNames.configureNotifications,
  builder: (context, state) => const NotificationSettingsScreen(),
),
```

`settings_screen.dart`: add a `('NOTIFICATIONS', '[CONFIGURE]', 'configureNotifications')` entry to the Account section's list (`_sections`, above the `LOGOUT` entry), and a matching `case 'configureNotifications': context.push(AppRoutes.configureNotifications);` in `_navigateTo`.

## 5. Data flow

1. User opens Settings → Account → NOTIFICATIONS → `NotificationSettingsScreen` mounts, `NotificationRuleCubit.watchRules()` streams the current user's `notification_rules` row (or an empty map if none exists yet).
2. Each `Switch` renders `rules[type] ?? true`.
3. Toggling a switch calls `setTypeEnabled(type, value)` → repository get-or-creates the row, merges the one changed key into `rules`, saves. The Drift-backed stream (`BaseDao.watch`) pushes the updated row back through automatically — no manual refetch needed (matches `ToolPermissionsScreen`'s reactive-write pattern).
4. Server-side: when a chat turn ends with a non-cancelled `StopReason`, `api/agent.go`'s new closure fires `hooks.SendPushNotification(..., "chat_reply", ...)`, which checks `isNotificationTypeEnabled` (reads the same `rules` map this screen edits) and `IsUserOnline` before dispatching to the user's registered devices.

## 6. Error handling

- Repository failures surface as `RepositoryException`, caught by the cubit into `NotificationRuleState.error(message)`, rendered the same way `ToolPermissionsScreen` renders its `error` state (`Center` + red `Text`).
- `finished` callback errors in the backend are swallowed (`_ = finished(...)`) — a failed/slow notification dispatch must never fail or delay run teardown, matching the existing fire-and-forget (`go SendPushNotification(...)`) convention.
- A user with no `notification_rules` row (never opened this screen, or a schema-fresh account) is unaffected: `isNotificationTypeEnabled`'s Go-side default and this screen's Dart-side default both resolve missing keys to enabled, so behavior before and after this feature ships is identical until a user explicitly opts out of something.

## 7. Testing

- **Backend:** `run_test.go` additions per §3.3 (2 new cases: `finished` called once with `end_turn`; `finished` not called on cancel). `go build ./... && go vet ./... && go test ./...` must pass.
- **Flutter:**
  - `test/infrastructure/notifications/notification_rule_repository_test.dart` — mirrors `device_repository_test.dart`'s `MockPocketBase`/DAO-mock structure: create-when-absent, update-and-merge-when-present, `watchRules()` mapping.
  - `test/application/notifications/notification_rule_cubit_test.dart` — mirrors `tool_permissions_cubit_test.dart` (if present) or `auth_cubit_test.dart`'s `bloc_test`-style structure: loading→loaded, loading→error, `setTypeEnabled` error path.
  - `test/presentation/notifications/notification_settings_screen_test.dart` — mocked cubit (`MockNotificationRuleCubit extends Mock implements NotificationRuleCubit`, precedented by `MockMcpCubit` in `settings_screen_test.dart`), asserts all 4 switches render with correct default-on state and that tapping one calls `setTypeEnabled` with the right args. Must set `theme: AppTheme.lightTheme` on the test `MaterialApp` (known past bug: a missing theme crashes instead of failing red).
  - `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze`, `flutter test` must all pass.

## 8. Out of scope (explicit)

- Firing `task_complete`/`task_error` from anywhere — no such caller exists today; this spec only makes their toggles present and functionally correct for whenever such a caller is added.
- A "silence during a specific chat" or granular per-chat notification override — global per-type only, matching the existing `notification_rules` schema (no `chat` field on the collection).
- Any change to how devices register or which push provider (ntfy/FCM) is used.
- Notification history or delivery-confirmation UI.
