import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/glyph_label_row.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

Widget _app(Widget child) =>
    MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: child));

void main() {
  testWidgets('renders the glyph and the child label', (tester) async {
    await tester.pumpWidget(_app(const GlyphLabelRow(
      glyph: '[+]',
      child: TerminalText('some requirement'),
    )));

    expect(find.text('[+]'), findsOneWidget);
    expect(find.text('some requirement'), findsOneWidget);
  });

  testWidgets('applies the given glyph color', (tester) async {
    await tester.pumpWidget(_app(GlyphLabelRow(
      glyph: r'$',
      color: Colors.red,
      child: const TerminalText('harness'),
    )));

    final glyphText = tester.widget<Text>(find.text(r'$'));
    expect(glyphText.style?.color, Colors.red);
  });

  testWidgets('defaults to HSpace.x1 when no spacing is given',
      (tester) async {
    await tester.pumpWidget(_app(const GlyphLabelRow(
      glyph: '[+]',
      child: TerminalText('label'),
    )));

    final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
    expect(sizedBox.width, AppSizes.space);
  });

  testWidgets('honors an explicit spacing override', (tester) async {
    await tester.pumpWidget(_app(GlyphLabelRow(
      glyph: r'$',
      spacing: HSpace.x2,
      child: const TerminalText('harness'),
    )));

    final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
    expect(sizedBox.width, AppSizes.space * 2);
  });

  testWidgets('expands the child to fill remaining row space',
      (tester) async {
    await tester.pumpWidget(_app(const GlyphLabelRow(
      glyph: '[+]',
      child: TerminalText('label'),
    )));

    expect(find.byType(Expanded), findsOneWidget);
  });
}
