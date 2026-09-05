// FOSS/test/design_system/no_font_size_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// ASCII art is a picture made of glyphs, sized like an image. Everything else
/// is text at the one body size.
const _artExemptions = {
  'lib/presentation/core/widgets/ascii_art.dart',
  'lib/presentation/core/widgets/ascii_logo.dart',
  'lib/presentation/core/widgets/poco_bubble.dart', // Poco face sizing
  'lib/presentation/core/widgets/poco_animator.dart', // Poco animated face sizing
  'lib/presentation/boot/boot_view.dart', // Poco art sizing on boot screen
};

/// These files were owned by earlier tasks; all have landed clean, so this
/// set is empty. Kept as a named hook rather than removed entirely -- add a
/// file here (with a task reference) only for a genuinely temporary,
/// in-progress migration, and remove it the moment that migration lands.
const _deferredExemptions = <String>{};

void main() {
  test('no fontSize outside the design system', () {
    final offenders = <String>[];
    for (final f in Directory('lib/presentation').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (_artExemptions.any(f.path.endsWith)) continue;
      if (_deferredExemptions.any(f.path.endsWith)) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('fontSize')) {
          offenders.add('${f.path}:${i + 1}  ${lines[i].trim()}');
        }
      }
    }
    expect(offenders, isEmpty, reason: '''
The interface has ONE text size. Hierarchy comes from TextRole
(dim / body / bright+bold), indentation and blank lines -- never from scale.
A type scale in a monospace font is what made this app read as a BIOS setup
utility rather than a terminal.

Use TextRole instead of a TextStyle with a size:
${offenders.join('\n')}
''');
  });
}
