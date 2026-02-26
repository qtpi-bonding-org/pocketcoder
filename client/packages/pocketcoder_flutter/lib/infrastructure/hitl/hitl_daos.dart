import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/models/permission.dart';
import 'package:pocketcoder_flutter/domain/models/whitelist_action.dart';
import 'package:pocketcoder_flutter/domain/models/whitelist_target.dart';
import 'package:pocketcoder_flutter/infrastructure/core/base_dao.dart';
import "package:flutter_aeroform/infrastructure/core/collections.dart";

@lazySingleton
class PermissionDao extends BaseDao<Permission> {
  PermissionDao(PocketBase pb)
      : super(pb, Collections.permissions, Permission.fromJson);
}

@lazySingleton
class WhitelistTargetDao extends BaseDao<WhitelistTarget> {
  WhitelistTargetDao(PocketBase pb)
      : super(pb, Collections.whitelistTargets, WhitelistTarget.fromJson);
}

@lazySingleton
class WhitelistActionDao extends BaseDao<WhitelistAction> {
  WhitelistActionDao(PocketBase pb)
      : super(pb, Collections.whitelistActions, WhitelistAction.fromJson);
}
