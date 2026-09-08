import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/support/validation/email_format.dart';

// Cases mirror PocketBase's own EmailField validator (govalidator.IsEmail),
// minus its Unicode-domain allowance -- this check is intentionally
// ASCII-only and thus stricter there, never looser, than the server.
void main() {
  group('isValidEmailFormat', () {
    for (final valid in [
      'foo@bar.com',
      'x@x.x',
      'foo@bar.com.au',
      'foo+bar@bar.com',
      'foo@bar.coffee',
      'foo@bar.bar.coffee',
      'NathAn.daVIeS@DomaIn.cOM',
      'NATHAN.DAVIES@DOMAIN.CO.UK',
      'admin@example.com',
    ]) {
      test('accepts $valid', () {
        expect(isValidEmailFormat(valid), isTrue);
      });
    }

    for (final invalid in [
      '',
      'str',
      'invalidemail@',
      'invalid.com',
      '@invalid.com',
      'foo@bar.coffee..coffee',
      'admin@localhost',
      'admin',
      'admin@',
      '@example.com',
    ]) {
      test('rejects $invalid', () {
        expect(isValidEmailFormat(invalid), isFalse);
      });
    }
  });
}
