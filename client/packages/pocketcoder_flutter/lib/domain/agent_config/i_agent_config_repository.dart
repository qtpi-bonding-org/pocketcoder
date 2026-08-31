import 'package:pocketcoder_flutter/domain/models/permission_mode.dart';
import 'package:pocketcoder_flutter/domain/models/poco_config.dart';
import 'package:pocketcoder_flutter/domain/models/prompt.dart';

abstract class IAgentConfigRepository {
  Stream<List<PocoConfig>> watchConfigs();
  Stream<List<Prompt>> watchPrompts();
  Stream<List<PermissionMode>> watchPermissionModes();
  Future<void> saveConfig(PocoConfig config);
  Future<void> deleteConfig(String id);
  Future<void> savePrompt(Prompt prompt);
  Future<void> deletePrompt(String id);
}
