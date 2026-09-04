import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/domain/models/chat.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/chat/widgets/chat_list_tile.dart';

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
