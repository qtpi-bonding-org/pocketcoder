import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/tool_permissions/i_tool_permission_repository.dart';
import 'package:pocketcoder_flutter/domain/models/tool_permission.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/core/try_operation.dart';
import 'tool_permission_daos.dart';

@LazySingleton(as: IToolPermissionRepository)
class ToolPermissionRepository implements IToolPermissionRepository {
  final ToolPermissionDao _toolPermissionDao;

  ToolPermissionRepository(this._toolPermissionDao);

  @override
  Stream<List<ToolPermission>> watchRules() {
    return _toolPermissionDao.watch(filter: 'poco_config = ""', sort: 'tool');
  }

  @override
  Future<void> createRule(
      {required String tool, required String action}) async {
    return tryMethod(
      () async {
        await _toolPermissionDao.save(null, {
          'tool': tool,
          'pattern': '*',
          'action': action,
          'active': true,
        });
      },
      ToolPermissionsException.new,
      'createRule',
    );
  }

  @override
  Future<void> updateAction(String id, String action) async {
    return tryMethod(
      () async {
        await _toolPermissionDao.save(id, {'action': action});
      },
      ToolPermissionsException.new,
      'updateAction',
    );
  }

  @override
  Future<void> setActive(String id, bool active) async {
    return tryMethod(
      () async {
        await _toolPermissionDao.save(id, {'active': active});
      },
      ToolPermissionsException.new,
      'setActive',
    );
  }
}
