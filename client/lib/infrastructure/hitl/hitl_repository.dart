import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../domain/hitl/i_hitl_repository.dart';
import '../../domain/permission/permission_request.dart';
import '../../domain/whitelist/whitelist_action.dart';
import '../../domain/whitelist/whitelist_target.dart';
import '../../domain/permission/permission_api_models.dart';
import '../../domain/exceptions.dart';
import '../../core/try_operation.dart';
import 'hitl_daos.dart';

@LazySingleton(as: IHitlRepository)
class HitlRepository implements IHitlRepository {
  final PermissionDao _permissionDao;
  final WhitelistTargetDao _targetDao;
  final WhitelistActionDao _actionDao;
  final PocketBase _pb;

  HitlRepository(
    this._permissionDao,
    this._targetDao,
    this._actionDao,
    this._pb,
  );

  @override
  Stream<List<PermissionRequest>> watchPending(String chatId) {
    return _permissionDao.watch(
      filter: 'chat = "$chatId" && status = "draft"',
      sort: 'created',
    );
  }

  @override
  Future<void> authorize(String permissionId) async {
    return tryMethod(
      () async {
        await _permissionDao.save(permissionId, {'status': 'authorized'});
      },
      PermissionException.new,
      'authorize',
    );
  }

  @override
  Future<void> deny(String permissionId) async {
    return tryMethod(
      () async {
        await _permissionDao.save(permissionId, {'status': 'denied'});
      },
      PermissionException.new,
      'deny',
    );
  }

  @override
  Future<PermissionResponse> evaluatePermission({
    required String permission,
    required List<String> patterns,
    required String chatId,
    required String sessionId,
    required String agentPermissionId,
    Map<String, dynamic>? metadata,
    String? message,
    String? messageId,
    String? callId,
  }) async {
    return tryMethod(
      () async {
        final response = await _pb
            .send('/api/pocketcoder/permission', method: 'POST', body: {
          'permission': permission,
          'patterns': patterns,
          'chat_id': chatId,
          'session_id': sessionId,
          'opencode_id': agentPermissionId,
          if (metadata != null) 'metadata': metadata,
          if (message != null) 'message': message,
          if (messageId != null) 'message_id': messageId,
          if (callId != null) 'call_id': callId,
        });

        return PermissionResponse.fromJson(response as Map<String, dynamic>);
      },
      PermissionException.new,
      'evaluatePermission',
    );
  }

  @override
  Future<List<WhitelistTarget>> getTargets() async {
    return _targetDao.getFullList(sort: '-created');
  }

  @override
  Future<List<WhitelistAction>> getActions() async {
    return _actionDao.getFullList(sort: '-created');
  }

  @override
  Future<WhitelistTarget> createTarget(String name, String pattern) async {
    return _targetDao.save(null, {
      'name': name,
      'pattern': pattern,
      'active': true,
    });
  }

  @override
  Future<void> deleteTarget(String id) async {
    return _targetDao.delete(id);
  }

  @override
  Future<WhitelistAction> createAction(
    String permission, {
    String kind = 'pattern',
    String? value,
  }) async {
    return _actionDao.save(null, {
      'permission': permission,
      'kind': kind,
      'value': value,
      'active': true,
    });
  }

  @override
  Future<void> deleteAction(String id) async {
    return _actionDao.delete(id);
  }

  @override
  Future<void> toggleAction(String id, bool active) async {
    return tryMethod(
      () async {
        await _actionDao.save(id, {'active': active});
      },
      WhitelistException.new,
      'toggleAction',
    );
  }
}
