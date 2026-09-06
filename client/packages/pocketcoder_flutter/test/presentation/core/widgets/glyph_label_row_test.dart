import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/glyph_label_row.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

Widget _app(Widget child) =>
    MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: child));

void main() {
  testWidgets('renders the glyph and the child label', (tester) async {
    await tester.pumpWidget(_app(const GlyphLabelRow(
      glyph: '[+]',
      child: TerminalText('some requirement', role: TextRole.body),
    )));

    expect(find.text('[+]'), findsOneWidget);
    expect(find.text('some requirement'), findsOneWidget);
  });

  testWidgets('glyph renders in the label role', (tester) async {
    await tester.pumpWidget(_app(GlyphLabelRow(
      glyph: r'$',
      child: const TerminalText('harness', role: TextRole.body),
    )));

    final glyphText =
        tester.widget<TerminalText>(find.widgetWithText(TerminalText, r'$'));
    expect(glyphText.role, TextRole.label);
  });

  testWidgets('defaults to HSpace.x1 when no spacing is given', (tester) async {
    await tester.pumpWidget(_app(const GlyphLabelRow(
      glyph: '[+]',
      child: TerminalText('label', role: TextRole.body),
    )));

    final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
    // HSpace is CHARACTER-based ("one unit = one character width"), not the
    // pixel `space` token. These were numerically equal only while the font
    // advance was mis-measured at 0.5, which hid the conflation.
    expect(sizedBox.width, AppSizes.ch);
  });

  testWidgets('honors an explicit spacing override', (tester) async {
    await tester.pumpWidget(_app(GlyphLabelRow(
      glyph: r'$',
      spacing: HSpace.x2,
      child: const TerminalText('harness', role: TextRole.body),
    )));

    final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
    expect(sizedBox.width, AppSizes.ch * 2);
  });

  testWidgets('expands the child to fill remaining row space', (tester) async {
    await tester.pumpWidget(_app(const GlyphLabelRow(
      glyph: '[+]',
      child: TerminalText('label', role: TextRole.body),
    )));

    expect(find.byType(Expanded), findsOneWidget);
  });
}
