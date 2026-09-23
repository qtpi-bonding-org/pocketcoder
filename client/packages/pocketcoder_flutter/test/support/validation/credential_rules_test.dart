import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/support/validation/credential_rules.dart';

void main() {
  test('PocketBase users-collection password bounds', () {
    expect(kPocketBasePasswordMinLength, 8);
    expect(kPocketBasePasswordMaxLength, 71);
  });

  group('hasSurroundingWhitespace', () {
    for (final value in [' a', 'a ', '\ta', 'a\n', ' ', 'a\r\n']) {
      test('flags ${value.codeUnits}', () {
        expect(hasSurroundingWhitespace(value), isTrue);
      });
    }
    for (final value in ['', 'a', 'a b', 'a\tb']) {
      test('accepts ${value.codeUnits}', () {
        expect(hasSurroundingWhitespace(value), isFalse);
      });
    }
  });

  group('containsLineBreakOrTab', () {
    for (final value in ['a\nb', 'a\rb', 'a\tb', '\n']) {
      test('flags ${value.codeUnits}', () {
        expect(containsLineBreakOrTab(value), isTrue);
      });
    }
    for (final value in ['', 'a b', ' a ']) {
      test('accepts ${value.codeUnits}', () {
        expect(containsLineBreakOrTab(value), isFalse);
      });
    }
  });

  test('passwordRuneLength counts code points, not UTF-16 units', () {
    expect(passwordRuneLength('abcdefg😀'), 8);
    expect('abcdefg😀'.length, 9);
  });

  group('emailIssue', () {
    test('valid mixed-case email has no issue', () {
      expect(emailIssue('User.Name@Example.com'), isNull);
    });
    test('surrounding whitespace wins over format', () {
      expect(emailIssue(' user@example.com'), EmailIssue.surroundingWhitespace);
      expect(emailIssue('user@example.com\n'),
          EmailIssue.surroundingWhitespace);
    });
    test('bad format', () {
      expect(emailIssue('user@localhost'), EmailIssue.invalidFormat);
      expect(emailIssue('not an email'), EmailIssue.invalidFormat);
    });
  });

  group('newPasswordIssue', () {
    test('8 to 71 runes is accepted, spaces inside are legal', () {
      expect(newPasswordIssue('pass word'), isNull);
      expect(newPasswordIssue('a' * 71), isNull);
      expect(newPasswordIssue('😀' * 8), isNull);
    });
    test('under 8 runes is too short', () {
      expect(newPasswordIssue('1234567'), PasswordIssue.tooShort);
      expect(newPasswordIssue('😀' * 7), PasswordIssue.tooShort);
    });
    test('over 71 runes is too long', () {
      expect(newPasswordIssue('a' * 72), PasswordIssue.tooLong);
      expect(newPasswordIssue('😀' * 72), PasswordIssue.tooLong);
    });
    test('surrounding whitespace is rejected', () {
      expect(newPasswordIssue(' password'), PasswordIssue.surroundingWhitespace);
      expect(newPasswordIssue('password '), PasswordIssue.surroundingWhitespace);
    });
  });

  group('loginPasswordLooksPasted', () {
    test('flags surrounding whitespace or line breaks/tabs', () {
      expect(loginPasswordLooksPasted(' secret'), isTrue);
      expect(loginPasswordLooksPasted('sec\tret'), isTrue);
      expect(loginPasswordLooksPasted('sec\nret'), isTrue);
    });
    test('accepts inner spaces and short passwords', () {
      expect(loginPasswordLooksPasted('my pass'), isFalse);
      expect(loginPasswordLooksPasted('pw'), isFalse);
      expect(loginPasswordLooksPasted(''), isFalse);
    });
  });
}
