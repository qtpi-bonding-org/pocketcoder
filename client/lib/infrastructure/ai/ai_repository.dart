import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../domain/ai/ai_models.dart';
import '../../domain/exceptions.dart';
import '../core/collections.dart';
import '../../core/try_operation.dart';

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
    return tryMethod(
      () async {
        final records = await _pb.collection(Collections.aiAgents).getFullList(
              expand: 'prompt,model',
            );
        return records.map((e) {
          return AiAgent.fromJson({
            ...e.data,
            'id': e.id,
            'prompt': e.get<RecordModel>('expand.prompt').data,
            'model': e.get<RecordModel>('expand.model').data,
          });
        }).toList();
      },
      AiException.new,
      'getAgents',
    );
  }

  @override
  Future<List<AiPrompt>> getPrompts() async {
    return tryMethod(
      () async {
        final records = await _pb.collection(Collections.aiPrompts).getFullList();
        return records
            .map((e) => AiPrompt.fromJson({...e.data, 'id': e.id}))
            .toList();
      },
      AiException.new,
      'getPrompts',
    );
  }

  @override
  Future<List<AiModel>> getModels() async {
    return tryMethod(
      () async {
        final records = await _pb.collection(Collections.aiModels).getFullList();
        return records
            .map((e) => AiModel.fromJson({...e.data, 'id': e.id}))
            .toList();
      },
      AiException.new,
      'getModels',
    );
  }

  @override
  Future<List<AiPermissionRule>> getRules(String agentId) async {
    return tryMethod(
      () async {
        final records = await _pb.collection(Collections.aiPermissionRules).getFullList(
              filter: 'agent = "$agentId"',
            );
        return records
            .map((e) => AiPermissionRule.fromJson({...e.data, 'id': e.id}))
            .toList();
      },
      AiException.new,
      'getRules',
    );
  }

  @override
  Future<void> saveAgent(AiAgent agent) async {
    return tryMethod(
      () async {
        final data = agent.toJson()..remove('id');
        if (agent.id.isEmpty) {
          await _pb.collection(Collections.aiAgents).create(body: data);
        } else {
          await _pb.collection(Collections.aiAgents).update(agent.id, body: data);
        }
      },
      AiException.new,
      'saveAgent',
    );
  }

  @override
  Future<void> savePrompt(AiPrompt prompt) async {
    return tryMethod(
      () async {
        final data = prompt.toJson()..remove('id');
        if (prompt.id.isEmpty) {
          await _pb.collection(Collections.aiPrompts).create(body: data);
        } else {
          await _pb.collection(Collections.aiPrompts).update(prompt.id, body: data);
        }
      },
      AiException.new,
      'savePrompt',
    );
  }

  @override
  Future<void> saveModel(AiModel model) async {
    return tryMethod(
      () async {
        final data = model.toJson()..remove('id');
        if (model.id.isEmpty) {
          await _pb.collection(Collections.aiModels).create(body: data);
        } else {
          await _pb.collection(Collections.aiModels).update(model.id, body: data);
        }
      },
      AiException.new,
      'saveModel',
    );
  }

  @override
  Future<void> saveRule(AiPermissionRule rule) async {
    return tryMethod(
      () async {
        final data = rule.toJson()..remove('id');
        if (rule.id.isEmpty) {
          await _pb.collection(Collections.aiPermissionRules).create(body: data);
        } else {
          await _pb.collection(Collections.aiPermissionRules).update(rule.id, body: data);
        }
      },
      AiException.new,
      'saveRule',
    );
  }

  @override
  Future<void> deleteAgent(String id) async {
    return tryMethod(
      () async => _pb.collection(Collections.aiAgents).delete(id),
      AiException.new,
      'deleteAgent',
    );
  }

  @override
  Future<void> deletePrompt(String id) async {
    return tryMethod(
      () async => _pb.collection(Collections.aiPrompts).delete(id),
      AiException.new,
      'deletePrompt',
    );
  }

  @override
  Future<void> deleteModel(String id) async {
    return tryMethod(
      () async => _pb.collection(Collections.aiModels).delete(id),
      AiException.new,
      'deleteModel',
    );
  }

  @override
  Future<void> deleteRule(String id) async {
    return tryMethod(
      () async => _pb.collection(Collections.aiPermissionRules).delete(id),
      AiException.new,
      'deleteRule',
    );
  }
}
