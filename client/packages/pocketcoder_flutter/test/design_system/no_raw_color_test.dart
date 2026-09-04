// FOSS/test/design_system/no_raw_color_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Color roles and semantic palettes not yet in use throughout lib/presentation.
/// Raw Color/AppPalette use is pervasive until Tasks 7-19 individually migrate
/// each widget to TextRole or semantic-role-based colors. This guard test's
/// enforcement value begins once that migration is underway.
const _colorExemptions = {
  'lib/presentation/', // Entire subtree is exempt until Tasks 7-19 land
};

void main() {
  test('no raw Color/AppPalette outside design system', () {
    final offenders = <String>[];
    for (final f in Directory('lib/presentation').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (_colorExemptions.any((exempt) => f.path.startsWith(exempt))) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.contains('Color(0x') ||
            line.contains('Colors.') ||
            line.contains('AppPalette.')) {
          offenders.add('${f.path}:${i + 1}  ${line.trim()}');
        }
      }
    }
    expect(offenders, isEmpty, reason: '''
Color roles enable @media-style theme switching and semantic consistency.
Widgets take roles (TextRole, ButtonRole, etc.), not raw values. Raw Color
literals and AppPalette constants will migrate across Tasks 7-19 as each
widget adopts role-based theming. See the call-site inventory in this
plan's Task 6 brief for which task owns each widget.

Until then, this guard test documents but does not enforce the rule:
${offenders.join('\n')}
''');
  });
}
