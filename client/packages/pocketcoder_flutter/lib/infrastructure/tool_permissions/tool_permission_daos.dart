import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/models/tool_permission.dart';
import 'package:pocketcoder_flutter/infrastructure/core/base_dao.dart';
import "package:pocketcoder_flutter/domain/models/collections.dart";

@lazySingleton
class ToolPermissionDao extends BaseDao<ToolPermission> {
  ToolPermissionDao(PocketBase pb)
      : super(pb, Collections.toolPermissions, ToolPermission.fromJson);
}
