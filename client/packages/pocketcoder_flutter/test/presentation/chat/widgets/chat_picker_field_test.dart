import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/chat/widgets/chat_picker_field.dart';

void main() {
  Future<void> pumpField(
    WidgetTester tester, {
    required List<String> options,
    String Function(String)? groupLabel,
    ValueChanged<String>? onSelected,
  }) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ChatPickerField<String>(
          label: 'field',
          dialogTitle: 'pick one',
          emptyLabel: 'select',
          options: options,
          selected: null,
          optionLabel: (o) => o,
          groupLabel: groupLabel,
          onSelected: onSelected ?? (_) {},
        ),
      ),
    ));
  }

  testWidgets('opening the picker shows a search field', (tester) async {
    await pumpField(tester, options: ['alpha', 'beta']);
    await tester.tap(find.text('select'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('typing into the search field filters the options',
      (tester) async {
    await pumpField(tester, options: ['alpha', 'beta']);
    await tester.tap(find.text('select'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'alp');
    await tester.pumpAndSettle();

    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('beta'), findsNothing);
  });

  testWidgets('a groupLabel renders a header above each group',
      (tester) async {
    await pumpField(
      tester,
      options: ['anthropic-model', 'openai-model'],
      groupLabel: (o) => o.startsWith('anthropic') ? 'Anthropic' : 'OpenAI',
    );
    await tester.tap(find.text('select'));
    await tester.pumpAndSettle();

    expect(find.text('Anthropic'), findsOneWidget);
    expect(find.text('OpenAI'), findsOneWidget);
  });
}
