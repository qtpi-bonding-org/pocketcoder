import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat_core;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/chat/tool_call_card.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en')],
    home: Scaffold(body: child),
  );
}

void main() {
  group('ToolCallCard diff rendering', () {
    testWidgets('a tool call with no diffs renders no diff summary line', (tester) async {
      final message = chat_core.Message.custom(
        id: 't1',
        authorId: 'assistant',
        metadata: const {'kind': 'toolCall', 'name': 'search', 'args': '{}', 'result': 'ok'},
      ) as chat_core.CustomMessage;

      await tester.pumpWidget(_wrap(ToolCallCard(message: message)));
      await tester.pumpAndSettle();

      expect(find.textContaining('+'), findsNothing);
    });

    testWidgets('a tool call with one diff renders a summary line with path and counts',
        (tester) async {
      final message = chat_core.Message.custom(
        id: 't1',
        authorId: 'assistant',
        metadata: {
          'kind': 'toolCall',
          'name': 'edit_file',
          'args': '{}',
          'result': 'ok',
          'diffs': [
            {'path': 'lib/foo.dart', 'oldText': 'return a + b', 'newText': 'return a - b'},
          ],
        },
      ) as chat_core.CustomMessage;

      await tester.pumpWidget(_wrap(ToolCallCard(message: message)));
      await tester.pumpAndSettle();

      expect(find.textContaining('LIB/FOO.DART'), findsOneWidget);
      expect(find.textContaining('(+1 -1)'), findsOneWidget);
      expect(find.text('return a - b'), findsNothing);
    });

    testWidgets('tapping the summary line expands the diff body', (tester) async {
      final message = chat_core.Message.custom(
        id: 't1',
        authorId: 'assistant',
        metadata: {
          'kind': 'toolCall',
          'name': 'edit_file',
          'args': '{}',
          'result': 'ok',
          'diffs': [
            {'path': 'lib/foo.dart', 'oldText': 'return a + b', 'newText': 'return a - b'},
          ],
        },
      ) as chat_core.CustomMessage;

      await tester.pumpWidget(_wrap(ToolCallCard(message: message)));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('LIB/FOO.DART'));
      await tester.pumpAndSettle();

      expect(find.text('- return a + b'), findsOneWidget);
      expect(find.text('+ return a - b'), findsOneWidget);
    });

    testWidgets('a new-file diff (empty oldText) shows NEW FILE instead of counts', (tester) async {
      final message = chat_core.Message.custom(
        id: 't1',
        authorId: 'assistant',
        metadata: {
          'kind': 'toolCall',
          'name': 'write_file',
          'args': '{}',
          'result': 'ok',
          'diffs': [
            {'path': 'lib/new.dart', 'oldText': '', 'newText': 'content'},
          ],
        },
      ) as chat_core.CustomMessage;

      await tester.pumpWidget(_wrap(ToolCallCard(message: message)));
      await tester.pumpAndSettle();

      expect(find.textContaining('NEW FILE'), findsOneWidget);
    });
  });
}
