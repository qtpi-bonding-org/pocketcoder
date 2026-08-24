import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/widgets/onboarding_login_view.dart';

void main() {
  testWidgets('CONNECT renders outlined: bordered in its own color, not filled/inverted',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: OnboardingLoginView(
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

    final text = tester.widget<Text>(find.text('CONNECT'));
    expect(text.style?.color, isNot(Colors.black));

    final container = tester.widget<Container>(
      find
          .descendant(
              of: find.ancestor(
                of: find.text('CONNECT'),
                matching: find.byType(InkWell),
              ),
              matching: find.byType(Container))
          .first,
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.border, isNotNull);
    expect(decoration.color, anyOf(isNull, Colors.transparent));
  });
}
