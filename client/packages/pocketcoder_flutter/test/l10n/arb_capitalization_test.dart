import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// SYSTEM_ERROR:/UNABLE_TO_LOAD_BOOT_LOGS are identifiers, not a label.
const _allowedUppercaseKeys = {
  'bootLoadError',
  'proFeatureReady',
  'pocketCoderProgressFailed',
  'deploymentGpuBadge',
};

bool _isEntirelyUppercase(String value) {
  final letters = value.runes.where(
    (r) => String.fromCharCode(r).toUpperCase() != String.fromCharCode(r).toLowerCase(),
  );
  if (letters.isEmpty) return false;
  return letters.every(
    (r) => String.fromCharCode(r) == String.fromCharCode(r).toUpperCase(),
  );
}

void main() {
  test('no ARB value is entirely uppercase except the explicit allowlist', () {
    final arbFile = File('lib/l10n/app_en.arb');
    expect(arbFile.existsSync(), isTrue, reason: 'app_en.arb should exist at ${arbFile.path}');

    final Map<String, dynamic> data =
        jsonDecode(arbFile.readAsStringSync()) as Map<String, dynamic>;

    final offenders = <String>[];
    data.forEach((key, value) {
      if (key.startsWith('@')) return;
      if (value is! String) return;
      if (!_isEntirelyUppercase(value)) return;
      if (_allowedUppercaseKeys.contains(key)) return;
      offenders.add('$key: "$value"');
    });

    expect(
      offenders,
      isEmpty,
      reason: 'entirely-uppercase ARB values outside the allowlist:\n${offenders.join('\n')}',
    );
  });

  test('every allowlisted key still exists and is still uppercase', () {
    final arbFile = File('lib/l10n/app_en.arb');
    final Map<String, dynamic> data =
        jsonDecode(arbFile.readAsStringSync()) as Map<String, dynamic>;

    for (final key in _allowedUppercaseKeys) {
      expect(data.containsKey(key), isTrue, reason: '$key should exist in app_en.arb');
      final value = data[key];
      expect(value, isA<String>());
      expect(
        _isEntirelyUppercase(value as String),
        isTrue,
        reason: '$key is allowlisted as uppercase but is no longer uppercase '
            '-- remove it from the allowlist',
      );
    }
  });
}
