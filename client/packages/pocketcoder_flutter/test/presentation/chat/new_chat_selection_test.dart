import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/domain/models/model.dart';
import 'package:pocketcoder_flutter/domain/models/harness_provider.dart';
import 'package:pocketcoder_flutter/domain/models/provider_api_key.dart';
import 'package:pocketcoder_flutter/presentation/chat/new_chat_selection.dart';

void main() {
  const modelA = Model(id: 'model-a', name: 'a', provider: 'p-anthropic');
  const modelB = Model(id: 'model-b', name: 'b', provider: 'p-openai');
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
        harnessProviders: const [
          HarnessProvider(id: 'hp-a', harness: 'h1', provider: 'p-anthropic'),
          HarnessProvider(id: 'hp-b', harness: 'h1', provider: 'p-openai'),
        ],
        providerAPIKeys: [
          const ProviderApiKey(
              id: 'k1', owner: 'u', provider: 'p-anthropic', apiKey: 'a'),
          const ProviderApiKey(
              id: 'k2', owner: 'u', provider: 'p-openai', apiKey: 'b'),
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
        harnessProviders: const [
          HarnessProvider(id: 'hp-a', harness: 'h1', provider: 'p-anthropic'),
          HarnessProvider(id: 'hp-b', harness: 'h1', provider: 'p-openai'),
        ],
        providerAPIKeys: [
          const ProviderApiKey(
              id: 'k1', owner: 'u', provider: 'p-anthropic', apiKey: 'a'),
        ],
      );
      expect(result.map((h) => h.id), ['hm-a']);
    });

    test(
        'excludes a harness_models row whose model id has no matching Model record',
        () {
      final result = selectableModels(
        harnessId: 'h1',
        harnessModels: [hmA],
        models: const [], // modelA missing entirely
        harnessProviders: const [
          HarnessProvider(id: 'hp-a', harness: 'h1', provider: 'p-anthropic'),
          HarnessProvider(id: 'hp-b', harness: 'h1', provider: 'p-openai'),
        ],
        providerAPIKeys: [
          const ProviderApiKey(
              id: 'k1', owner: 'u', provider: 'p-anthropic', apiKey: 'a'),
        ],
      );
      expect(result, isEmpty);
    });

    test('returns an empty list when no provider_keys exist at all', () {
      final result = selectableModels(
        harnessId: 'h1',
        harnessModels: [hmA, hmB],
        models: [modelA, modelB],
        harnessProviders: const [],
        providerAPIKeys: const [],
      );
      expect(result, isEmpty);
    });
    test('Codex openai key selects model through harness provider edge', () {
      final result = selectableModels(
        harnessId: 'codex',
        harnessModels: const [
          HarnessModel(
              id: 'hm', harness: 'codex', model: 'm', harnessModelId: 'gpt-4')
        ],
        models: const [
          Model(id: 'm', name: 'GPT-4', provider: 'openai-record')
        ],
        harnessProviders: const [
          HarnessProvider(
              id: 'edge', harness: 'codex', provider: 'openai-record')
        ],
        providerAPIKeys: const [
          ProviderApiKey(
              id: 'key',
              owner: 'u',
              provider: 'openai-record',
              apiKey: 'secret')
        ],
      );
      expect(result.map((model) => model.id), ['hm']);
    });
  });

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
