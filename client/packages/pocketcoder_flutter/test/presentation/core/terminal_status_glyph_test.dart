import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_status_glyph.dart';

void main() {
  Future<Color?> colorFor(WidgetTester tester, TerminalStatus status) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: TerminalStatusGlyph(status: status)),
      ),
    );
    return tester.widget<Text>(find.byType(Text)).style?.color;
  }

  testWidgets('running and success use plain phosphor, not attention/white',
      (tester) async {
    final running = await colorFor(tester, TerminalStatus.running);
    expect(running, const Color(0xFF00B82A));
  });

  testWidgets('failure uses warning amber, not danger red', (tester) async {
    final failure = await colorFor(tester, TerminalStatus.failure);
    expect(failure, const Color(0xFFFFB100));
  });
}
