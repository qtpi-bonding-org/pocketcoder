import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_conversation.dart';
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

    final guidedSuggestion = tester.widget<TerminalPromptSuggestion>(
      find.ancestor(
        of: find.textContaining('Help me with setup'),
        matching: find.byType(TerminalPromptSuggestion),
      ),
    );
    expect(guidedSuggestion.emphasis, Emphasis.outlined);

    final selfHostSuggestion = tester.widget<TerminalPromptSuggestion>(
      find.ancestor(
        of: find.textContaining("I'll set it up"),
        matching: find.byType(TerminalPromptSuggestion),
      ),
    );
    expect(selfHostSuggestion.emphasis, isNot(Emphasis.outlined));
  });

  testWidgets('the reset escape hatch is hidden by default', (tester) async {
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

    expect(find.textContaining('reset'), findsNothing);
  });

  testWidgets(
      'the reset escape hatch shows and fires onReset when showReset is '
      'true', (tester) async {
    var resetCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: WelcomeView(
          showGuidedSetup: true,
          onGuidedSetup: () {},
          onSelfHost: () {},
          showReset: true,
          onReset: () => resetCount++,
        ),
      ),
    );

    final resetLabel = AppLocalizations.of(
        tester.element(find.byType(WelcomeView)))!.onboardingWelcomeActionReset;
    await tester.tap(find.text(resetLabel));
    await tester.pump();

    expect(resetCount, 1);
  });

  testWidgets('the reset escape hatch renders as destructive (danger)',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: WelcomeView(
          showGuidedSetup: true,
          onGuidedSetup: () {},
          onSelfHost: () {},
          showReset: true,
          onReset: () {},
        ),
      ),
    );

    final resetLabel = AppLocalizations.of(
        tester.element(find.byType(WelcomeView)))!.onboardingWelcomeActionReset;
    final resetSuggestion = tester.widget<TerminalPromptSuggestion>(
      find.ancestor(
        of: find.text(resetLabel),
        matching: find.byType(TerminalPromptSuggestion),
      ),
    );
    expect(resetSuggestion.danger, isTrue);
  });
}
