import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/infrastructure/security/password_generator.dart';

void main() {
  group('PasswordGenerator', () {
    late PasswordGenerator generator;

    setUp(() {
      generator = PasswordGenerator();
    });

    group('generatePassword', () {
      test('generates password with exactly 20 characters', () async {
        for (int i = 0; i < 100; i++) {
          final password = await generator.generatePassword();
          expect(password.length, equals(20),
              reason: 'Password $i should be exactly 20 characters');
        }
      });

      test('generated password contains at least 4 uppercase letters', () async {
        for (int i = 0; i < 100; i++) {
          final password = await generator.generatePassword();
          final uppercaseCount = password.runes
              .where((r) => 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.contains(String.fromCharCode(r)))
              .length;
          expect(uppercaseCount, greaterThanOrEqualTo(4),
              reason: 'Password $i should have at least 4 uppercase letters');
        }
      });

      test('generated password contains at least 4 lowercase letters', () async {
        for (int i = 0; i < 100; i++) {
          final password = await generator.generatePassword();
          final lowercaseCount = password.runes
              .where((r) => 'abcdefghijklmnopqrstuvwxyz'.contains(String.fromCharCode(r)))
              .length;
          expect(lowercaseCount, greaterThanOrEqualTo(4),
              reason: 'Password $i should have at least 4 lowercase letters');
        }
      });

      test('generated password contains at least 4 digits', () async {
        for (int i = 0; i < 100; i++) {
          final password = await generator.generatePassword();
          final digitCount = password.runes
              .where((r) => '0123456789'.contains(String.fromCharCode(r)))
              .length;
          expect(digitCount, greaterThanOrEqualTo(4),
              reason: 'Password $i should have at least 4 digits');
        }
      });

      test('generated password contains at least 4 special characters', () async {
        for (int i = 0; i < 100; i++) {
          final password = await generator.generatePassword();
          final specialCount = password.runes
              .where((r) => '!@#\$%^&*'.contains(String.fromCharCode(r)))
              .length;
          expect(specialCount, greaterThanOrEqualTo(4),
              reason: 'Password $i should have at least 4 special characters');
        }
      });

      test('generated password only contains valid characters', () async {
        final validChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#\$%^&*';
        for (int i = 0; i < 100; i++) {
          final password = await generator.generatePassword();
          for (final char in password.runes) {
            final charStr = String.fromCharCode(char);
            expect(validChars.contains(charStr), isTrue,
                reason: 'Password $i contains invalid character: $charStr');
          }
        }
      });

      test('generated passwords are not identical (randomness)', () async {
        final passwords = <String>{};
        for (int i = 0; i < 50; i++) {
          passwords.add(await generator.generatePassword());
        }
        // With cryptographically secure random, duplicates are extremely unlikely
        expect(passwords.length, greaterThan(1),
            reason: 'Generated passwords should be unique');
      });
    });

    group('generateAdminPassword', () {
      test('generates admin password with correct requirements', () async {
        for (int i = 0; i < 50; i++) {
          final password = await generator.generateAdminPassword();
          expect(password.length, equals(20));
        }
      });
    });

    group('generateRootPassword', () {
      test('generates root password with correct requirements', () async {
        for (int i = 0; i < 50; i++) {
          final password = await generator.generateRootPassword();
          expect(password.length, equals(20));
        }
      });
    });
  });
}