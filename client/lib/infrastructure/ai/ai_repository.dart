import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../domain/ai/ai_models.dart';
import '../core/collections.dart';

abstract class IAiRepository {
  Future<List<AiAgent>> getAgents();
  Future<List<AiPrompt>> getPrompts();
  Future<List<AiModel>> getModels();
  Future<List<AiPermissionRule>> getRules(String agentId);

  Future<void> saveAgent(AiAgent agent);
  Future<void> savePrompt(AiPrompt prompt);
  Future<void> saveModel(AiModel model);
  Future<void> saveRule(AiPermissionRule rule);

  Future<void> deleteAgent(String id);
  Future<void> deletePrompt(String id);
  Future<void> deleteModel(String id);
  Future<void> deleteRule(String id);
}

@LazySingleton(as: IAiRepository)
class AiRepository implements IAiRepository {
  final PocketBase _pb;

  AiRepository(this._pb);

  @override
  Future<List<AiAgent>> getAgents() async {
    final records = await _pb.collection(Collections.aiAgents).getFullList(
          expand: 'prompt,model',
        );
    return records
        .map((e) => AiAgent.fromJson({
              ...e.data,
              'id': e.id,
              'expand': e.expand,
            }))
        .toList();
  }

  @override
  Future<List<AiPrompt>> getPrompts() async {
    final records = await _pb.collection(Collections.aiPrompts).getFullList();
    return records
        .map((e) => AiPrompt.fromJson({...e.data, 'id': e.id}))
        .toList();
  }

  @override
  Future<List<AiModel>> getModels() async {
    final records = await _pb.collection(Collections.aiModels).getFullList();
    return records
        .map((e) => AiModel.fromJson({...e.data, 'id': e.id}))
        .toList();
  }

  @override
  Future<List<AiPermissionRule>> getRules(String agentId) async {
    final records = await _pb.collection(Collections.aiPermissionRules).getFullList(
          filter: 'agent = "$agentId"',
        );
    return records
        .map((e) => AiPermissionRule.fromJson({...e.data, 'id': e.id}))
        .toList();
  }

  @override
  Future<void> saveAgent(AiAgent agent) async {
    final data = agent.toJson()..remove('id');
    if (agent.id.isEmpty) {
      await _pb.collection(Collections.aiAgents).create(body: data);
    } else {
      await _pb.collection(Collections.aiAgents).update(agent.id, body: data);
    }
  }

  @override
  Future<void> savePrompt(AiPrompt prompt) async {
    final data = prompt.toJson()..remove('id');
    if (prompt.id.isEmpty) {
      await _pb.collection(Collections.aiPrompts).create(body: data);
    } else {
      await _pb.collection(Collections.aiPrompts).update(prompt.id, body: data);
    }
  }

  @override
  Future<void> saveModel(AiModel model) async {
    final data = model.toJson()..remove('id');
    if (model.id.isEmpty) {
      await _pb.collection(Collections.aiModels).create(body: data);
    } else {
      await _pb.collection(Collections.aiModels).update(model.id, body: data);
    }
  }

  @override
  Future<void> saveRule(AiPermissionRule rule) async {
    final data = rule.toJson()..remove('id');
    if (rule.id.isEmpty) {
      await _pb.collection(Collections.aiPermissionRules).create(body: data);
    } else {
      await _pb.collection(Collections.aiPermissionRules).update(rule.id, body: data);
    }
  }

  @override
  Future<void> deleteAgent(String id) => _pb.collection(Collections.aiAgents).delete(id);

  @override
  Future<void> deletePrompt(String id) =>
      _pb.collection(Collections.aiPrompts).delete(id);

  @override
  Future<void> deleteModel(String id) => _pb.collection(Collections.aiModels).delete(id);

  @override
  Future<void> deleteRule(String id) =>
      _pb.collection(Collections.aiPermissionRules).delete(id);
}
