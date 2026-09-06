import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ascii_art.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/poco_animator.dart';

void main() {
  String faceText(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('poco-face'))).data ?? '';

  testWidgets('isAgentTurn true shows the thinking face and does not cycle',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PocoAnimator(isAgentTurn: true)),
    ));

    expect(faceText(tester), PocoExpression.thinking);

    await tester.pump(const Duration(seconds: 10));
    expect(faceText(tester), PocoExpression.thinking,
        reason: 'thinking face must not cycle to something else on its own');
  });

  testWidgets(
      'flipping isAgentTurn true->false settles on one random happy face '
      'and stops', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PocoAnimator(isAgentTurn: true)),
    ));
    expect(faceText(tester), PocoExpression.thinking);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PocoAnimator(isAgentTurn: false)),
    ));
    final settled = faceText(tester);
    expect(PocoExpression.greenHappy, contains(settled));

    await tester.pump(const Duration(seconds: 10));
    expect(faceText(tester), settled,
        reason: 'must freeze on the settled happy face, not keep cycling');
  });

  testWidgets('flipping isAgentTurn false->true goes back to thinking',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PocoAnimator(isAgentTurn: false)),
    ));
    expect(PocoExpression.greenHappy, contains(faceText(tester)));

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PocoAnimator(isAgentTurn: true)),
    ));
    expect(faceText(tester), PocoExpression.thinking);
  });

  testWidgets('isAgentTurn null preserves legacy random idle cycling',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PocoAnimator()),
    ));
    expect(PocoExpression.greenHappy, contains(faceText(tester)));

    final first = faceText(tester);
    var changed = false;
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 2000));
      if (faceText(tester) != first) {
        changed = true;
        break;
      }
    }
    expect(changed, isTrue,
        reason: 'legacy behavior keeps cycling forever when no turn state '
            'is provided');
  });
}
