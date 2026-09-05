import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/section_header.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

void main() {
  testWidgets('renders a bullet and a lowercase name, no divider',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SectionHeader(name: 'services')),
    ));
    expect(find.text('●'), findsOneWidget); // the bullet
    expect(find.text('services'), findsOneWidget);
    expect(find.byType(Divider), findsNothing,
        reason: 'the divider is the settings-utility tell (spec section 2)');
  });

  testWidgets('bullet takes the aggregate state colour', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
          body:
              SectionHeader(name: 'gatekeeper', state: SectionState.attention)),
    ));
    final bullet = tester.widget<TerminalText>(find.byType(TerminalText).first);
    expect(bullet.role, TextRole.warn);
  });

  testWidgets('a section with no state concept is green', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SectionHeader(name: 'about')),
    ));
    final bullet = tester.widget<TerminalText>(find.byType(TerminalText).first);
    expect(bullet.role, TextRole.ok);
  });
}
