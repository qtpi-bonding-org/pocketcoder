import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/domain/models/model.dart';
import 'package:pocketcoder_flutter/domain/models/provider_key.dart';
import 'package:pocketcoder_flutter/presentation/chat/new_chat_selection.dart';

void main() {
  const modelA = Model(id: 'model-a', name: 'a', provider: 'anthropic');
  const modelB = Model(id: 'model-b', name: 'b', provider: 'openai');
  const hmA = HarnessModel(
      id: 'hm-a', harness: 'h1', model: 'model-a', harnessModelId: 'claude-3');
  const hmB = HarnessModel(
      id: 'hm-b', harness: 'h1', model: 'model-b', harnessModelId: 'gpt-4');
  const hmOtherHarness = HarnessModel(
      id: 'hm-c', harness: 'h2', model: 'model-a', harnessModelId: 'claude-3');

  group('selectableModels', () {
    test('only returns harness_models rows for the selected harness', () {
      final result = selectableModels(
        harnessId: 'h1',
        harnessModels: [hmA, hmB, hmOtherHarness],
        models: [modelA, modelB],
        providerKeys: [
          const ProviderKey(id: 'k1', user: 'u', provider: 'anthropic'),
          const ProviderKey(id: 'k2', user: 'u', provider: 'openai'),
        ],
      );
      expect(result.map((h) => h.id), containsAll(['hm-a', 'hm-b']));
      expect(result.map((h) => h.id), isNot(contains('hm-c')));
    });

    test('excludes a model whose provider has no provider_keys row', () {
      final result = selectableModels(
        harnessId: 'h1',
        harnessModels: [hmA, hmB],
        models: [modelA, modelB],
        providerKeys: [
          const ProviderKey(id: 'k1', user: 'u', provider: 'anthropic'),
        ],
      );
      expect(result.map((h) => h.id), ['hm-a']);
    });

    test('excludes a harness_models row whose model id has no matching Model record', () {
      final result = selectableModels(
        harnessId: 'h1',
        harnessModels: [hmA],
        models: const [], // modelA missing entirely
        providerKeys: [
          const ProviderKey(id: 'k1', user: 'u', provider: 'anthropic'),
        ],
      );
      expect(result, isEmpty);
    });

    test('returns an empty list when no provider_keys exist at all', () {
      final result = selectableModels(
        harnessId: 'h1',
        harnessModels: [hmA, hmB],
        models: [modelA, modelB],
        providerKeys: const [],
      );
      expect(result, isEmpty);
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

    test('rejects /workspace/subdir/../.. which escapes via multiple segments', () {
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

    test('rejects a path that is only a prefix-string match, not a real segment prefix', () {
      // "/workspace-evil" starts with the string "/workspace" but is not
      // "/workspace" or a "/workspace/..." segment — must be rejected.
      expect(validateWorkspacePath('/workspace-evil'), isNotNull);
    });

    test('accepts a custom root when given', () {
      expect(validateWorkspacePath('/custom/sub', root: '/custom'), isNull);
    });
  });
}
