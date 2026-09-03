import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_status_glyph.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.terminalTheme,
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('defaults to a running glyph when no status is given',
      (tester) async {
    await tester.pumpWidget(_wrap(const TerminalLoadingIndicator()));
    final glyph =
        tester.widget<TerminalStatusGlyph>(find.byType(TerminalStatusGlyph));
    expect(glyph.status, TerminalStatus.running);
  });

  testWidgets('renders a failure glyph when status is failure', (tester) async {
    await tester.pumpWidget(
        _wrap(const TerminalLoadingIndicator(status: TerminalStatus.failure)));
    final glyph =
        tester.widget<TerminalStatusGlyph>(find.byType(TerminalStatusGlyph));
    expect(glyph.status, TerminalStatus.failure);
  });
}
