import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/models/sandbox_agent.dart';
import 'package:pocketcoder_flutter/infrastructure/core/base_dao.dart';
import "package:pocketcoder_flutter/domain/models/collections.dart";

@lazySingleton
class SandboxAgentDao extends BaseDao<SandboxAgent> {
  SandboxAgentDao(PocketBase pb)
      : super(pb, Collections.sandboxAgents, SandboxAgent.fromJson);
}
