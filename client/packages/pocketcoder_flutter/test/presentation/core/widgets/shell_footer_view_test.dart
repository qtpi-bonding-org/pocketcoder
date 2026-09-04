import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/shell_footer.dart';
import 'package:pocketcoder_flutter/design_system/primitives/nav_pillar.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/shell_footer_view.dart';

void main() {
  testWidgets('pillar footer renders four angle-bracket pillars in order',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: ShellFooterView(
              footer:
                  PillarFooter(active: NavPillar.status, onSelect: (_) {}))),
    ));
    for (final label in ['<chat>', '<config>', '<status>', '<control>']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('pillar footer sits correctly at three items', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: ShellFooterView(
              footer: PillarFooter(
                  active: NavPillar.chat,
                  onSelect: (_) {},
                  available: const [
            NavPillar.chat,
            NavPillar.config,
            NavPillar.status
          ]))),
    ));
    expect(find.text('<control>'), findsNothing);
    expect(find.text('<chat>'), findsOneWidget);
  });

  testWidgets('wizard footer uses words and a counter, never arrows',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: ShellFooterView(
              footer: WizardFooter(
                  step: 3, totalSteps: 7, onNext: () {}, onBack: () {}))),
    ));
    expect(find.text('<back>'), findsOneWidget);
    expect(find.text('(3/7)'), findsOneWidget);
    expect(find.text('<next>'), findsOneWidget);
    expect(find.textContaining('▸'), findsNothing,
        reason: 'the navigate glyph means navigate-to-a-screen and nothing '
            'else');
  });

  test('a wizard footer cannot be stepless', () {
    expect(() => WizardFooter(step: 0, totalSteps: 7, onNext: () {}),
        throwsAssertionError);
  });
}
