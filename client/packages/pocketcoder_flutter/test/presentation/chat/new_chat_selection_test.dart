import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/presentation/chat/new_chat_selection.dart';

void main() {
  group('supportsOllamaHarness', () {
    test('only exposes virtual local models for Goose and OpenCode', () {
      expect(supportsOllamaHarness('goose'), isTrue);
      expect(supportsOllamaHarness('opencode'), isTrue);
      expect(supportsOllamaHarness('codex'), isFalse);
      expect(supportsOllamaHarness('claude-code'), isFalse);
    });
  });

  group('validateWorkspacePath', () {
    test('accepts /workspace as a valid root path', () {
      final error = validateWorkspacePath('/workspace');
      expect(error, isNull);
    });

    test('accepts /workspace/ as a valid root path', () {
      final error = validateWorkspacePath('/workspace/');
      expect(error, isNull);
    });

    test('accepts /workspace/subdir as a valid subdirectory', () {
      final error = validateWorkspacePath('/workspace/subdir');
      expect(error, isNull);
    });

    test('accepts /workspace/a/b/c as nested subdirectories', () {
      final error = validateWorkspacePath('/workspace/a/b/c');
      expect(error, isNull);
    });

    test('rejects paths outside /workspace', () {
      final error = validateWorkspacePath('/etc/passwd');
      expect(error, isNotNull);
    });

    test('rejects paths that escape via .. traversal', () {
      final error = validateWorkspacePath('/workspace/../etc');
      expect(error, isNotNull);
    });

    test('rejects /workspace/.. which escapes the workspace root', () {
      final error = validateWorkspacePath('/workspace/..');
      expect(error, isNotNull);
    });

    test('rejects /workspace/subdir/../.. which escapes via multiple segments',
        () {
      final error = validateWorkspacePath('/workspace/subdir/../..');
      expect(error, isNotNull);
    });

    test('rejects empty path', () {
      final error = validateWorkspacePath('');
      expect(error, isNotNull);
    });

    test('rejects relative paths', () {
      final error = validateWorkspacePath('workspace/subdir');
      expect(error, isNotNull);
    });

    test('normalizes trailing slashes correctly', () {
      final error1 = validateWorkspacePath('/workspace/subdir/');
      expect(error1, isNull);
    });

    test('handles workspace paths with dot segments correctly', () {
      final error = validateWorkspacePath('/workspace/./subdir');
      expect(error, isNull);
    });

    test(
        'rejects a path that is only a prefix-string match, not a real segment prefix',
        () {
      // "/workspace-evil" starts with the string "/workspace" but is not
      // "/workspace" or a "/workspace/..." segment — must be rejected.
      expect(validateWorkspacePath('/workspace-evil'), isNotNull);
    });

    test('accepts a custom root when given', () {
      expect(validateWorkspacePath('/custom/sub', root: '/custom'), isNull);
    });
  });
}
