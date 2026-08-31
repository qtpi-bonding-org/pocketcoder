import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/core/try_operation.dart';
import 'package:pocketcoder_flutter/domain/agent_config/i_agent_config_repository.dart';
import 'package:pocketcoder_flutter/domain/exceptions/agent_config_exception.dart';
import 'package:pocketcoder_flutter/domain/models/permission_mode.dart';
import 'package:pocketcoder_flutter/domain/models/poco_config.dart';
import 'package:pocketcoder_flutter/domain/models/prompt.dart';
import 'package:pocketcoder_flutter/infrastructure/agent_config/agent_config_daos.dart';

@LazySingleton(as: IAgentConfigRepository)
class AgentConfigRepository implements IAgentConfigRepository {
  AgentConfigRepository(
    this._configDao,
    this._promptDao,
    this._permissionModeDao,
  );

  final PocoConfigDao _configDao;
  final PromptDao _promptDao;
  final PermissionModeDao _permissionModeDao;

  @override
  Stream<List<PocoConfig>> watchConfigs() => _configDao.watch();

  @override
  Stream<List<Prompt>> watchPrompts() => _promptDao.watch();

  @override
  Stream<List<PermissionMode>> watchPermissionModes() =>
      _permissionModeDao.watch();

  @override
  Future<void> saveConfig(PocoConfig config) => tryMethod(
        () async {
          await _configDao.save(config.id, config.toJson());
        },
        AgentConfigException.new,
        'saveConfig',
      );

  @override
  Future<void> deleteConfig(String id) => tryMethod(
        () => _configDao.delete(id),
        AgentConfigException.new,
        'deleteConfig',
      );

  @override
  Future<void> savePrompt(Prompt prompt) => tryMethod(
        () async {
          await _promptDao.save(prompt.id, prompt.toJson());
        },
        AgentConfigException.new,
        'savePrompt',
      );

  @override
  Future<void> deletePrompt(String id) => tryMethod(
        () => _promptDao.delete(id),
        AgentConfigException.new,
        'deletePrompt',
      );
}
