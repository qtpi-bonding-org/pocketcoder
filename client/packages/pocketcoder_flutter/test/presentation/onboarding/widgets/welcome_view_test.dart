import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/widgets/welcome_view.dart';

void main() {
  testWidgets(
      'the guided-setup suggestion renders a full-opacity outlined border; '
      'self-host keeps the existing alpha-0.3 chip border', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: WelcomeView(
          showGuidedSetup: true,
          onGuidedSetup: () {},
          onSelfHost: () {},
        ),
      ),
    );

    final colors =
        Theme.of(tester.element(find.byType(WelcomeView))).colorScheme;

    final guidedButton = tester.widget<TextButton>(
      find.ancestor(
        of: find.textContaining('HELP ME WITH SETUP'),
        matching: find.byType(TextButton),
      ),
    );
    final guidedSide =
        (guidedButton.style?.shape?.resolve({}) as RoundedRectangleBorder).side;
    expect(guidedSide.color, colors.primary);

    final selfHostButton = tester.widget<TextButton>(
      find.ancestor(
        of: find.textContaining("I’LL SET IT UP"),
        matching: find.byType(TextButton),
      ),
    );
    final selfHostSide =
        (selfHostButton.style?.shape?.resolve({}) as RoundedRectangleBorder)
            .side;
    expect(selfHostSide.color, colors.primary.withValues(alpha: 0.3));
  });
}
