import 'package:pocketcoder_flutter/domain/models/llm_key.dart';
import 'package:pocketcoder_flutter/domain/models/model_selection.dart';
import 'package:pocketcoder_flutter/domain/models/llm_provider.dart';

abstract class ILlmRepository {
  // --- Keys ---
  Stream<List<LlmKey>> watchKeys();
  Future<void> saveKey(String providerId, Map<String, dynamic> envVars);
  Future<void> deleteKey(String id);

  // --- Providers (read-only catalog) ---
  Stream<List<LlmProvider>> watchProviders();

  // --- Model Selection ---
  Stream<List<ModelSelection>> watchConfig();
  Future<void> setModel(String model, {String? chat});
}
