import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/infrastructure/users/temp_password_generator.dart';

void main() {
  test('generateTempPassword produces an 8-char unambiguous-charset string',
      () {
    final p = generateTempPassword();
    expect(p.length, 8);
    expect(RegExp(r'^[A-HJ-NP-Za-hj-np-z2-9]+$').hasMatch(p), isTrue);
  });

  test('generateTempPassword is not deterministic', () {
    final a = generateTempPassword();
    final b = generateTempPassword();
    expect(a, isNot(b));
  });
}
