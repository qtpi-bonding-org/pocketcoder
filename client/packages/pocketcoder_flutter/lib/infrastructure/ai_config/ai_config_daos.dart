import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../domain/ai/ai_models.dart';
import '../../domain/subagent/subagent.dart';
import '../core/base_dao.dart';
import '../core/collections.dart';

@lazySingleton
class AiAgentDao extends BaseDao<AiAgent> {
  AiAgentDao(PocketBase pb) : super(pb, Collections.aiAgents, AiAgent.fromJson);
}

@lazySingleton
class AiPromptDao extends BaseDao<AiPrompt> {
  AiPromptDao(PocketBase pb)
      : super(pb, Collections.aiPrompts, AiPrompt.fromJson);
}

@lazySingleton
class AiModelDao extends BaseDao<AiModel> {
  AiModelDao(PocketBase pb) : super(pb, Collections.aiModels, AiModel.fromJson);
}

@lazySingleton
class SubagentDao extends BaseDao<Subagent> {
  SubagentDao(PocketBase pb)
      : super(pb, Collections.subagents, Subagent.fromJson);
}
