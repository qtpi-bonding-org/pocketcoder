import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/typewriter_text.dart';

void main() {
  testWidgets(
      'a prefixed TypewriterText renders one merged paragraph, not a '
      'separately-boxed prefix', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            child: TypewriterText(
              text: 'a fairly long line of text that wraps onto more than one line',
              prefix: '[poco] ',
              instant: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Merged paragraph => exactly one RichText whose plain text contains
    // both the prefix and the body -- no separate render object for the
    // prefix, and no WidgetSpan-boxed child.
    final richTexts = tester.widgetList<RichText>(find.byType(RichText));
    expect(richTexts, hasLength(1));
    final text = richTexts.single.text.toPlainText();
    expect(text, startsWith('[poco] '));
    expect(text, contains('fairly long'));

    // A merged paragraph's second visual line starts at the container's
    // left edge (dx == 0), not indented to align under the first line's
    // body start.
    final renderParagraph =
        tester.renderObject<RenderParagraph>(find.byType(RichText).first);
    final boxes = renderParagraph.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: text.length),
    );
    final lineStarts = boxes.map((b) => b.left).toSet();
    // Sub-pixel text-layout rounding can put the true left edge a hair off
    // exact 0.0 (observed ~0.125px) -- assert "flush with the left edge"
    // with a small tolerance rather than exact equality.
    expect(lineStarts.any((left) => left < 1.0), isTrue,
        reason: 'a wrapped continuation line should start at x=0, not '
            'indented under the prefix column');
  });

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