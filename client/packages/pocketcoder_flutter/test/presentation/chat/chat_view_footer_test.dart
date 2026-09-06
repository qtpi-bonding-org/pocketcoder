import 'package:ag_ui_widgets_flutter/ag_ui_widgets_flutter.dart'
    as ag_ui_widgets;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/chat/widgets/chat_view.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/detail_row.dart';

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

  Widget buildChatView() => wrap(ChatView(
        chatId: 'chat-1',
        conversation: const ag_ui_widgets.Conversation(),
        title: 'CHAT',
        isLoading: false,
        isRunning: false,
        requiresProviderReauthentication: false,
        config: null,
        showMonitorAction: true,
        monitored: true,
        onToggleMonitored: () {},
        onOpen: (_) {},
        onSendPrompt: (_) {},
        onCancel: () {},
        onSetOption: (_) {},
        onPermissionOptionSelected: (_, {optionId, cancelled = false}) {},
        onElicitationRespond: (_, __) {},
        animatedMessageIds: const {},
        onMessageAnimated: (_) {},
        onFiles: () {},
      ));

  testWidgets('watch is an active action in the footer', (tester) async {
    await tester.pumpWidget(buildChatView());
    await tester.pumpAndSettle();

    final footer = tester.widget<TerminalFooter>(find.byType(TerminalFooter));
    final watch = footer.actions.singleWhere(
      (action) => action.label == 'watch',
    );
    expect(watch.isActive, isTrue);
  });

  testWidgets('watch has no DetailRow toggle in the body', (tester) async {
    await tester.pumpWidget(buildChatView());
    await tester.pumpAndSettle();

    expect(find.widgetWithText(DetailRow, 'watch'), findsNothing);
  });
}
