import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/typewriter_text.dart';

void main() {
  testWidgets('instant: true renders full text on the first frame, no animation',
      (tester) async {
    var completed = false;
    await tester.pumpWidget(MaterialApp(
      home: TypewriterText(
        text: 'hello world',
        instant: true,
        onComplete: () => completed = true,
      ),
    ));

    // No pump() for elapsed time -- if this were still animating, only an
    // empty or partial string would be present on the very first frame.
    expect(find.text('hello world'), findsOneWidget);
    expect(completed, isTrue);
  });

  testWidgets('instant: false still animates incrementally (existing behavior)',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: TypewriterText(
        text: 'hello world',
        speed: Duration(milliseconds: 10),
      ),
    ));

    // Immediately after the first frame, nothing has had time to reveal yet.
    expect(find.text('hello world'), findsNothing);

    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('hello world'), findsOneWidget);
  });
}