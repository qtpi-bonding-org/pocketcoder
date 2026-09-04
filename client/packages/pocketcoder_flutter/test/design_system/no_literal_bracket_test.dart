// FOSS/test/design_system/no_literal_bracket_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Brackets belong to StatusMarker (for [ ok ]) and the action widget
/// (for angle bracket actions). Hand-typed brackets in Text widgets break
/// visual consistency and take wrong colors. These files are owned by
/// later tasks that will wrap text in proper marker/action widgets.
const _bracketExemptions = {
  'lib/presentation/core/widgets/terminal_status_glyph.dart', // Task 10: Markers and loader split
  'lib/presentation/core/widgets/terminal_loading_indicator.dart', // Task 10: Markers and loader split
  'lib/presentation/core/widgets/bios_action_strip.dart', // Task 14: Dialog actions and action strips to angle brackets
  'lib/presentation/files/widgets/file_browser_view.dart', // Task 10: [DIR]/[FILE] markers to proper marker widget
  'lib/presentation/agent/widgets/config_picker.dart', // False positive: brackets are from dict access, not string literals
};

void main() {
  test('no literal brackets in Text widgets', () {
    final offenders = <String>[];
    for (final f in Directory('lib/presentation').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (_bracketExemptions.any(f.path.endsWith)) continue;

      final content = f.readAsStringSync();
      final lines = content.split('\n');

      // Simple scan: look for Text( followed by a string with brackets
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // Check if line contains Text( and has brackets
        if (line.contains('Text(') || line.contains('Text.rich(')) {
          // Look for [ or < in string literals within Text calls
          if (line.contains(RegExp(r'"[^"]*[\[<][^"]*"')) ||
              line.contains(RegExp(r"'[^']*[\[<][^']*'"))) {
            offenders.add('${f.path}:${i + 1}  ${line.trim()}');
          }
        }
      }
    }
    expect(offenders, isEmpty, reason: '''
Brackets [ ], < >, [ ok ], [!], etc. belong to StatusMarker and action
widgets, not in raw Text. Hand-typing brackets breaks visual consistency
and color cohesion. Tasks 10, 13, and 14 will wrap text in proper widgets.

Offending lines:
${offenders.join('\n')}
''');
  });
}
