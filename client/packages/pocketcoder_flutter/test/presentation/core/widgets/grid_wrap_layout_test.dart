import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/grid_wrap.dart';

// A tight test viewport would force SizedBox to the full 800px, so the
// Align releases the tight constraint and lets 320 actually apply.
Future<List<Offset>> _layout(WidgetTester tester, int count, double w) async {
  final keys = [for (var i = 0; i < count; i++) GlobalKey()];
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 320,
        child: GridWrap(children: [
          for (final k in keys) SizedBox(key: k, width: w, height: 20)
        ]),
      ),
    ),
  ));
  return [for (final k in keys) tester.getTopLeft(find.byKey(k))];
}

void main() {
  testWidgets('five items that do not fit take two rows, not three',
      (tester) async {
    // 5 x 90px needs 450 in a 320 box. A fixed 2-column fallback gives three
    // rows; balanced across the fewest rows that hold them it is 3 + 2.
    final offsets = await _layout(tester, 5, 90);
    expect(tester.takeException(), isNull);
    expect(offsets.map((o) => o.dy).toSet(), hasLength(2),
        reason: 'expected two rows, got \${offsets.map((o) => o.dy).toSet()}');
  });

  testWidgets('every child in a row gets its own position', (tester) async {
    // Positioning only the first two of a row left later children stacked
    // at the origin once rows could hold three.
    final offsets = await _layout(tester, 5, 90);
    expect(offsets.toSet(), hasLength(offsets.length));
  });

  testWidgets('items that already fit stay on one row', (tester) async {
    final offsets = await _layout(tester, 3, 60);
    expect(tester.takeException(), isNull);
    expect(offsets.map((o) => o.dy).toSet(), hasLength(1));
  });
}
