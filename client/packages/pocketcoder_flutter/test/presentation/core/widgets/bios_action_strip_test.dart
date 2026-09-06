import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_action_strip.dart';

Widget _app(Widget child) =>
    MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: child));

void main() {
  testWidgets('renders one button per action and forwards taps',
      (tester) async {
    var pausedTapped = false;
    await tester.pumpWidget(_app(BiosActionStrip(actions: [
      BiosActionStripItem(label: 'pause', onTap: () => pausedTapped = true),
      BiosActionStripItem(label: 'delete', onTap: () {}),
    ])));

    expect(find.text('<pause>'), findsOneWidget);
    expect(find.text('<delete>'), findsOneWidget);

    await tester.tap(find.text('<pause>'));
    expect(pausedTapped, isTrue);
  });

  testWidgets('an active action inverts fill/text (matches TerminalFooter)',
      (tester) async {
    await tester.pumpWidget(_app(BiosActionStrip(actions: [
      BiosActionStripItem(label: 'allow', onTap: () {}, isActive: true),
    ])));

    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(BiosActionStrip),
        matching: find.byType(Container),
      ),
    );
    expect(container.color, ActionKind.neutral.role.color);
  });
}
