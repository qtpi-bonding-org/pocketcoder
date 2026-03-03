import 'package:pocketcoder_flutter/domain/models/sandbox_agent.dart';

abstract class ISandboxAgentRepository {
  Stream<List<SandboxAgent>> watchSandboxAgents(String chatId);
  Future<void> terminateSandboxAgent(String id);
}
