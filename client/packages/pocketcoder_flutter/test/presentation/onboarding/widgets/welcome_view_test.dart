import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/widgets/welcome_view.dart';

void main() {
  testWidgets(
      'the guided-setup suggestion is emphasized (primary); self-host is '
      'the plain default (neutral)', (tester) async {
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

    final guidedButton = tester.widget<TerminalButton>(
      find.ancestor(
        of: find.textContaining('help me with setup'),
        matching: find.byType(TerminalButton),
      ),
    );
    expect(guidedButton.kind, ActionKind.primary);

    final selfHostButton = tester.widget<TerminalButton>(
      find.ancestor(
        of: find.textContaining('i’ll set it up'),
        matching: find.byType(TerminalButton),
      ),
    );
    expect(selfHostButton.kind, ActionKind.neutral);
  });
}
