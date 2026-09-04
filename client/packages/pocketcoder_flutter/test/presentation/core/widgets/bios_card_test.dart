import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_action_strip.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_card.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_card.dart';

Widget _app(Widget child) =>
    MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: child));

void main() {
  testWidgets('renders header rows only when body/footer are omitted',
      (tester) async {
    await tester.pumpWidget(_app(const BiosCard(
      header: [Text('SERVER NAME')],
    )));

    expect(find.text('SERVER NAME'), findsOneWidget);
    expect(find.byType(BiosActionStrip), findsNothing);
    expect(find.byType(TerminalCard), findsOneWidget);
  });

  testWidgets('renders a custom body when provided', (tester) async {
    await tester.pumpWidget(_app(const BiosCard(
      header: [Text('ERROR: CHAT_001')],
      body: Text('full stack trace here'),
    )));

    expect(find.text('full stack trace here'), findsOneWidget);
  });

  testWidgets(
      'body is absent (collapsed) when null, matching the '
      'caller-owned expand/collapse pattern', (tester) async {
    await tester.pumpWidget(_app(const BiosCard(
      header: [Text('ERROR: CHAT_001')],
      body: null,
    )));

    expect(find.text('full stack trace here'), findsNothing);
  });

  testWidgets('renders a footer action strip when provided', (tester) async {
    await tester.pumpWidget(_app(BiosCard(
      header: const [Text('my-job')],
      footer: BiosActionStrip(actions: [
        BiosActionStripItem(label: 'PAUSE', onTap: () {}),
      ]),
    )));

    expect(find.text('PAUSE'), findsOneWidget);
  });
}
