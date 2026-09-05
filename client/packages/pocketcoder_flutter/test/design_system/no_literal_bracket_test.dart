// FOSS/test/design_system/no_literal_bracket_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Brackets belong to StatusMarker (for [ ok ]) and the action widget
/// (for angle bracket actions). Hand-typed brackets in Text widgets break
/// visual consistency and take wrong colors. These files are owned by
/// later tasks that will wrap text in proper marker/action widgets.
const _bracketExemptions = {
  'lib/presentation/files/widgets/file_browser_view.dart', // [DIR]/[FILE] markers -- no task in this plan owns this, flagged as a known gap
  'lib/presentation/chat/elicitation_card.dart', // No task in this plan currently owns bracket fixes here — flagged as a known gap
  'lib/presentation/core/widgets/terminal_checkbox.dart', // [X]/[ ] checkbox glyph -- no task in this plan owns this, flagged as a known gap
  'lib/presentation/chat/thinking_block.dart', // '[ THOUGHTS ]' -- no task in this plan owns this, flagged as a known gap
  'lib/presentation/chat/widgets/inline_approval.dart', // Task 15: spec section 8 mandates literal [!] eyebrow and [requestId] brackets -- neither is a StatusMarker glyph, so no role-based primitive fits
  'lib/presentation/onboarding/widgets/harness_choice_card.dart', // No task in this plan currently owns this — flagged as a known gap, not silently hidden
};

void main() {
  test('no literal brackets in Text widgets', () {
    final offenders = <String>[];
    for (final f in Directory('lib/presentation').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (_bracketExemptions.any(f.path.endsWith)) continue;

      final content = f.readAsStringSync();
      final lines = content.split('\n');

      // Scan for Text( or Text.rich( followed (possibly on next line) by a string with brackets
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];

        // Check if this line has Text( or Text.rich(
        if (line.contains('Text(') || line.contains('Text.rich(')) {
          // Look for brackets on this line or the next few lines
          for (var j = i; j < (i + 3).clamp(0, lines.length); j++) {
            final searchLine = lines[j];
            // Skip lines with ${} or [' (false positives from interpolation/dict access)
            if (searchLine.contains(r'${') || searchLine.contains(r"['")) {
              continue;
            }
            // Match string literals containing [ or <
            if (searchLine.contains(RegExp(r'"[^"]*[\[<][^"]*"')) ||
                searchLine.contains(RegExp(r"'[^']*[\[<][^']*'"))) {
              offenders.add('${f.path}:${j + 1}  ${searchLine.trim()}');
              break; // Only report once per Text call
            }
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
