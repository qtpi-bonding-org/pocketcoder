# Pocketcoder Builder Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Switch `chat_screen.dart` from wiring `AgUiChat`'s five builder slots by hand to
`StackedChatBuilders` (from `ag_ui_widgets_flutter` — see the companion plan
`ag_ui_widgets_flutter/docs/superpowers/plans/2026-07-26-reusable-builder-extensions-plan.md`,
which this plan depends on), while preserving every piece of pocketcoder's terminal visual
identity (COMMANDER/POCO/THINKING labels, diff rendering, typed elicitation fields) — deleting
pocketcoder's own duplicated implementations of whatever the package now does generically, and
keeping pocketcoder's own widgets only where the package's generic content genuinely can't match
(distinct permission deny action, elicitation decline/cancel).

**Architecture:** One `StackedChatStyle` config carries pocketcoder's theme colors/fonts plus a
`roleHeaderBuilder` that reproduces the existing COMMANDER/POCO/THINKING label row. One
`ChatActionCallbacks` wires `onPermissionOptionSelected`/`onElicitationRespond` to the existing
cubits and sets `permissionCardBuilder`/`elicitationCardBuilder` to pocketcoder's existing
`PermissionCard`/`ElicitationCard` (kept, since they need decline/cancel and a distinct deny
action the generic cards don't support). `toolCallOverrides`/`toolRequestOverrides` are left empty
— the package's generic tool-call card now renders diffs, and pocketcoder has no client-executed
tool feature yet, so the generic `toolRequestBuilder` fallback card is a strict improvement over
today's silent `SizedBox.shrink()`.

**Tech Stack:** Dart/Flutter, `ag_ui_widgets_flutter` (bumped pin), `flutter_bloc`, existing cubits.

## Global Constraints

- **Do not start this plan until the companion package plan has landed and pushed** — confirm
  `git -C /Users/aicoder/Documents/ag_ui_widgets_flutter log --oneline -1 origin/main` shows the
  `chore: bump to 0.4.0 for builder extension release` commit before Task 1.
- Follow `/Users/aicoder/Documents/pocketcoder/client/CLAUDE.md`: never use `!`; cubits only, not
  Blocs; state extends `IUiFlowState`.
- Follow this repo's root `CLAUDE.md` model-generation-pipeline note if any PocketBase schema
  changes — not applicable to this plan (no schema touched).
- Preserve every assertion in `test/presentation/chat/permission_card_test.dart` and
  `elicitation_card_test.dart` — these widgets are kept, not replaced, only re-wired to a different
  call site (`ChatActionCallbacks.permissionCardBuilder`/`.elicitationCardBuilder` instead of
  `AgUiChat.permissionBuilder`/`.elicitationBuilder` directly). Their rendered output must not change.
- Run `flutter analyze` and `flutter test` after every task; both must be clean before moving on.
- Per this repo's root `CLAUDE.md`: after this plan's final task, actually run the app (see the
  `run` skill) and visually confirm the golden path — send a message, see a tool call with a diff,
  trigger a permission request — since automated tests don't cover visual fidelity.

---

### Task 1: Bump the dependency pin

**Files:**
- Modify: `client/packages/pocketcoder_flutter/pubspec.yaml`

**Interfaces:**
- Consumes: the pushed HEAD commit of `ag_ui_widgets_flutter` after its `0.4.0` release (Task 9 of
  the companion plan).

- [ ] **Step 1: Get the new commit hash**

Run: `git -C /Users/aicoder/Documents/ag_ui_widgets_flutter rev-parse origin/main`

- [ ] **Step 2: Update the pin**

In `client/packages/pocketcoder_flutter/pubspec.yaml`, under the `ag_ui_widgets_flutter:` git
dependency, replace the `ref:` value with the hash from Step 1.

- [ ] **Step 3: Resolve and verify the version landed**

Run: `cd client/packages/pocketcoder_flutter && flutter pub get`
Then: `grep -A2 "^  ag_ui_widgets_flutter:" ../../pubspec.lock` (from `client/`) and confirm
`version: "0.4.0"`.

- [ ] **Step 4: Run analyze — expect new breakage from nothing yet, or none**

Run: `flutter analyze lib`
Expected: PASS (the pin bump alone doesn't break anything until Task 4 changes builder wiring —
`0.4.0`'s new fields are all additive/optional).

- [ ] **Step 5: Commit**

```bash
git add client/packages/pocketcoder_flutter/pubspec.yaml client/pubspec.lock
git commit -m "chore: bump ag_ui_widgets_flutter to 0.4.0"
```

---

### Task 2: Extract the role-header row into a reusable function

Pulls the label/icon row currently inlined in `_Bubble` (`chat_message_bubble.dart`) out into a
standalone function so it can be passed as `StackedChatStyle.roleHeaderBuilder` in Task 3, without
duplicating the COMMANDER/POCO/THINKING logic.

**Files:**
- Modify: `lib/presentation/chat/chat_message_bubble.dart`

**Interfaces:**
- Produces: `Widget pocketcoderRoleHeader(BuildContext context, {required String role, required bool isSentByMe, required bool isReasoning})`
  — consumed by Task 3's style config.

- [ ] **Step 1: Read the current `_Bubble` header row**

Re-read `lib/presentation/chat/chat_message_bubble.dart` — `_Bubble.build` starts around line 97;
the `Row` containing the `Icon` + `Text(label, ...)` is around lines 125-144 (re-check the exact
lines when implementing — line numbers shift as earlier tasks/tests are added to this file).

- [ ] **Step 2: Extract it as a top-level function**

Add to `chat_message_bubble.dart` (this becomes the file's only export other than the constants —
`ChatMessageBubble`, `ChatStreamMessageBubble`, and `_Bubble` are deleted in Task 5 once the
generic builders replace them, but keep them in place for now so this step's extraction doesn't
break the still-in-use call sites until Task 4 flips the wiring):

```dart
/// Renders pocketcoder's COMMANDER/POCO/THINKING label row: an icon + small
/// uppercase label whose color/text depend on who's speaking and whether
/// this is a reasoning aside. Passed as `StackedChatStyle.roleHeaderBuilder`
/// so both completed and streaming messages get identical header treatment.
Widget pocketcoderRoleHeader(
  BuildContext context, {
  required String role,
  required bool isSentByMe,
  required bool isReasoning,
}) {
  final colors = context.colorScheme;
  final terminalColors = context.terminalColors;
  final accent = isReasoning
      ? terminalColors.warning
      : isSentByMe
          ? terminalColors.user
          : colors.primary;
  final label = isSentByMe ? 'COMMANDER' : (isReasoning ? 'THINKING' : 'POCO');

  return Padding(
    padding: EdgeInsets.only(bottom: AppSizes.space),
    child: Row(
      children: [
        Icon(
          isSentByMe ? Icons.person_outline : Icons.smart_toy_outlined,
          size: 14,
          color: accent,
        ),
        HSpace.x1,
        Text(
          label,
          style: TextStyle(
            color: accent,
            fontFamily: AppFonts.bodyFamily,
            fontSize: AppSizes.fontTiny,
            fontWeight: AppFonts.heavy,
            letterSpacing: 2,
          ),
        ),
      ],
    ),
  );
}
```

Note: this ignores the `role` param's raw value (`'user'`/`'assistant'`) in favor of `isSentByMe`/
`isReasoning`, matching `_Bubble`'s existing logic exactly — pocketcoder only has two authors
today, so `role` isn't needed for the label choice, but the param stays in the function signature
since it's part of `roleHeaderBuilder`'s package-defined shape.

- [ ] **Step 3: Run analyze**

Run: `flutter analyze lib/presentation/chat/chat_message_bubble.dart`
Expected: PASS (pure addition, nothing calls the new function yet)

- [ ] **Step 4: Commit**

```bash
git add client/packages/pocketcoder_flutter/lib/presentation/chat/chat_message_bubble.dart
git commit -m "refactor: extract pocketcoderRoleHeader for reuse as roleHeaderBuilder"
```

---

### Task 3: Build pocketcoder's `StackedChatStyle` + `ChatActionCallbacks`

**Files:**
- Create: `lib/presentation/chat/pocketcoder_chat_builders.dart`
- Test: `test/presentation/chat/pocketcoder_chat_builders_test.dart`

**Interfaces:**
- Consumes: `pocketcoderRoleHeader` (Task 2), `PermissionCard`, `ElicitationCard` (existing,
  unmodified), `PermissionCubit`/`ElicitationCubit`'s existing `.authorize`/`.deny`/`.submit`
  methods (via `context.read` inside the returned widgets — unchanged, since `PermissionCard`/
  `ElicitationCard` already read their own cubits internally rather than taking callbacks).
- Produces: `StackedChatBuilders pocketcoderChatBuilders(BuildContext context, {required void Function(String, {String? optionId, bool cancelled}) onPermissionOptionSelected, required void Function(String, Map<String, dynamic>) onElicitationRespond})`
  — consumed by Task 4's `chat_screen.dart`.

- [ ] **Step 1: Write the failing test**

Confirmed during plan review: the real theme API is `AppTheme.darkTheme`/`AppTheme.lightTheme`
(static getters on `class AppTheme`) — there is no `buildAppTheme()` function. Use `AppTheme.darkTheme`
directly (matches the terminal aesthetic these styles target). The review also flagged that a test
asserting only "doesn't throw" + the permission callback wouldn't catch a wiring mistake (e.g.
`elicitationCardBuilder` accidentally rendering `PermissionCard`, or `roleHeaderBuilder` pointing at
the wrong function) — so this version actually pumps the returned builders through `AgUiChat` and
asserts on rendered output:
```dart
// test/presentation/chat/pocketcoder_chat_builders_test.dart
import 'package:ag_ui_widgets_flutter/ag_ui_widgets_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/chat/elicitation_card.dart';
import 'package:pocketcoder_flutter/presentation/chat/permission_card.dart';
import 'package:pocketcoder_flutter/presentation/chat/pocketcoder_chat_builders.dart';

void main() {
  Widget host(BuildContext context, StackedChatBuilders builders, Conversation conversation) {
    return AgUiChat(
      conversation: conversation,
      currentUserId: 'user',
      onSendMessage: (_) {},
      textMessageBuilder: builders.textMessageBuilder,
      textStreamMessageBuilder: builders.textStreamMessageBuilder,
      toolCallBuilder: builders.toolCallBuilder,
      permissionBuilder: builders.permissionBuilder,
      elicitationBuilder: builders.elicitationBuilder,
      toolRequestBuilder: builders.toolRequestBuilder,
    );
  }

  testWidgets('roleHeaderBuilder renders COMMANDER for the current user', (tester) async {
    late StackedChatBuilders builders;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: Builder(builder: (context) {
          builders = pocketcoderChatBuilders(
            context,
            onPermissionOptionSelected: (_, {optionId, cancelled = false}) {},
            onElicitationRespond: (_, __) {},
          );
          return host(
            context,
            builders,
            const Conversation(timeline: [
              TimelineItem.text(id: 'm1', kind: ChatMessageKind.text, role: 'user', text: 'hi'),
            ]),
          );
        }),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('COMMANDER'), findsOneWidget);
  });

  testWidgets('permissionCardBuilder renders pocketcoder\'s own PermissionCard', (tester) async {
    late StackedChatBuilders builders;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: Builder(builder: (context) {
          builders = pocketcoderChatBuilders(
            context,
            onPermissionOptionSelected: (_, {optionId, cancelled = false}) {},
            onElicitationRespond: (_, __) {},
          );
          return host(
            context,
            builders,
            const Conversation(timeline: [
              TimelineItem.permissionRequest(requestId: 'p1', toolTitle: 'bash', options: []),
            ]),
          );
        }),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(PermissionCard), findsOneWidget);
    expect(find.byType(ElicitationCard), findsNothing);
  });

  testWidgets('elicitationCardBuilder renders pocketcoder\'s own ElicitationCard', (tester) async {
    late StackedChatBuilders builders;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: Builder(builder: (context) {
          builders = pocketcoderChatBuilders(
            context,
            onPermissionOptionSelected: (_, {optionId, cancelled = false}) {},
            onElicitationRespond: (_, __) {},
          );
          return host(
            context,
            builders,
            const Conversation(timeline: [
              TimelineItem.elicitationRequest(requestId: 'e1', message: 'hi', mode: 'form'),
            ]),
          );
        }),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(ElicitationCard), findsOneWidget);
    expect(find.byType(PermissionCard), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/presentation/chat/pocketcoder_chat_builders_test.dart`
Expected: FAIL — `pocketcoder_chat_builders.dart` doesn't exist

- [ ] **Step 3: Implement**

```dart
// lib/presentation/chat/pocketcoder_chat_builders.dart
import 'package:ag_ui_widgets_flutter/ag_ui_widgets_flutter.dart';
import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'chat_message_bubble.dart' show pocketcoderRoleHeader;
import 'elicitation_card.dart';
import 'permission_card.dart';

/// Builds this app's `StackedChatBuilders` config: pocketcoder's theme
/// colors/fonts as a `StackedChatStyle`, plus `ChatActionCallbacks` wired to
/// this chat's permission/elicitation action callbacks. `permissionCardBuilder`/
/// `elicitationCardBuilder` keep pocketcoder's own `PermissionCard`/
/// `ElicitationCard` (they read their cubits internally) since those need a
/// distinct deny action and decline/cancel responses the package's generic
/// cards don't support. `toolCallOverrides`/`toolRequestOverrides` are left
/// empty — the generic tool-call card now renders diffs, and pocketcoder has
/// no client-executed-tool feature yet.
StackedChatBuilders pocketcoderChatBuilders(
  BuildContext context, {
  required void Function(String requestId, {String? optionId, bool cancelled}) onPermissionOptionSelected,
  required void Function(String requestId, Map<String, dynamic> response) onElicitationRespond,
}) {
  final colors = context.colorScheme;
  final terminalColors = context.terminalColors;

  final style = StackedChatStyle(
    sentBackground: Colors.transparent,
    receivedBackground: Colors.transparent,
    textStyle: TextStyle(
      color: colors.onSurface,
      fontFamily: AppFonts.bodyFamily,
      fontSize: AppSizes.fontStandard,
      height: 1.4,
    ),
    reasoningTextStyle: TextStyle(
      color: colors.onSurface.withValues(alpha: 0.7),
      fontFamily: AppFonts.bodyFamily,
      fontSize: AppSizes.fontStandard,
      fontStyle: FontStyle.italic,
      height: 1.4,
    ),
    roleHeaderBuilder: pocketcoderRoleHeader,
    padding: EdgeInsets.symmetric(horizontal: AppSizes.space * 2, vertical: AppSizes.space * 1.5),
    cardBorderColor: terminalColors.attention.withValues(alpha: 0.3),
    diffAddedColor: terminalColors.attention,
    diffRemovedColor: terminalColors.danger,
  );

  final callbacks = ChatActionCallbacks(
    onPermissionOptionSelected: onPermissionOptionSelected,
    onElicitationRespond: onElicitationRespond,
    permissionCardBuilder: (context, item) => PermissionCard(item: item),
    elicitationCardBuilder: (context, item) => ElicitationCard(item: item),
  );

  return StackedChatBuilders(style, callbacks);
}
```

Note: `sentBackground`/`receivedBackground: Colors.transparent` because pocketcoder's existing
look uses only a bottom border between messages (`_Bubble`'s `decoration.border.bottom`), not a
background tint — check whether `StackedChatBuilders.textMessageBuilder`'s `Container` still needs
that bottom-border look added via `cardBorderColor`/a wrapping decoration, or whether losing the
per-message bottom border is an acceptable, deliberate visual simplification. Decide during
implementation by comparing against the current running app (Task 6's manual verification step) —
if the bottom border is missed, this function's `style` is the only place to add it back.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/presentation/chat/pocketcoder_chat_builders_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add client/packages/pocketcoder_flutter/lib/presentation/chat/pocketcoder_chat_builders.dart \
        client/packages/pocketcoder_flutter/test/presentation/chat/pocketcoder_chat_builders_test.dart
git commit -m "feat: add pocketcoderChatBuilders config for the shared StackedChatBuilders"
```

---

### Task 4: Wire `chat_screen.dart` to the new builders

**Files:**
- Modify: `lib/presentation/chat/chat_screen.dart`

**Interfaces:**
- Consumes: `pocketcoderChatBuilders` (Task 3), existing `PermissionCubit.authorize`/`.deny`,
  `ElicitationCubit.submit`.

- [ ] **Step 1: Check `PermissionCubit`/`ElicitationCubit`'s exact method shapes**

Read `lib/application/agent/permission_cubit.dart` and `elicitation_cubit.dart` in full — confirm
`authorize(String optionId)`/`deny()`/`submit(ElicitationResponse)`'s exact signatures before
writing the adapter closures in Step 2 (the earlier research pass described these but re-verify
before wiring, since a mismatched signature fails silently as a type error at the call site, not
a runtime error).

- [ ] **Step 2: Replace the five hand-wired builder params**

In `lib/presentation/chat/chat_screen.dart`, remove these imports (no longer used once Step 3
deletes their source files in Task 5 — remove now so the analyzer catches any straggling
reference before Task 5 runs):
```dart
import 'package:pocketcoder_flutter/presentation/chat/chat_message_bubble.dart';
import 'package:pocketcoder_flutter/presentation/chat/tool_call_card.dart';
```
Keep the `permission_card.dart`/`elicitation_card.dart` imports — wait, those are no longer
referenced directly in `chat_screen.dart` either (they're referenced inside
`pocketcoder_chat_builders.dart` now) — remove them from `chat_screen.dart` too. Add:
```dart
import 'package:pocketcoder_flutter/presentation/chat/pocketcoder_chat_builders.dart';
```
Also remove the now-unused `show PermissionRequestTimelineItem, ElicitationRequestTimelineItem`
import — no longer downcast manually in this file.

Replace the `ag_ui_widgets.AgUiChat(...)` block's builder params (everything from
`textMessageBuilder:` through `elicitationBuilder:`) with — **no extra `Builder` wrap needed**:
confirmed during plan review that the `context` already available inside this
`BlocBuilder<ChatCubit, ChatState>`'s builder callback is already a descendant of the
`MultiBlocProvider` providing `PermissionCubit`/`ElicitationCubit`, and already resolves
`context.colorScheme` successfully elsewhere in this same method (the empty-timeline branch above)
— so `pocketcoderChatBuilders(context, ...)` can just use the existing outer `context` directly:
```dart
                      : (() {
                          final builders = pocketcoderChatBuilders(
                            context,
                            onPermissionOptionSelected: (requestId, {optionId, cancelled = false}) {
                              final cubit = context.read<PermissionCubit>();
                              if (cancelled || optionId == null) {
                                cubit.deny();
                              } else {
                                cubit.authorize(optionId);
                              }
                            },
                            onElicitationRespond: (requestId, response) {
                              // ElicitationCard calls ElicitationCubit.submit directly via its
                              // own context.read — this callback only fires for a hypothetical
                              // future generic elicitation card, not the current override.
                            },
                          );
                          return ag_ui_widgets.AgUiChat(
                            conversation: commState.conversation,
                            currentUserId: 'user',
                            onSendMessage: (text) => context.read<ChatCubit>().sendPrompt(text),
                            textMessageBuilder: builders.textMessageBuilder,
                            textStreamMessageBuilder: builders.textStreamMessageBuilder,
                            toolCallBuilder: builders.toolCallBuilder,
                            permissionBuilder: builders.permissionBuilder,
                            elicitationBuilder: builders.elicitationBuilder,
                            toolRequestBuilder: builders.toolRequestBuilder,
                            composerBuilder: (context) => Padding(
                              padding: EdgeInsets.all(AppSizes.space),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (commState.isLoading) ...[
                                    TerminalLoadingIndicator(label: context.l10n.chatThinking),
                                    VSpace.x1,
                                  ],
                                  _SimpleInput(
                                    controller: _inputController,
                                    enabled: !commState.isLoading && commState.chatId != null,
                                    onSubmitted: () => _handleSubmit(context),
                                  ),
                                ],
                              ),
                            ),
                          );
                        })(),
```
This is an immediately-invoked closure only so `builders` can be computed once before constructing
`AgUiChat` within the same conditional expression — it captures the outer `context`, it does not
introduce a new one (unlike a `Builder` widget, which would).

Reconsider the `onElicitationRespond` no-op: since `elicitationCardBuilder` is set (Task 3) and
always used (the package only falls through to the generic content when `elicitationCardBuilder`
is `null`), this callback is genuinely dead for as long as `ElicitationCard` stays a full override.
Either delete the param entirely by checking whether `ChatActionCallbacks.onElicitationRespond` is
actually `required` (it is, per the companion plan's Task 3 change to `chat_action_cards.dart`'s
constructor) — in which case keep it as a documented no-op — or wire it to
`context.read<ElicitationCubit>().submit(...)` translating the raw `Map` back into an
`ElicitationResponse` for defense-in-depth, matching the `action`-key convention already decoded in
`pocketcoder_ag_ui_transport.dart`. Prefer the no-op with a clear comment (shown above) — don't
duplicate decode logic that only matters if the override is later removed.

Similarly reconsider `onPermissionOptionSelected`'s dead-code status: since `permissionCardBuilder`
is always set, this callback is also unreachable via the current wiring. Keep it wired correctly
anyway (as shown) — it costs nothing and means the fallback path stays correct if a future change
ever unsets `permissionCardBuilder`.

- [ ] **Step 3: Run analyze**

Run: `flutter analyze lib/presentation/chat/chat_screen.dart`
Expected: PASS. If `PermissionCubit`/`ElicitationCubit` imports are now missing from
`chat_screen.dart` (they were previously only imported for `BlocProvider` registration in
`ChatScreen.build`, which is untouched), no new import is needed — `context.read<PermissionCubit>()`
inside the `Builder` closure resolves via the existing `MultiBlocProvider` ancestor regardless of
whether this file additionally imports the cubit class name (it does, already, for
`BlocProvider<PermissionCubit>`).

- [ ] **Step 4: Run the full test suite**

Run: `flutter test`
Expected: PASS. `permission_card_test.dart`/`elicitation_card_test.dart` test `PermissionCard`/
`ElicitationCard` directly (not through `chat_screen.dart`), so they're unaffected by this rewiring.

- [ ] **Step 5: Commit**

```bash
git add client/packages/pocketcoder_flutter/lib/presentation/chat/chat_screen.dart
git commit -m "refactor: wire chat_screen.dart to pocketcoderChatBuilders"
```

---

### Task 5: Delete superseded code

**Files:**
- Delete: `lib/presentation/chat/tool_call_card.dart`, `lib/presentation/chat/diff_summary_view.dart`,
  `lib/presentation/chat/diff_stats.dart`
- Delete: `test/presentation/chat/tool_call_card_test.dart`, `test/presentation/chat/diff_stats_test.dart`
- Modify: `lib/presentation/chat/chat_message_bubble.dart` (delete `ChatMessageBubble`,
  `ChatStreamMessageBubble`, `_Bubble` — keep only `kUserAuthorId`, `kAgentAuthorId`,
  `pocketcoderRoleHeader`)
- Modify: `pubspec.yaml` (remove `diff_match_patch` dependency)

**Interfaces:**
- Consumes: nothing new. This task only removes code Task 4 made unreachable.

- [ ] **Step 1: Confirm nothing else references the doomed files**

Run: `grep -rln "ToolCallCard\|DiffSummaryLine\|DiffBody\|computeDiffStats\|ChatMessageBubble\|ChatStreamMessageBubble" lib/ test/`
Expected: only the files listed above under "Files" (plus `chat_message_bubble.dart` itself, which
is edited not deleted). If anything else references these, stop and investigate before deleting —
don't blind-delete over an unexpected caller.

- [ ] **Step 2: Delete the four files**

```bash
git rm client/packages/pocketcoder_flutter/lib/presentation/chat/tool_call_card.dart \
       client/packages/pocketcoder_flutter/lib/presentation/chat/diff_summary_view.dart \
       client/packages/pocketcoder_flutter/lib/presentation/chat/diff_stats.dart \
       client/packages/pocketcoder_flutter/test/presentation/chat/tool_call_card_test.dart \
       client/packages/pocketcoder_flutter/test/presentation/chat/diff_stats_test.dart
```

- [ ] **Step 3: Trim `chat_message_bubble.dart`**

Delete the `ChatMessageBubble`, `ChatStreamMessageBubble`, and `_Bubble` classes from
`lib/presentation/chat/chat_message_bubble.dart`, leaving only `kUserAuthorId`, `kAgentAuthorId`,
and `pocketcoderRoleHeader` (added in Task 2). Update the file's header comment (currently
describes the two deleted widgets) to describe just the remaining constants/function. Remove now-
unused imports (`flutter_chat_core`, `flyer_chat_text_stream_message`) if nothing left in the file
uses them.

- [ ] **Step 4: Remove the now-unused dependency**

In `pubspec.yaml`, delete the `diff_match_patch: ^0.4.1` line. Run: `flutter pub get`.

- [ ] **Step 5: Run analyze and the full test suite**

Run: `flutter analyze lib` then `flutter test`
Expected: both PASS, zero references to deleted symbols remain

- [ ] **Step 6: Commit**

```bash
git add -A client/packages/pocketcoder_flutter client/pubspec.lock
git commit -m "chore: delete chat widgets superseded by StackedChatBuilders"
```

---

### Task 6: Manual verification

Automated tests don't cover visual fidelity — required per this repo's root `CLAUDE.md` UI-change
policy.

- [ ] **Step 1: Launch the app**

Use the `run` skill (or this repo's existing dev-launch process) to start pocketcoder against a
real or sandboxed backend session.

- [ ] **Step 2: Walk the golden path**

Open a chat, send a message, confirm: COMMANDER/POCO labels render above messages (and above a
still-streaming reply — this is new; previously streaming replies had no header at all, confirm it
now matches completed messages). **Specifically watch the streaming reply as it arrives**: confirm
the text is actually live-updating (not stuck on a loading placeholder — the companion package
plan's Task 5/6 correction fixes a real typedef bug where a naively-wired streaming builder would
have no access to the in-progress text at all) and confirm its text color matches the rest of the
UI from the very first character (the companion plan's Task 5/6 also fixes a real color-pop bug:
`FlyerChatTextStreamMessage` defaults to `flutter_chat_ui`'s stock light-mode palette unless the
caller passes `sentTextStyle`/`receivedTextStyle` explicitly — if pocketcoder's terminal colors
"pop" or flash the instant a reply finishes streaming, that fix didn't land correctly upstream).
Trigger a tool call that produces a file diff; confirm the diff renders with the expand/collapse
summary line and correct add/remove coloring. Trigger a permission request; confirm `PermissionCard`'s
deny button and requestId tag still render exactly as before. Trigger an elicitation request with a
boolean and a string field; confirm decline/cancel/submit all still work.

- [ ] **Step 3: Compare against pre-migration screenshots if available, or note any visual delta**

If the `sentBackground`/`receivedBackground: Colors.transparent` + missing per-message bottom
border decision from Task 3 Step 3 reads as a regression, fix it in
`pocketcoder_chat_builders.dart`'s `style` now, before considering this plan done — this is the
step that step 3 explicitly deferred to.

- [ ] **Step 4: Final full verification**

Run: `flutter analyze` and `flutter test` one more time from a clean state to confirm nothing
Task 6's manual fixes (if any) broke.

---

## Post-Review Corrections

A Sonnet review pass against the live codebase caught and fixed, before execution:
- **Task 4**: dropped an unnecessary `Builder` widget wrap — the outer `context` already resolves
  fine (confirmed by reading `chat_screen.dart` in full: it's already a `MultiBlocProvider`
  descendant and already uses `context.colorScheme` at the same nesting level elsewhere in the
  file).
- **Task 3's test**: `theme: buildAppTheme()` doesn't exist — fixed to the real API,
  `AppTheme.darkTheme`. The test was also strengthened from "doesn't throw" to three separate
  widget tests actually rendering `AgUiChat` and asserting on output (`COMMANDER` text,
  `PermissionCard`/`ElicitationCard` type checks) — the original version wouldn't have caught a
  builder accidentally wired to the wrong widget.
- **Task 2**: corrected an inaccurate line-number citation (cosmetic — the step already told the
  implementer to re-read rather than trust the number blindly).
- **Task 4/6**: flagged that this plan's `builders.textStreamMessageBuilder` depends on a mechanism
  the companion package plan's *original draft* got wrong (a typedef with no way to access
  streaming text) — now fixed upstream (see that plan's own Post-Review Corrections). Task 6's
  manual-verification step was expanded to explicitly check that streaming text is actually live
  and correctly colored from the first character, since neither plan has automated coverage that
  would catch a regression there through pocketcoder's own actual UI.
- Confirmed via direct `grep` (not just trusting the plan's premise) that Task 5's deletion list is
  complete — no unlisted caller of `ToolCallCard`/`ChatMessageBubble`/etc. exists in `lib/` or
  `test/` beyond what's already scheduled for deletion or edit.
- Confirmed `PermissionCubit.authorize(String)`/`.deny()`/`ElicitationCubit.submit(ElicitationResponse)`
  signatures match Task 4's adapter closures exactly, and that `permission_card_test.dart`/
  `elicitation_card_test.dart` construct their widgets directly (not through `chat_screen.dart`),
  so they're genuinely unaffected by this migration as claimed.

## Self-Review Notes

- Every widget pocketcoder had before this plan is accounted for: `ChatMessageBubble`/
  `ChatStreamMessageBubble` → generic `textMessageBuilder`/`textStreamMessageBuilder` +
  `roleHeaderBuilder` (Task 2–4); `ToolCallCard`/diff view → generic `toolCallBuilder` (deleted,
  Task 5); `PermissionCard`/`ElicitationCard` → kept via `permissionCardBuilder`/
  `elicitationCardBuilder` overrides (Task 3), unchanged, still directly tested.
- The one genuine open question (per-message background/border treatment under the new generic
  `textMessageBuilder` shell) is flagged explicitly rather than silently decided, with a concrete
  fallback (Task 6 Step 3) if it doesn't hold up visually.
- `toolRequestBuilder` — previously silently dropped (`SizedBox.shrink()`) — now renders the
  package's generic fallback card for free, with no new pocketcoder code, since there's no
  client-executed-tool feature to build a bespoke widget for yet.
