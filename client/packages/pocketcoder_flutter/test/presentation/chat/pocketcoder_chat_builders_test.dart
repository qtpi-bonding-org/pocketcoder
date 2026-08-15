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
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/chat/elicitation_card.dart';
import 'package:pocketcoder_flutter/presentation/chat/permission_card.dart';
import 'package:pocketcoder_flutter/presentation/chat/pocketcoder_chat_builders.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_conversation.dart';

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

  testWidgets('roleHeaderBuilder renders COMMANDER for the current user',
      (tester) async {
    late StackedChatBuilders builders;
    await tester.pumpWidget(wrap(
      Builder(builder: (context) {
        builders = pocketcoderChatBuilders(
          context,
          onPermissionOptionSelected: (_, {optionId, cancelled = false}) {},
          onElicitationRespond: (_, __) {},
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
            ),
          ]),
        );
      }),
    ));
    await tester.pumpAndSettle();
    expect(find.text('COMMANDER'), findsOneWidget);
    expect(find.byType(TerminalConversationFrame), findsOneWidget);
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
        );
        return host(
          context,
          builders,
          const Conversation(timeline: [
            TimelineItem.permissionRequest(
              requestId: 'p1',
              toolTitle: 'bash',
              options: [],
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
        );
        return host(
          context,
          builders,
          const Conversation(timeline: [
            TimelineItem.elicitationRequest(
              requestId: 'e1',
              message: 'hi',
              mode: 'form',
            ),
          ]),
        );
      }),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(ElicitationCard), findsOneWidget);
    expect(find.byType(PermissionCard), findsNothing);
  });
}
