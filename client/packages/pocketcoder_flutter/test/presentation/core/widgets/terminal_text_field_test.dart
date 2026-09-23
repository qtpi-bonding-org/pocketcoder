import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';

void main() {
  Widget host(TerminalTextField field) => MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: field),
      );

  TextField textField(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField));

  testWidgets('defaults keep the previous field behavior', (tester) async {
    await tester.pumpWidget(host(TerminalTextField(
      controller: TextEditingController(),
      label: 'name',
    )));

    final field = textField(tester);
    expect(field.obscureText, isFalse);
    expect(field.keyboardType, TextInputType.text);
    expect(field.autocorrect, isTrue);
    expect(field.enableSuggestions, isTrue);
    expect(field.autofillHints, isNull);
    expect(field.decoration?.helperText, isNull);
    expect(find.text('show'), findsNothing);
    expect(find.text('hide'), findsNothing);
  });

  testWidgets('an obscured field is not revealable unless asked',
      (tester) async {
    await tester.pumpWidget(host(TerminalTextField(
      controller: TextEditingController(),
      label: 'password',
      obscureText: true,
    )));

    expect(textField(tester).obscureText, isTrue);
    expect(find.text('show'), findsNothing);
  });

  testWidgets('a revealable field toggles between show and hide',
      (tester) async {
    await tester.pumpWidget(host(TerminalTextField(
      controller: TextEditingController(text: 'secret'),
      label: 'password',
      obscureText: true,
      revealable: true,
    )));

    expect(textField(tester).obscureText, isTrue);
    await tester.tap(find.text('show'));
    await tester.pump();
    expect(textField(tester).obscureText, isFalse);
    expect(find.text('hide'), findsOneWidget);

    await tester.tap(find.text('hide'));
    await tester.pump();
    expect(textField(tester).obscureText, isTrue);
    expect(find.text('show'), findsOneWidget);
  });

  testWidgets('passes keyboard and autofill options through', (tester) async {
    await tester.pumpWidget(host(TerminalTextField(
      controller: TextEditingController(),
      label: 'email',
      keyboardType: TextInputType.emailAddress,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: const [AutofillHints.email],
    )));

    final field = textField(tester);
    expect(field.keyboardType, TextInputType.emailAddress);
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);
    expect(field.autofillHints, [AutofillHints.email]);
  });

  testWidgets('helper text shows as a warning without an error border',
      (tester) async {
    await tester.pumpWidget(host(TerminalTextField(
      controller: TextEditingController(),
      label: 'password',
      helperText: 'careful',
    )));

    expect(find.text('careful'), findsOneWidget);
    final decoration = textField(tester).decoration;
    expect(decoration?.errorText, isNull);
    final context = tester.element(find.byType(TextField));
    expect(decoration?.helperStyle?.color, context.terminalColors.warning);
  });
}
