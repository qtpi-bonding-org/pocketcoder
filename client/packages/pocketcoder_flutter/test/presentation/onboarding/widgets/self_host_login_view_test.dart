import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/dot_spinner.dart';
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

  Widget view({
    UiFlowStatus status = UiFlowStatus.idle,
    VoidCallback? onRetrySetup,
    Future<void> Function(String, String, String)? onLogin,
  }) =>
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SelfHostLoginView(
          initialUrl: 'https://server.test',
          initialEmail: 'a@test',
          initialPassword: 'pw',
          status: status,
          pocoMessage: 'hi',
          pocoSequence: const [],
          pocoHistory: const [],
          onDeploy: () {},
          onLogin: onLogin ?? (_, __, ___) async {},
          onRetrySetup: onRetrySetup,
        ),
      );

  testWidgets('while logging in the footer shows a spinner, not next',
      (tester) async {
    await tester.pumpWidget(view(status: UiFlowStatus.loading));

    expect(find.text('next'), findsNothing);
    expect(find.byType(DotSpinner), findsOneWidget);
    expect(find.text('authenticating'), findsOneWidget);
  });

  testWidgets('after a successful login the footer stays busy', (tester) async {
    await tester.pumpWidget(view(status: UiFlowStatus.success));

    expect(find.text('next'), findsNothing);
    expect(find.byType(DotSpinner), findsOneWidget);
    expect(find.text('connected, finishing setup…'), findsOneWidget);
  });

  testWidgets('a stalled setup offers retry in the footer', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
        view(status: UiFlowStatus.success, onRetrySetup: () => retries++));

    expect(find.byType(DotSpinner), findsNothing);
    await tester.tap(find.text('retry'));
    expect(retries, 1);
  });

  testWidgets('submitting from next dismisses the keyboard', (tester) async {
    var logins = 0;
    await tester.pumpWidget(view(onLogin: (_, __, ___) async => logins++));
    await tester.showKeyboard(find.byType(EditableText).last);
    expect(
        tester
            .widget<EditableText>(find.byType(EditableText).last)
            .focusNode
            .hasFocus,
        isTrue);

    await tester.tap(find.text('next'));
    await tester.pump();

    expect(logins, 1);
    expect(
        tester
            .widget<EditableText>(find.byType(EditableText).last)
            .focusNode
            .hasFocus,
        isFalse);
  });

  testWidgets('submitting from the password field dismisses the keyboard',
      (tester) async {
    var logins = 0;
    await tester.pumpWidget(view(onLogin: (_, __, ___) async => logins++));
    await tester.showKeyboard(find.byType(EditableText).last);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(logins, 1);
    expect(
        tester
            .widget<EditableText>(find.byType(EditableText).last)
            .focusNode
            .hasFocus,
        isFalse);
  });

  for (final (name, size) in [
    ('iPad landscape', const Size(1180, 820)),
    ('iPad portrait', const Size(820, 1180)),
    ('phone', const Size(390, 844)),
  ]) {
    testWidgets(
        '$name: the focused password field and next stay above the keyboard',
        (tester) async {
      const keyboard = 380.0;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(view());
      final password = find.byType(EditableText).last;
      await tester.showKeyboard(password);
      tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final visibleBottom = size.height - keyboard;
      expect(tester.getRect(password).bottom, lessThanOrEqualTo(visibleBottom));
      expect(tester.getRect(password).top, greaterThanOrEqualTo(0));
      expect(tester.getRect(find.text('next')).bottom,
          lessThanOrEqualTo(visibleBottom));
    });
  }
}
