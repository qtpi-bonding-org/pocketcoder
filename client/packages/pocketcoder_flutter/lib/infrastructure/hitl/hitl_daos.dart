import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/models/permission.dart';
import 'package:pocketcoder_flutter/domain/models/question.dart';
import 'package:pocketcoder_flutter/domain/models/tool_permission.dart';
import 'package:pocketcoder_flutter/domain/models/whitelist_target.dart';
import 'package:pocketcoder_flutter/infrastructure/core/base_dao.dart';
import "package:pocketcoder_flutter/domain/models/collections.dart";

@lazySingleton
class PermissionDao extends BaseDao<Permission> {
  PermissionDao(PocketBase pb)
      : super(pb, Collections.permissions, Permission.fromJson);
}

@lazySingleton
class QuestionDao extends BaseDao<Question> {
  QuestionDao(PocketBase pb)
      : super(pb, Collections.questions, Question.fromJson);
}

@lazySingleton
class WhitelistTargetDao extends BaseDao<WhitelistTarget> {
  WhitelistTargetDao(PocketBase pb)
      : super(pb, Collections.whitelistTargets, WhitelistTarget.fromJson);
}

@lazySingleton
class ToolPermissionDao extends BaseDao<ToolPermission> {
  ToolPermissionDao(PocketBase pb)
      : super(pb, Collections.toolPermissions, ToolPermission.fromJson);
}
