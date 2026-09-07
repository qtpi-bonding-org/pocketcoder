import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/domain/models/permission_mode.dart';
import 'package:pocketcoder_flutter/domain/models/tool_permission.dart';
import 'package:pocketcoder_flutter/domain/permission_modes/i_permission_mode_repository.dart';
import 'package:pocketcoder_flutter/core/try_operation.dart';
import 'package:pocketcoder_flutter/infrastructure/agent_config/agent_config_daos.dart';
import 'tool_permission_dao.dart';

@LazySingleton(as: IPermissionModeRepository)
class PermissionModeRepository implements IPermissionModeRepository {
  PermissionModeRepository(this._modeDao, this._ruleDao, this._auth);

  final PermissionModeDao _modeDao;
  final ToolPermissionDao _ruleDao;
  final IAuthRepository _auth;

  @override
  Stream<List<PermissionMode>> watchModes() =>
      _modeDao.watch(sort: 'name');

  @override
  Stream<List<ToolPermission>> watchRules(String modeId) =>
      _ruleDao.watch(filter: 'permission_mode = "$modeId"', sort: 'tool');

  @override
  Future<void> saveMode(PermissionMode mode) => tryMethod(
        () async {
          // Only the metadata fields this method is documented to touch --
          // spreading mode.toJson() wholesale would also send is_default,
          // which freezed serializes as an explicit null when unset, and
          // PocketBase coerces a null bool to false. Nothing in this
          // feature sets isDefault today, so it's not reachable yet, but
          // spreading toJson() would silently make it impossible to ever
          // persist a true isDefault through this method later.
          await _modeDao.save(mode.id, {
            'name': mode.name,
            'description': mode.description,
            'base_session_mode': 'approve',
            'user': _auth.currentUserId,
            'is_system': false,
          });
        },
        ToolPermissionsException.new,
        'saveMode',
      );

  @override
  Future<void> deleteMode(String id) => tryMethod(
        () => _modeDao.delete(id),
        ToolPermissionsException.new,
        'deleteMode',
      );

  @override
  Future<void> duplicateMode({
    required PermissionMode source,
    required String newName,
  }) =>
      tryMethod(
        () async {
          final created = await _modeDao.save(null, {
            'name': newName,
            'description': source.description,
            'base_session_mode': 'approve',
            'user': _auth.currentUserId,
            'is_system': false,
          });
          final rules = await _ruleDao.getFullList(
            filter: 'permission_mode = "${source.id}"',
          );
          for (final rule in rules) {
            await _ruleDao.save(null, {
              'tool': rule.tool,
              'pattern': rule.pattern,
              'action': _actionWireValue(rule.action),
              'active': rule.active,
              'permission_mode': created.id,
            });
          }
        },
        ToolPermissionsException.new,
        'duplicateMode',
      );

  @override
  Future<void> createRule({
    required String modeId,
    required String tool,
    required String action,
  }) =>
      tryMethod(
        () async {
          await _ruleDao.save(null, {
            'tool': tool,
            'pattern': '*',
            'action': action,
            'active': true,
            'permission_mode': modeId,
          });
        },
        ToolPermissionsException.new,
        'createRule',
      );

  @override
  Future<void> updateAction(String id, String action) => tryMethod(
        () => _ruleDao.save(id, {'action': action}),
        ToolPermissionsException.new,
        'updateAction',
      );

  @override
  Future<void> setActive(String id, bool active) => tryMethod(
        () => _ruleDao.save(id, {'active': active}),
        ToolPermissionsException.new,
        'setActive',
      );
}

/// ToolPermissionAction's members are literally named allow/ask/deny, so
/// `.name` round-trips correctly for those -- but the enum also has an
/// `unknown` member (`@JsonKey(unknownEnumValue: ...)`, used only for
/// *decoding* an unrecognized value) whose `.name` is `'unknown'`, which
/// permission_mode_tools.action (a 3-value select) would reject outright.
/// duplicateMode can only ever encounter allow/ask/deny in practice (those
/// are the only values ever written), but guard explicitly rather than
/// trust `.name` blindly on an enum that has a fourth member.
String _actionWireValue(ToolPermissionAction action) => switch (action) {
      ToolPermissionAction.allow => 'allow',
      ToolPermissionAction.ask => 'ask',
      ToolPermissionAction.deny => 'deny',
      ToolPermissionAction.unknown => throw StateError(
          'cannot duplicate a rule with an unrecognized action'),
    };
