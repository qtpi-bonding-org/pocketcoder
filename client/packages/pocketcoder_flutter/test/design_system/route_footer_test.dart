import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every shell call site supplies a footer', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      if (!src.contains('PocketCoderShell(')) continue;
      if (src.contains('PocketCoderShell(') && !src.contains('footer:')) {
        offenders.add(f.path);
      }
    }
    expect(offenders, isEmpty);
  });
}
