import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/dot_spinner.dart';

void main() {
  Widget wrap(Widget child, {bool reduceMotion = false}) => MaterialApp(
        theme: AppTheme.darkTheme,
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Scaffold(body: Center(child: child)),
        ),
      );

  testWidgets('occupies exactly one character cell', (tester) async {
    await tester.pumpWidget(wrap(const DotSpinner()));
    final size = tester.getSize(find.byType(DotSpinner));
    expect(size.width, AppSizes.ch);
    expect(size.height, AppSizes.line);
    // Let the repeating timer stop before the test ends.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the gap travels, so the cell repaints', (tester) async {
    await tester.pumpWidget(wrap(const DotSpinner()));
    final first = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(DotSpinner),
        matching: find.byType(CustomPaint),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final second = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(DotSpinner),
        matching: find.byType(CustomPaint),
      ),
    );
    expect(second.painter!.shouldRepaint(first.painter!), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('reduced motion holds one frame', (tester) async {
    await tester.pumpWidget(wrap(const DotSpinner(), reduceMotion: true));
    final first = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(DotSpinner),
        matching: find.byType(CustomPaint),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final second = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(DotSpinner),
        matching: find.byType(CustomPaint),
      ),
    );
    expect(second.painter!.shouldRepaint(first.painter!), isFalse);
  });
}
