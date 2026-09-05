import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/row_affordance.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_progress_bar.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_spinner.dart';

/// Stale if `support/noto_sans_mono_regular_cmap.json` is not regenerated
/// after the font asset changes.
void main() {
  late Set<int> coveredCodepoints;

  setUpAll(() {
    final file = File(
      'test/design_system/support/noto_sans_mono_regular_cmap.json',
    );
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final list = json['codepoints'] as List<dynamic>;
    coveredCodepoints = list.cast<int>().toSet();
  });

  void expectCovered(String glyph, String description) {
    for (final rune in glyph.runes) {
      expect(
        coveredCodepoints.contains(rune),
        isTrue,
        reason: '$description (U+${rune.toRadixString(16).toUpperCase()} '
            '"$glyph") is missing from Noto Sans Mono Regular\'s cmap -- it '
            'would silently fall back to a different font at runtime',
      );
    }
  }

  test('spinner frames are covered by the shipped font', () {
    for (final frame in TerminalSpinner.frames) {
      expectCovered(frame, 'spinner frame');
    }
  });

  test('row affordance glyphs are covered by the shipped font', () {
    for (final affordance in RowAffordance.values) {
      if (affordance.glyph.isEmpty) continue;
      expectCovered(affordance.glyph, 'RowAffordance.${affordance.name}');
    }
  });

  test('progress bar cells are covered by the shipped font', () {
    expectCovered(TerminalProgressBar.filledGlyph, 'progress bar filled cell');
    expectCovered(TerminalProgressBar.emptyGlyph, 'progress bar empty cell');
  });

  test('section state bullet is covered by the shipped font', () {
    expectCovered('●', 'section header bullet (●)');
  });

  test('box-drawing glyphs used for boxed art are covered by the shipped '
      'font', () {
    const boxDrawing = '┌┐└┘│─╔╗╚╝║═';
    expectCovered(boxDrawing, 'box-drawing set');
  });

  test('glyphs known to be missing from the shipped font never reappear as '
      'literals in lib/presentation', () {
    const banned = ['✓', '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];
    final dir = Directory('lib/presentation');
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final content = entity.readAsStringSync();
      for (final glyph in banned) {
        expect(
          content.contains(glyph),
          isFalse,
          reason: '${entity.path} contains banned glyph "$glyph" -- it is '
              'missing from Noto Sans Mono Regular\'s cmap and silently '
              'falls back to a different font',
        );
      }
    }
  });
}
