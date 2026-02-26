import 'dart:math';
import 'package:injectable/injectable.dart';
import 'package:flutter_aeroform/domain/security/i_password_generator.dart';

/// Password generator implementation using cryptographically secure random
/// number generation
@LazySingleton(as: IPasswordGenerator)
class PasswordGenerator implements IPasswordGenerator {
  static const int _passwordLength = 20;
  static const int _minUppercase = 4;
  static const int _minLowercase = 4;
  static const int _minDigits = 4;
  static const int _minSpecial = 4;
  static const String _uppercaseLetters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const String _lowercaseLetters = 'abcdefghijklmnopqrstuvwxyz';
  static const String _digits = '0123456789';
  static const String _specialCharacters = '!@#\$%^&*';

  PasswordGenerator();

  @override
  Future<String> generatePassword() async {
    return _generatePassword();
  }

  @override
  Future<String> generateAdminPassword() async {
    return _generatePassword();
  }

  @override
  Future<String> generateRootPassword() async {
    return _generatePassword();
  }

  String _generatePassword() {
    final random = Random.secure();
    final password = StringBuffer();

    // Add required minimum characters
    for (int i = 0; i < _minUppercase; i++) {
      password.write(_uppercaseLetters[random.nextInt(_uppercaseLetters.length)]);
    }
    for (int i = 0; i < _minLowercase; i++) {
      password.write(_lowercaseLetters[random.nextInt(_lowercaseLetters.length)]);
    }
    for (int i = 0; i < _minDigits; i++) {
      password.write(_digits[random.nextInt(_digits.length)]);
    }
    for (int i = 0; i < _minSpecial; i++) {
      password.write(_specialCharacters[random.nextInt(_specialCharacters.length)]);
    }

    // Fill remaining characters with random selection from all character sets
    final remainingLength = _passwordLength - password.length;
    final allCharacters = '$_uppercaseLetters$_lowercaseLetters$_digits$_specialCharacters';
    for (int i = 0; i < remainingLength; i++) {
      password.write(allCharacters[random.nextInt(allCharacters.length)]);
    }

    // Shuffle the password to avoid predictable patterns
    return _shuffleString(password.toString(), random);
  }

  String _shuffleString(String input, Random random) {
    final chars = input.split('');
    for (int i = chars.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final temp = chars[i];
      chars[i] = chars[j];
      chars[j] = temp;
    }
    return chars.join();
  }
}