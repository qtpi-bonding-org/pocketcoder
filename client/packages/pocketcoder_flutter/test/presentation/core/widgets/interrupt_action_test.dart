import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/interrupt_action.dart';

void main() {
  testWidgets('^C reports the interrupt exactly once per tap', (tester) async {
    var interrupts = 0;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: InterruptAction(onInterrupt: () => interrupts++)),
    ));

    expect(find.text('^C'), findsOneWidget);
    await tester.tap(find.text('^C'));
    await tester.pump();
    expect(interrupts, 1);
  });
}
