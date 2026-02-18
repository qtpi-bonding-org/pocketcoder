import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../domain/permission/permission_request.dart';
import '../../domain/whitelist/whitelist_action.dart';
import '../../domain/whitelist/whitelist_target.dart';
import '../core/base_dao.dart';
import '../core/collections.dart';

@lazySingleton
class PermissionDao extends BaseDao<PermissionRequest> {
  PermissionDao(PocketBase pb)
      : super(pb, Collections.permissions, PermissionRequest.fromJson);
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
