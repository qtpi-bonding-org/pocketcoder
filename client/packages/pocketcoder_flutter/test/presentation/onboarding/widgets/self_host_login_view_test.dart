import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/widgets/self_host_login_view.dart';

void main() {
  testWidgets(
      'wizard <next> renders on a transparent background at rest, not '
      'filled/inverted', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SelfHostLoginView(
          initialUrl: '',
          initialEmail: '',
          initialPassword: '',
          status: UiFlowStatus.idle,
          pocoMessage: 'hi',
          pocoSequence: const [],
          pocoHistory: const [],
          onDeploy: () {},
          onLogin: (_, __, ___) async {},
        ),
      ),
    );

    final text = tester.widget<Text>(find.text('next'));
    expect(text.style?.color, isNot(Colors.black));

    final container = tester.widget<Container>(
      find
          .descendant(
              of: find.ancestor(
                of: find.text('next'),
                matching: find.byType(GestureDetector),
              ),
              matching: find.byType(Container))
          .first,
    );
    expect(container.color, Colors.transparent);
  });
}
