import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/application/chat/chat_list_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/chat/widgets/chat_list_view.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';

void main() {
  testWidgets('the new-chat action is not part of the bottom nav footer',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: ChatListView(
        state: const ChatListState(chats: [], status: UiFlowStatus.success),
        onNewChat: () => tapped = true,
        onOpen: (_) {},
        onArchive: (_) {},
        onDelete: (_) {},
      ),
    ));

    final footer = tester.widget<TerminalFooter>(find.byType(TerminalFooter));
    expect(footer.actions.map((a) => a.label), isNot(contains('NEW')));

    await tester.tap(find.text('<new>'));
    await tester.pump();
    expect(tapped, isTrue);
  });
}
