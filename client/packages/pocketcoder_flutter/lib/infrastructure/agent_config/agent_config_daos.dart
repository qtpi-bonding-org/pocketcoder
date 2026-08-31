import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/models/collections.dart';
import 'package:pocketcoder_flutter/domain/models/permission_mode.dart';
import 'package:pocketcoder_flutter/domain/models/poco_config.dart';
import 'package:pocketcoder_flutter/domain/models/prompt.dart';
import 'package:pocketcoder_flutter/infrastructure/core/base_dao.dart';

@lazySingleton
class PocoConfigDao extends BaseDao<PocoConfig> {
  PocoConfigDao(PocketBase pb)
      : super(pb, Collections.pocoConfigs, PocoConfig.fromJson);
}

@lazySingleton
class PromptDao extends BaseDao<Prompt> {
  PromptDao(PocketBase pb) : super(pb, Collections.prompts, Prompt.fromJson);
}

@lazySingleton
class PermissionModeDao extends BaseDao<PermissionMode> {
  PermissionModeDao(PocketBase pb)
      : super(pb, Collections.permissionModes, PermissionMode.fromJson);
}
