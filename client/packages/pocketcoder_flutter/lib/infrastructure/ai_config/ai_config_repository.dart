import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/ai_config/i_ai_config_repository.dart';
import 'package:pocketcoder_flutter/domain/models/ai_agent.dart';
import 'package:pocketcoder_flutter/domain/models/ai_prompt.dart';
import 'package:pocketcoder_flutter/domain/models/ai_model.dart';
import 'package:pocketcoder_flutter/domain/models/sandbox_agent.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/core/try_operation.dart';
import 'ai_config_daos.dart';

@LazySingleton(as: IAiConfigRepository)
class AiConfigRepository implements IAiConfigRepository {
  final AiAgentDao _agentDao;
  final AiPromptDao _promptDao;
  final AiModelDao _modelDao;
  final SandboxAgentDao _sandboxAgentDao;

  AiConfigRepository(
    this._agentDao,
    this._promptDao,
    this._modelDao,
    this._sandboxAgentDao,
  );

  // --- Agents ---

  @override
  Future<List<AiAgent>> getAgents() async {
    return _agentDao.getFullList(expand: 'prompt,model', sort: 'name');
  }

  @override
  Stream<List<AiAgent>> watchAgents() {
    return _agentDao.watch(expand: 'prompt,model', sort: 'name');
  }

  @override
  Future<void> saveAgent(AiAgent agent) async {
    return tryMethod(
      () async {
        final data = agent.toJson()
          ..remove('id')
          ..remove('created')
          ..remove('updated');
        await _agentDao.save(agent.id.isEmpty ? null : agent.id, data);
      },
      AiException.new,
      'saveAgent',
    );
  }

  @override
  Future<void> deleteAgent(String id) async {
    return _agentDao.delete(id);
  }

  // --- Prompts ---

  @override
  Future<List<AiPrompt>> getPrompts() async {
    return _promptDao.getFullList(sort: 'name');
  }

  @override
  Stream<List<AiPrompt>> watchPrompts() {
    return _promptDao.watch(sort: 'name');
  }

  @override
  Future<void> savePrompt(AiPrompt prompt) async {
    return tryMethod(
      () async {
        final data = prompt.toJson()
          ..remove('id')
          ..remove('created')
          ..remove('updated');
        await _promptDao.save(prompt.id.isEmpty ? null : prompt.id, data);
      },
      AiException.new,
      'savePrompt',
    );
  }

  @override
  Future<void> deletePrompt(String id) async {
    return _promptDao.delete(id);
  }

  // --- Models ---

  @override
  Future<List<AiModel>> getModels() async {
    return _modelDao.getFullList(sort: 'name');
  }

  @override
  Stream<List<AiModel>> watchModels() {
    return _modelDao.watch(sort: 'name');
  }

  @override
  Future<void> saveModel(AiModel model) async {
    return tryMethod(
      () async {
        final data = model.toJson()
          ..remove('id')
          ..remove('created')
          ..remove('updated');
        await _modelDao.save(model.id.isEmpty ? null : model.id, data);
      },
      AiException.new,
      'saveModel',
    );
  }

  @override
  Future<void> deleteModel(String id) async {
    return _modelDao.delete(id);
  }

  // --- Sandbox Agents ---

  @override
  Future<List<SandboxAgent>> getSandboxAgents() async {
    return _sandboxAgentDao.getFullList(sort: '-created');
  }

  @override
  Stream<List<SandboxAgent>> watchSandboxAgents() {
    return _sandboxAgentDao.watch(sort: '-created');
  }

  @override
  Future<void> saveSandboxAgent(SandboxAgent sandboxAgent) async {
    return tryMethod(
      () async {
        final data = sandboxAgent.toJson()
          ..remove('id')
          ..remove('created')
          ..remove('updated');
        await _sandboxAgentDao.save(sandboxAgent.id.isEmpty ? null : sandboxAgent.id, data);
      },
      RepositoryException.new,
      'saveSandboxAgent',
    );
  }

  @override
  Future<void> deleteSandboxAgent(String id) async {
    return _sandboxAgentDao.delete(id);
  }
}
