import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/sandbox_agent/i_sandbox_agent_repository.dart';
import 'package:pocketcoder_flutter/domain/models/sandbox_agent.dart';
import 'package:flutter_aeroform/domain/exceptions.dart';
import 'package:flutter_aeroform/core/try_operation.dart';
import '../communication/communication_daos.dart';

@LazySingleton(as: ISandboxAgentRepository)
class SandboxAgentRepository implements ISandboxAgentRepository {
  final SandboxAgentDao _sandboxAgentDao;

  SandboxAgentRepository(this._sandboxAgentDao);

  @override
  Stream<List<SandboxAgent>> watchSandboxAgents(String chatId) {
    return _sandboxAgentDao.watch(filter: 'chat = "$chatId"');
  }

  @override
  Future<void> terminateSandboxAgent(String id) async {
    return tryMethod(
      () async {
        await _sandboxAgentDao.delete(id);
      },
      RepositoryException.new,
      'terminateSandboxAgent',
    );
  }
}
