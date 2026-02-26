import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/models/ai_agent.dart';
import 'package:pocketcoder_flutter/domain/models/ai_prompt.dart';
import 'package:pocketcoder_flutter/domain/models/ai_model.dart';
import 'package:pocketcoder_flutter/domain/models/subagent.dart';
import 'package:pocketcoder_flutter/infrastructure/core/base_dao.dart';
import "package:flutter_aeroform/infrastructure/core/collections.dart";

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
