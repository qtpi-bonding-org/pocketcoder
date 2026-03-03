import 'package:pocketcoder_flutter/domain/models/ai_agent.dart';
import 'package:pocketcoder_flutter/domain/models/ai_prompt.dart';
import 'package:pocketcoder_flutter/domain/models/ai_model.dart';
import 'package:pocketcoder_flutter/domain/models/sandbox_agent.dart';

abstract class IAiConfigRepository {
  // --- Agents ---
  Future<List<AiAgent>> getAgents();
  Stream<List<AiAgent>> watchAgents();
  Future<void> saveAgent(AiAgent agent);
  Future<void> deleteAgent(String id);

  // --- Prompts ---
  Future<List<AiPrompt>> getPrompts();
  Stream<List<AiPrompt>> watchPrompts();
  Future<void> savePrompt(AiPrompt prompt);
  Future<void> deletePrompt(String id);

  // --- Models ---
  Future<List<AiModel>> getModels();
  Stream<List<AiModel>> watchModels();
  Future<void> saveModel(AiModel model);
  Future<void> deleteModel(String id);

  // --- Sandbox Agents ---
  Future<List<SandboxAgent>> getSandboxAgents();
  Stream<List<SandboxAgent>> watchSandboxAgents();
  Future<void> saveSandboxAgent(SandboxAgent sandboxAgent);
  Future<void> deleteSandboxAgent(String id);
}
