import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/presentation/chat/diff_stats.dart';

void main() {
  group('computeDiffStats', () {
    test('a single-line change counts one removed line and one added line', () {
      final stats = computeDiffStats('return a + b', 'return a - b');

      expect(stats.removed, 1);
      expect(stats.added, 1);
      expect(stats.lines, hasLength(2));
      expect(stats.lines[0].kind, DiffLineKind.removed);
      expect(stats.lines[0].text, 'return a + b');
      expect(stats.lines[1].kind, DiffLineKind.added);
      expect(stats.lines[1].text, 'return a - b');
    });

    test('identical old and new text yields zero added/removed, all context lines', () {
      final stats = computeDiffStats('line one\nline two', 'line one\nline two');

      expect(stats.added, 0);
      expect(stats.removed, 0);
      expect(stats.lines, hasLength(2));
      expect(stats.lines.every((l) => l.kind == DiffLineKind.context), isTrue);
    });

    test('empty oldText (new file) counts every line as added, zero removed', () {
      final stats = computeDiffStats('', 'line one\nline two\nline three');

      expect(stats.removed, 0);
      expect(stats.added, 3);
      expect(stats.lines.every((l) => l.kind == DiffLineKind.added), isTrue);
    });

    test('a multi-line edit preserves unchanged context lines around the change', () {
      final stats = computeDiffStats(
        'def add(a, b):\n    return a + b\n\ndef sub(a, b):',
        'def add(a, b):\n    result = a + b\n    return result\n\ndef sub(a, b):',
      );

      expect(stats.removed, 1);
      expect(stats.added, 2);
      expect(stats.lines.first.text, 'def add(a, b):');
      expect(stats.lines.first.kind, DiffLineKind.context);
      expect(stats.lines.last.text, 'def sub(a, b):');
      expect(stats.lines.last.kind, DiffLineKind.context);
    });
  });
}
