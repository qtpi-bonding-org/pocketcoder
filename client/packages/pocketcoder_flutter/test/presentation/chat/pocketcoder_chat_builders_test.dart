// Test for pocketcoderChatBuilders: confirms the StackedChatStyle wires the
// role-header row, the StackedChatBuilders delegate the five AgUiChat slots
// correctly, and the permission/elicitation card overrides actually render
// pocketcoder's own PermissionCard/ElicitationCard (and not each other).
//
// Pumps each scenario through a real AgUiChat and asserts on rendered
// output (not just "doesn't throw") so a wiring mistake (e.g. swap of
// permissionCardBuilder/elicitationCardBuilder, or roleHeaderBuilder
// pointing at the wrong function) is caught.
import 'package:ag_ui_widgets_flutter/ag_ui_widgets_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/status_marker.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/chat/elicitation_card.dart';
import 'package:pocketcoder_flutter/presentation/chat/permission_card.dart';
import 'package:pocketcoder_flutter/presentation/chat/pocketcoder_chat_builders.dart';
import 'package:pocketcoder_flutter/presentation/chat/widgets/terminal_command_card.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/status_marker_view.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_conversation.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/typewriter_text.dart';

void main() {
  Widget host(BuildContext context, StackedChatBuilders builders,
      Conversation conversation) {
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

  Widget wrap(Widget body) => MaterialApp(
        theme: AppTheme.darkTheme,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: Scaffold(body: body),
      );

  testWidgets('renders a terminal prompt for the current user', (tester) async {
    late StackedChatBuilders builders;
    await tester.pumpWidget(wrap(
      Builder(builder: (context) {
        builders = pocketcoderChatBuilders(
          context,
          onPermissionOptionSelected: (_, {optionId, cancelled = false}) {},
          onElicitationRespond: (_, __) {},
          animatedMessageIds: const {},
          onMessageAnimated: (_) {},
        );
        return host(
          context,
          builders,
          const Conversation(timeline: [
            TimelineItem.text(
              id: 'm1',
              kind: ChatMessageKind.text,
              role: 'user',
              text: 'hi',
              order: OrderKey(1),
            ),
          ]),
        );
      }),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('commander@pc \$ '), findsOneWidget);
    expect(find.byType(TerminalConversationFrame), findsOneWidget);
  });

  testWidgets('assistant responses use a Poco terminal prefix', (tester) async {
    late StackedChatBuilders builders;
    await tester.pumpWidget(wrap(
      Builder(builder: (context) {
        builders = pocketcoderChatBuilders(
          context,
          onPermissionOptionSelected: (_, {optionId, cancelled = false}) {},
          onElicitationRespond: (_, __) {},
          animatedMessageIds: const {},
          onMessageAnimated: (_) {},
        );
        return host(
          context,
          builders,
          const Conversation(timeline: [
            TimelineItem.text(
              id: 'assistant-1',
              kind: ChatMessageKind.text,
              role: 'assistant',
              text: 'The deployment is healthy.',
              order: OrderKey(1),
            ),
          ]),
        );
      }),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('[poco] '), findsOneWidget);
    expect(find.byType(TypewriterText), findsOneWidget);
  });

  testWidgets(
      'reasoning messages render nothing inline -- the caption above Poco '
      'owns their display now, not the transcript bubble list', (tester) async {
    late StackedChatBuilders builders;
    await tester.pumpWidget(wrap(
      Builder(builder: (context) {
        builders = pocketcoderChatBuilders(
          context,
          onPermissionOptionSelected: (_, {optionId, cancelled = false}) {},
          onElicitationRespond: (_, __) {},
          animatedMessageIds: const {},
          onMessageAnimated: (_) {},
        );
        return host(
          context,
          builders,
          const Conversation(timeline: [
            TimelineItem.text(
              id: 'reasoning-1',
              kind: ChatMessageKind.reasoning,
              role: 'assistant',
              text: 'thinking...',
              order: OrderKey(1),
            ),
          ]),
        );
      }),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(TerminalConversationFrame), findsNothing);
    expect(find.textContaining('thinking...'), findsNothing);
  });

  testWidgets(
      'a poco text message already in animatedMessageIds renders instantly',
      (tester) async {
    late StackedChatBuilders builders;
    await tester.pumpWidget(wrap(
      Builder(builder: (context) {
        builders = pocketcoderChatBuilders(
          context,
          onPermissionOptionSelected: (_, {optionId, cancelled = false}) {},
          onElicitationRespond: (_, __) {},
          animatedMessageIds: const {'m1'},
          onMessageAnimated: (_) {},
        );
        return host(
          context,
          builders,
          const Conversation(timeline: [
            TimelineItem.text(
              id: 'm1',
              kind: ChatMessageKind.text,
              role: 'assistant',
              text: 'already complete',
              order: OrderKey(1),
            ),
          ]),
        );
      }),
    ));

    // No pump-forward: instant rendering makes the complete text available
    // on the first frame.
    await tester.pump();
    expect(find.textContaining('already complete'), findsOneWidget);
  });

  testWidgets('permissionCardBuilder renders pocketcoder\'s own PermissionCard',
      (tester) async {
    late StackedChatBuilders builders;
    await tester.pumpWidget(wrap(
      Builder(builder: (context) {
        builders = pocketcoderChatBuilders(
          context,
          onPermissionOptionSelected: (_, {optionId, cancelled = false}) {},
          onElicitationRespond: (_, __) {},
          animatedMessageIds: const {},
          onMessageAnimated: (_) {},
        );
        return host(
          context,
          builders,
          const Conversation(timeline: [
            TimelineItem.permissionRequest(
              requestId: 'p1',
              toolTitle: 'bash',
              options: [],
              order: OrderKey(1),
            ),
          ]),
        );
      }),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(PermissionCard), findsOneWidget);
    expect(find.byType(ElicitationCard), findsNothing);
  });

  testWidgets(
      'elicitationCardBuilder renders pocketcoder\'s own ElicitationCard',
      (tester) async {
    late StackedChatBuilders builders;
    await tester.pumpWidget(wrap(
      Builder(builder: (context) {
        builders = pocketcoderChatBuilders(
          context,
          onPermissionOptionSelected: (_, {optionId, cancelled = false}) {},
          onElicitationRespond: (_, __) {},
          animatedMessageIds: const {},
          onMessageAnimated: (_) {},
        );
        return host(
          context,
          builders,
          const Conversation(timeline: [
            TimelineItem.elicitationRequest(
              requestId: 'e1',
              message: 'hi',
              mode: 'form',
              order: OrderKey(1),
            ),
          ]),
        );
      }),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(ElicitationCard), findsOneWidget);
    expect(find.byType(PermissionCard), findsNothing);
  });

  testWidgets(
      'toolCallBuilder shows the actual shell command for an execute-kind '
      'tool call, not the raw args JSON', (tester) async {
    late StackedChatBuilders builders;
    await tester.pumpWidget(wrap(
      Builder(builder: (context) {
        builders = pocketcoderChatBuilders(
          context,
          onPermissionOptionSelected: (_, {optionId, cancelled = false}) {},
          onElicitationRespond: (_, __) {},
          animatedMessageIds: const {},
          onMessageAnimated: (_) {},
        );
        return host(
          context,
          builders,
          const Conversation(timeline: [
            TimelineItem.toolCall(
              id: 't1',
              name: '',
              args: '{"command":"ls -la"}',
              toolKind: 'execute',
              order: OrderKey(1),
            ),
          ]),
        );
      }),
    ));
    await tester.pumpAndSettle();

    final card =
        tester.widget<TerminalCommandCard>(find.byType(TerminalCommandCard));
    expect(card.command, 'ls -la');
  });

  testWidgets(
      'toolCallBuilder falls back to a generic label when an execute-kind '
      'tool call has neither a name nor parseable args yet', (tester) async {
    late StackedChatBuilders builders;
    await tester.pumpWidget(wrap(
      Builder(builder: (context) {
        builders = pocketcoderChatBuilders(
          context,
          onPermissionOptionSelected: (_, {optionId, cancelled = false}) {},
          onElicitationRespond: (_, __) {},
          animatedMessageIds: const {},
          onMessageAnimated: (_) {},
        );
        return host(
          context,
          builders,
          const Conversation(timeline: [
            TimelineItem.toolCall(
              id: 't1',
              name: '',
              args: '{"comma', // still streaming -- not yet valid JSON
              toolKind: 'execute',
              order: OrderKey(1),
            ),
          ]),
        );
      }),
    ));
    await tester.pumpAndSettle();

    final card =
        tester.widget<TerminalCommandCard>(find.byType(TerminalCommandCard));
    expect(card.command, 'Tool call');
  });

  testWidgets(
      'toolCallBuilder keeps the name+args behavior for a non-execute tool '
      'call', (tester) async {
    late StackedChatBuilders builders;
    await tester.pumpWidget(wrap(
      Builder(builder: (context) {
        builders = pocketcoderChatBuilders(
          context,
          onPermissionOptionSelected: (_, {optionId, cancelled = false}) {},
          onElicitationRespond: (_, __) {},
          animatedMessageIds: const {},
          onMessageAnimated: (_) {},
        );
        return host(
          context,
          builders,
          const Conversation(timeline: [
            TimelineItem.toolCall(
              id: 't1',
              name: 'edit_file',
              args: '{"path":"lib/foo.dart"}',
              toolKind: 'edit',
              order: OrderKey(1),
            ),
          ]),
        );
      }),
    ));
    await tester.pumpAndSettle();

    final card =
        tester.widget<TerminalCommandCard>(find.byType(TerminalCommandCard));
    expect(card.command, 'edit_file {"path":"lib/foo.dart"}');
  });

  testWidgets(
      'toolCallBuilder shows a failed status marker for a tool call the '
      'harness reported (or the coordinator force-closed) as failed',
      (tester) async {
    late StackedChatBuilders builders;
    await tester.pumpWidget(wrap(
      Builder(builder: (context) {
        builders = pocketcoderChatBuilders(
          context,
          onPermissionOptionSelected: (_, {optionId, cancelled = false}) {},
          onElicitationRespond: (_, __) {},
          animatedMessageIds: const {},
          onMessageAnimated: (_) {},
        );
        return host(
          context,
          builders,
          const Conversation(timeline: [
            TimelineItem.toolCall(
              id: 't1',
              name: 'edit_file',
              toolKind: 'edit',
              hasEnded: true,
              status: 'failed',
              order: OrderKey(1),
            ),
          ]),
        );
      }),
    ));
    await tester.pumpAndSettle();

    final marker =
        tester.widget<StatusMarkerView>(find.byType(StatusMarkerView));
    expect(marker.marker, StatusMarker.failed);
  });

  testWidgets(
      'toolCallBuilder still shows the ok marker for a completed, non-failed '
      'tool call', (tester) async {
    late StackedChatBuilders builders;
    await tester.pumpWidget(wrap(
      Builder(builder: (context) {
        builders = pocketcoderChatBuilders(
          context,
          onPermissionOptionSelected: (_, {optionId, cancelled = false}) {},
          onElicitationRespond: (_, __) {},
          animatedMessageIds: const {},
          onMessageAnimated: (_) {},
        );
        return host(
          context,
          builders,
          const Conversation(timeline: [
            TimelineItem.toolCall(
              id: 't1',
              name: 'edit_file',
              toolKind: 'edit',
              hasEnded: true,
              status: 'completed',
              order: OrderKey(1),
            ),
          ]),
        );
      }),
    ));
    await tester.pumpAndSettle();

    final marker =
        tester.widget<StatusMarkerView>(find.byType(StatusMarkerView));
    expect(marker.marker, StatusMarker.ok);
  });
}
