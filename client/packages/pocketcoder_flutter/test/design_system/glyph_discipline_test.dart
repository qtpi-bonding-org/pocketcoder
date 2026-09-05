import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every delimiter in the interface belongs to exactly one widget.
///
/// The vocabulary is six forms, each saying one thing (see `GlyphForm`, and
/// the bracket law in the widget spec). It only stays legible if each glyph
/// has one owner -- a hand-typed `[` somewhere else takes the wrong colour,
/// sits off the character grid, and quietly starts meaning a second thing.
///
/// This is deliberately about OWNERSHIP rather than absence: the glyphs must
/// exist, but only where the type system puts them.
const _owners = <String, Set<String>>{
  // `[ ok ]` status, plus the two states that are legitimately bracketed:
  // a checkbox and a badge are things the machine reports, not actions.
  '[': {
    'design_system/primitives/glyph_form.dart',
    'design_system/primitives/status_marker.dart',
    'presentation/core/widgets/status_marker_view.dart',
    'presentation/core/widgets/terminal_checkbox.dart',
    // spec section 8 mandates a literal [!] eyebrow and [requestId]
    'presentation/chat/widgets/inline_approval.dart',
    'presentation/chat/elicitation_card.dart', // same: bracketed request id
    // The `[!]` attention badge on a row or a footer button. A badge is a
    // state the machine reports, so the bracket form is correct.
    'presentation/core/widgets/detail_row.dart',
    'presentation/core/widgets/bios_action_strip.dart',
    // Boot log lines are literal machine output -- `[sys]`, `[net]`, `[!]`
    // are the log's own prefixes, not interface chrome.
    'presentation/boot/boot_view.dart',
    // KNOWN GAP: `[ THOUGHTS ]` is a label wearing status brackets, and is
    // uppercase. Owned by the chat-screen task; listed rather than hidden.
    'presentation/chat/thinking_block.dart',
  },
  // `●` section bullet, carrying aggregate state.
  '●': {
    'design_system/primitives/glyph_form.dart',
    'presentation/core/widgets/section_header.dart',
  },
  // `▸ ▾ ▴` row affordances. Declared once, never typed.
  '▸': {'design_system/primitives/row_affordance.dart'},
  '▾': {'design_system/primitives/row_affordance.dart'},
  '▴': {'design_system/primitives/row_affordance.dart'},
};

/// Files whose whole job is to talk about glyphs.
bool _isMeta(String path) =>
    path.endsWith('design_system/primitives/glyph_form.dart');

/// A single- or double-quoted Dart string literal. Two adjacent raw strings,
/// each delimited by the quote character the other one contains.
final _stringLiteral = RegExp(r"'[^']*'" r'|"[^"]*"');

void main() {
  test('every glyph is used only by the widget that owns it', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('.g.dart') ||
          entity.path.endsWith('.freezed.dart') ||
          // Generated localizations quote every ARB value in a doc comment.
          entity.path.contains('/l10n/')) {
        continue;
      }
      final rel = entity.path.replaceFirst(RegExp(r'^lib/'), '');
      if (_isMeta(rel)) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final code = line.trimLeft();
        if (code.startsWith('//')) continue; // a comment is not a render
        // Only string literals count. A `[` in a list literal or a generic
        // is not a glyph.
        final literals = _stringLiteral
            .allMatches(line)
            .map((m) => m.group(0) ?? '');
        for (final literal in literals) {
          for (final entry in _owners.entries) {
            if (!literal.contains(entry.key)) continue;
            if (entry.value.any(rel.endsWith)) continue;
            offenders.add('$rel:${i + 1}  ${entry.key}  ${line.trim()}');
          }
        }
      }
    }

    expect(offenders, isEmpty, reason: '''
A glyph appeared outside the widget that owns it.

The vocabulary only reads if each form means one thing:
  [ ]    status the machine reports        StatusMarkerView / TerminalCheckbox
  < >    a discrete button                 TerminalButton
  >      a prompt, the user's own voice    TerminalPromptSuggestion
  *      a list item                       ServiceLine
  ●      a section header                  SectionHeader
  ▸ ▾ ▴  row affordances                   RowAffordance

Use the owning widget, or RowAffordance.<member>.glyph, instead of typing
the character. If a new file has a genuine claim on one, add it to _owners
with a reason rather than deleting the assertion.

${offenders.join('\n')}
''');
  });
}
