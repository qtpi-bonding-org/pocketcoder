import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/summary_field.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

Widget _app(Widget child) =>
    MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: child));

void main() {
  testWidgets('renders the full label and value on separate lines, no ellipsis',
      (tester) async {
    const longValue = 'A very long value that would otherwise be truncated';
    await tester.pumpWidget(_app(const SummaryField(
      label: 'server provider',
      value: longValue,
    )));

    final labelFinder = find.text('server provider');
    final valueFinder = find.text(longValue);
    expect(labelFinder, findsOneWidget);
    expect(valueFinder, findsOneWidget);
    expect(tester.getTopLeft(valueFinder).dy,
        greaterThan(tester.getBottomLeft(labelFinder).dy - 1));
  });

  testWidgets('the label is dimmer than the value', (tester) async {
    await tester.pumpWidget(_app(const SummaryField(
      label: 'instance plan',
      value: 'linode 2gb',
    )));

    final label = tester.widget<TerminalText>(find.byType(TerminalText).at(0));
    final value = tester.widget<TerminalText>(find.byType(TerminalText).at(1));

    // The label should use TextRole.label style (dim color, w400)
    final labelText = tester.widget<Text>(
      find.descendant(of: find.byWidget(label), matching: find.byType(Text)),
    );
    expect(labelText.style?.color, TextRole.label.color);
    expect(labelText.style?.fontWeight, TextRole.label.weight);

    // The value should use TextRole.value style (bright color, w700)
    final valueText = tester.widget<Text>(
      find.descendant(of: find.byWidget(value), matching: find.byType(Text)),
    );
    expect(valueText.style?.color, TextRole.value.color);
    expect(valueText.style?.fontWeight, TextRole.value.weight);
  });
}
