import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/domain/models/chat.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/chat/widgets/chat_list_tile.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('shows first and last message instead of the chat title',
      (tester) async {
    const chat = Chat(
      id: 'c1',
      title: 'New Chat',
      user: 'u1',
      firstMessage: 'how do I deploy this',
      preview: 'looks like it is working now',
    );

    await tester.pumpWidget(_wrap(
      ChatListTile(
        chat: chat,
        onOpen: _noopString,
        onArchive: _noopString,
        onDelete: _noopString,
      ),
    ));

    expect(find.text('New Chat'), findsNothing);
    expect(find.textContaining('how do I deploy this'), findsOneWidget);
    expect(find.textContaining('looks like it is working now'), findsOneWidget);
  });

  testWidgets('falls back to the no-messages string when nothing sent yet',
      (tester) async {
    const chat = Chat(id: 'c1', title: 'New Chat', user: 'u1');

    await tester.pumpWidget(_wrap(
      ChatListTile(
        chat: chat,
        onOpen: _noopString,
        onArchive: _noopString,
        onDelete: _noopString,
      ),
    ));

    expect(find.text('No messages yet'), findsOneWidget);
  });

  testWidgets('headline, preview and timestamp render in three distinct '
      'roles, not three identical label lines', (tester) async {
    final chat = Chat(
      id: 'c1',
      title: 'New Chat',
      user: 'u1',
      turn: ChatTurn.assistant,
      firstMessage: 'how do I deploy this',
      preview: 'looks like it is working now',
      lastActive: DateTime.now(),
    );

    await tester.pumpWidget(_wrap(
      ChatListTile(
        chat: chat,
        onOpen: _noopString,
        onArchive: _noopString,
        onDelete: _noopString,
      ),
    ));

    expect(
      tester
          .widget<TerminalText>(
              find.widgetWithText(TerminalText, 'how do I deploy this'))
          .role,
      TextRole.value,
      reason: 'the headline is the record\'s subject -- bright and bold',
    );
    expect(
      tester
          .widget<TerminalText>(find.widgetWithText(
              TerminalText, 'looks like it is working now'))
          .role,
      TextRole.body,
    );
    expect(
      tester.widget<TerminalText>(find.widgetWithText(TerminalText, 'now'))
          .role,
      TextRole.label,
      reason: 'timestamp stays label -- after task 7 that is body-weight, '
          'still readable',
    );
  });

  testWidgets('delete is destructive, not neutral', (tester) async {
    final chat = Chat(id: 'c1', title: 'New Chat', user: 'u1');

    await tester.pumpWidget(_wrap(
      ChatListTile(
        chat: chat,
        onOpen: _noopString,
        onArchive: _noopString,
        onDelete: _noopString,
      ),
    ));

    await tester.longPress(find.byType(InkWell));
    await tester.pumpAndSettle();

    final deleteButton = tester
        .widget<TerminalButton>(find.widgetWithText(TerminalButton, '<delete>'));
    expect(deleteButton.kind, ActionKind.destructive);
  });

  testWidgets('the long-press dialog states what archive and delete do, '
      'not an empty body', (tester) async {
    final chat = Chat(id: 'c1', title: 'my chat', user: 'u1');

    await tester.pumpWidget(_wrap(
      ChatListTile(
        chat: chat,
        onOpen: _noopString,
        onArchive: _noopString,
        onDelete: _noopString,
      ),
    ));

    await tester.longPress(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(find.textContaining('my chat'), findsWidgets,
        reason: 'names the chat, not just the actions');
    expect(find.textContaining('archive'), findsWidgets);
    expect(find.textContaining('delete'), findsWidgets);
  });

  testWidgets(
      'shows preview alone when firstMessage is missing but preview exists '
      '(pre-migration chat)', (tester) async {
    const chat = Chat(
      id: 'c1',
      title: 'New Chat',
      user: 'u1',
      preview: 'an old chat with no recorded first message',
    );

    await tester.pumpWidget(_wrap(
      ChatListTile(
        chat: chat,
        onOpen: _noopString,
        onArchive: _noopString,
        onDelete: _noopString,
      ),
    ));

    expect(find.text('No messages yet'), findsNothing);
    expect(find.textContaining('an old chat with no recorded first message'),
        findsOneWidget);
  });
}

void _noopString(String _) {}
