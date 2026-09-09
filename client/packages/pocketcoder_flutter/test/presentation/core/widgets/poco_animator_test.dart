import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ascii_art.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/poco_animator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/poco_gaze_scope.dart';

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

  testWidgets('tapping to the right of Poco while idle looks right',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
          body: PocoGazeScope(child: Center(child: PocoAnimator()))),
    ));

    final center = tester.getCenter(find.byType(PocoAnimator));
    await tester.tapAt(center + const Offset(200, 0));
    await tester.pump();

    expect(faceText(tester), PocoExpression.lookRight);
  });

  testWidgets('tapping to the left of Poco while idle looks left',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
          body: PocoGazeScope(child: Center(child: PocoAnimator()))),
    ));

    final center = tester.getCenter(find.byType(PocoAnimator));
    await tester.tapAt(center - const Offset(200, 0));
    await tester.pump();

    expect(faceText(tester), PocoExpression.lookLeft);
  });

  testWidgets('tapping close to Poco while idle looks neutral, not left/right',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
          body: PocoGazeScope(child: Center(child: PocoAnimator()))),
    ));

    final center = tester.getCenter(find.byType(PocoAnimator));
    await tester.tapAt(center + const Offset(5, 0));
    await tester.pump();

    expect(faceText(tester), PocoExpression.awake);
  });

  testWidgets('a tap does not override the thinking face', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
          body: PocoGazeScope(
              child: Center(child: PocoAnimator(isAgentTurn: true)))),
    ));

    final center = tester.getCenter(find.byType(PocoAnimator));
    await tester.tapAt(center + const Offset(200, 0));
    await tester.pump();

    expect(faceText(tester), PocoExpression.thinking,
        reason: 'thinking status must not be hidden by a tap-look override');
  });

  testWidgets('a tap does not override an active scripted sequence',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: PocoGazeScope(
              child: Center(
                  child: PocoAnimator(
        sequence: [(PocoExpression.sad, 10000)],
      )))),
    ));
    expect(faceText(tester), PocoExpression.sad);

    final center = tester.getCenter(find.byType(PocoAnimator));
    await tester.tapAt(center + const Offset(200, 0));
    await tester.pump();

    expect(faceText(tester), PocoExpression.sad,
        reason: 'a scripted onboarding beat must not be hidden by a tap');
  });

  testWidgets('a tap looks even when isAgentTurn is explicitly false',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
          body: PocoGazeScope(
              child: Center(child: PocoAnimator(isAgentTurn: false)))),
    ));
    expect(PocoExpression.greenHappy, contains(faceText(tester)));

    final center = tester.getCenter(find.byType(PocoAnimator));
    await tester.tapAt(center + const Offset(200, 0));
    await tester.pump();

    expect(faceText(tester), PocoExpression.lookRight,
        reason: 'chat passes a non-null isAgentTurn even while idle, so '
            'gaze must key off the thinking face, not turn-driven-ness');
  });

  testWidgets(
      'allowGazeDuringSequence lets a tap override an active scripted '
      'sequence', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: PocoGazeScope(
              child: Center(
                  child: PocoAnimator(
        sequence: [(PocoExpression.sad, 10000)],
        allowGazeDuringSequence: true,
      )))),
    ));
    expect(faceText(tester), PocoExpression.sad);

    final center = tester.getCenter(find.byType(PocoAnimator));
    await tester.tapAt(center + const Offset(200, 0));
    await tester.pump();

    expect(faceText(tester), PocoExpression.lookRight,
        reason: 'boot opts a scripted sequence into being tap-interruptible');
  });

  testWidgets(
      'allowGazeDuringSequence still defers to the thinking face',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
          body: PocoGazeScope(
              child: Center(
                  child: PocoAnimator(
        isAgentTurn: true,
        allowGazeDuringSequence: true,
      )))),
    ));

    final center = tester.getCenter(find.byType(PocoAnimator));
    await tester.tapAt(center + const Offset(200, 0));
    await tester.pump();

    expect(faceText(tester), PocoExpression.thinking,
        reason: 'thinking status must still win, even with the opt-in');
  });

  testWidgets('with no PocoGazeScope ancestor, a tap is a no-op',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: PocoAnimator())),
    ));
    expect(PocoExpression.greenHappy, contains(faceText(tester)));

    final center = tester.getCenter(find.byType(PocoAnimator));
    await tester.tapAt(center + const Offset(200, 0));
    await tester.pump();

    expect(PocoExpression.greenHappy, contains(faceText(tester)),
        reason: 'no scope means no gaze tracking, same as before this '
            'feature existed');
  });
}
