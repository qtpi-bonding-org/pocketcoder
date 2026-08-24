import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_action_strip.dart';

Widget _app(Widget child) =>
    MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: child));

void main() {
  testWidgets('renders one button per action and forwards taps',
      (tester) async {
    var pausedTapped = false;
    await tester.pumpWidget(_app(BiosActionStrip(actions: [
      BiosActionStripItem(label: 'PAUSE', onTap: () => pausedTapped = true),
      BiosActionStripItem(label: 'DELETE', onTap: () {}),
    ])));

    expect(find.text('PAUSE'), findsOneWidget);
    expect(find.text('DELETE'), findsOneWidget);

    await tester.tap(find.text('PAUSE'));
    expect(pausedTapped, isTrue);
  });

  testWidgets('an active action inverts fill/text (matches TerminalFooter)',
      (tester) async {
    await tester.pumpWidget(_app(BiosActionStrip(actions: [
      BiosActionStripItem(label: 'ALLOW', onTap: () {}, isActive: true),
    ])));

    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(BiosActionStrip),
        matching: find.byType(Container),
      ),
    );
    final decoration = container.decoration as BoxDecoration;
    final colors = AppTheme.lightTheme.colorScheme;
    expect(decoration.color, colors.onSurface);
  });
}
