import 'package:ag_ui_widgets_flutter/ag_ui_widgets_flutter.dart' as ag_ui_widgets;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/chat/widgets/chat_view.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: AppTheme.darkTheme,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: Scaffold(body: child),
      );

  testWidgets('shows interrupted outcome and retries the last prompt',
      (tester) async {
    var retried = false;
    final conversation = ag_ui_widgets.Conversation(
      sessionState: const ag_ui_widgets.SessionState(
        runOutcome: ag_ui_widgets.RunOutcome.interrupted,
      ),
    );

    await tester.pumpWidget(wrap(ChatView(
      chatId: 'chat-1',
      conversation: conversation,
      title: 'CHAT',
      isLoading: false,
      isRunning: false,
      modes: null,
      config: null,
      onOpen: (_) {},
      onSendPrompt: (_) {},
      onRetry: () => retried = true,
      onCancel: () {},
      onSelectMode: (_) {},
      onSetOption: (_) {},
      onPermissionOptionSelected: (_, {optionId, cancelled = false}) {},
      onElicitationRespond: (_, __) {},
      onFiles: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('RUN INTERRUPTED'), findsOneWidget);
    expect(find.text('The connection ended before the run finished.'),
        findsOneWidget);
    await tester.tap(find.text('RETRY'));
    expect(retried, isTrue);
  });
}
