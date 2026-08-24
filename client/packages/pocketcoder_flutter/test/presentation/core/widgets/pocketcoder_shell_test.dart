import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: AppTheme.darkTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      );

  testWidgets(
      'contextual actions render leftmost in the footer, ahead of back and nav',
      (tester) async {
    await tester.pumpWidget(wrap(PocketCoderShell(
      title: 'CHAT',
      activePillar: NavPillar.chats,
      showBack: true,
      actions: [TerminalAction(label: 'FILES', onTap: () {})],
      body: const SizedBox.shrink(),
    )));

    final labels = tester
        .widgetList<Text>(find.descendant(
            of: find.byType(TerminalFooter), matching: find.byType(Text)))
        .map((t) => t.data)
        .toList();

    final files = labels.indexOf('FILES');
    final back = labels.indexOf('BACK');
    final chats = labels.indexOf('CHATS');
    expect(files, greaterThanOrEqualTo(0));
    expect(files, lessThan(back));
    expect(back, lessThan(chats));
  });
}
