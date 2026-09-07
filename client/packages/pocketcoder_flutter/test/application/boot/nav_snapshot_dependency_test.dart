import 'package:flutter_test/flutter_test.dart';
import 'package:nav_snapshot/nav_snapshot.dart';

void main() {
  test('nav_snapshot resolves from pocketcoder_flutter', () {
    final part = SnapshotPart<int>.ready('probe', 1);
    expect(part.peek().valueOrNull, 1);
  });
}
