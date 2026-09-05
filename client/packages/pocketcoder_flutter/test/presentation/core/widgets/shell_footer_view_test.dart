import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';
import 'package:pocketcoder_flutter/design_system/primitives/shell_footer.dart';
import 'package:pocketcoder_flutter/design_system/primitives/nav_pillar.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/shell_footer_view.dart';

void main() {
  testWidgets('pillar footer renders four plain-word pillars in order',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: ShellFooterView(
              footer:
                  PillarFooter(active: NavPillar.status, onSelect: (_) {}))),
    ));
    for (final label in ['chat', 'config', 'status', 'control']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets(
      'pillar labels are maxLines: 1, so a width regression fails as visible '
      'truncation, not a silent mid-word wrap', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: ShellFooterView(
              footer:
                  PillarFooter(active: NavPillar.status, onSelect: (_) {}))),
    ));
    for (final label in ['chat', 'config', 'status', 'control']) {
      final text = tester.widget<Text>(find.text(label));
      expect(text.maxLines, 1);
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
    expect(find.text('control'), findsNothing);
    expect(find.text('chat'), findsOneWidget);
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

  testWidgets('pillar footer with extra actions renders all labels',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: ShellFooterView(
          footer: PillarFooter(
            active: NavPillar.chat,
            onSelect: (_) {},
            extraActions: [
              TerminalAction(
                label: 'files',
                onTap: () {},
                kind: ActionKind.neutral,
              ),
            ],
          ),
        ),
      ),
    ));

    // Should render four pillars plus the extra action
    expect(find.text('chat'), findsOneWidget);
    expect(find.text('config'), findsOneWidget);
    expect(find.text('status'), findsOneWidget);
    expect(find.text('control'), findsOneWidget);
    expect(find.text('files'), findsOneWidget);
  });

  testWidgets(
      'pillar footer at 320dp with extra action fits five items on one row '
      'with no overflow', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(320, 640));

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Align(
        alignment: Alignment.topLeft,
        child: ShellFooterView(
          footer: PillarFooter(
            active: NavPillar.chat,
            onSelect: (_) {},
            extraActions: [
              TerminalAction(
                label: 'files',
                onTap: () {},
                kind: ActionKind.neutral,
              ),
            ],
          ),
        ),
      ),
    ));

    // All five items fit one row without wrapping (only possible unbracketed).
    for (final label in ['chat', 'config', 'status', 'control', 'files']) {
      expect(find.text(label), findsOneWidget,
          reason: 'Single-row constraint; label $label must render whole');
      final text = tester.widget<Text>(find.text(label));
      expect(text.maxLines, 1,
          reason: 'Label $label must not wrap mid-word');
    }

    // Check that there are no render exceptions (overflow)
    final exception = tester.takeException();
    expect(exception, isNull,
        reason: 'Should not have render overflow at 320dp with 5 unbracketed items');
  });

  testWidgets('pillar footer with no extra actions renders four unbracketed labels',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: ShellFooterView(
          footer: PillarFooter(
            active: NavPillar.chat,
            onSelect: (_) {},
            extraActions: const [],
          ),
        ),
      ),
    ));

    // Should render only four pillars
    expect(find.text('chat'), findsOneWidget);
    expect(find.text('config'), findsOneWidget);
    expect(find.text('status'), findsOneWidget);
    expect(find.text('control'), findsOneWidget);

    // Should not render any extra actions
    expect(find.text('files'), findsNothing);
  });
}
