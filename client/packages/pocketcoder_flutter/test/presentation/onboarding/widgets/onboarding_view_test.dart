import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/application/system/poco_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/errors/widgets/error_inbox_link.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/widgets/onboarding_view.dart';

void main() {
  testWidgets('shows the error inbox link and opens it on tap',
      (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: OnboardingView(
          pocoState: const PocoState(message: 'hi', sequence: []),
          onLogin: () {},
          onDeploy: () {},
          errorInboxLink: ErrorInboxLink(count: 5, onTap: () => opened++),
        ),
      ),
    );

    await tester.ensureVisible(find.text('<errors (5)>'));
    await tester.tap(find.text('<errors (5)>'));
    expect(opened, 1);
  });
}
