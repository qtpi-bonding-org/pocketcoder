import 'dart:async';
import 'package:injectable/injectable.dart';

import 'package:pocketcoder_flutter/domain/hitl/i_hitl_repository.dart';
import 'package:pocketcoder_flutter/domain/models/permission.dart';
import 'package:pocketcoder_flutter/domain/models/whitelist_action.dart';
import 'package:pocketcoder_flutter/domain/models/whitelist_target.dart';
import 'package:pocketcoder_flutter/domain/permission/permission_api_models.dart';
import 'package:flutter_aeroform/domain/exceptions.dart';
import 'package:flutter_aeroform/core/try_operation.dart';
import 'package:pocketcoder_flutter/infrastructure/core/api_client.dart';
import 'hitl_daos.dart';

@LazySingleton(as: IHitlRepository)
class HitlRepository implements IHitlRepository {
  final PermissionDao _permissionDao;
  final WhitelistTargetDao _targetDao;
  final WhitelistActionDao _actionDao;
  final PocketCoderApi _api;

  HitlRepository(
    this._permissionDao,
    this._targetDao,
    this._actionDao,
    this._api,
  );

  @override
  Stream<List<Permission>> watchPending(String chatId) {
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
      () => _api.evaluatePermission(
        permission: permission,
        patterns: patterns,
        chatId: chatId,
        sessionId: sessionId,
        opencodeId: agentPermissionId,
        metadata: metadata,
        message: message,
        messageId: messageId,
        callId: callId,
      ),
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
