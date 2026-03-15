import 'dart:async';
import 'package:injectable/injectable.dart';

import 'package:pocketcoder_flutter/domain/hitl/i_hitl_repository.dart';
import 'package:pocketcoder_flutter/domain/models/permission.dart';
import 'package:pocketcoder_flutter/domain/models/question.dart';
import 'package:pocketcoder_flutter/domain/models/tool_permission.dart';
import 'package:pocketcoder_flutter/domain/permission/permission_api_models.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/core/try_operation.dart';
import 'package:pocketcoder_flutter/infrastructure/core/api_client.dart';
import 'hitl_daos.dart';

@LazySingleton(as: IHitlRepository)
class HitlRepository implements IHitlRepository {
  final PermissionDao _permissionDao;
  final QuestionDao _questionDao;
  final ToolPermissionDao _toolPermDao;
  final PocketCoderApi _api;

  HitlRepository(
    this._permissionDao,
    this._questionDao,
    this._toolPermDao,
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
  Stream<List<Question>> watchQuestions(String chatId) {
    return _questionDao.watch(
      filter: 'chat = "$chatId" && status = "asked"',
      sort: 'created',
    );
  }

  @override
  Future<void> answerQuestion(String questionId, String reply) async {
    return tryMethod(
      () async {
        await _questionDao.save(questionId, {
          'reply': reply,
          'status': 'replied',
        });
      },
      PermissionException.new,
      'answerQuestion',
    );
  }

  @override
  Future<void> rejectQuestion(String questionId) async {
    return tryMethod(
      () async {
        await _questionDao.save(questionId, {
          'status': 'rejected',
        });
      },
      PermissionException.new,
      'rejectQuestion',
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
  Future<List<ToolPermission>> getToolPermissions() async {
    return _toolPermDao.getFullList(sort: '-created');
  }

  @override
  Future<ToolPermission> createToolPermission({
    String? agent,
    required String tool,
    required String pattern,
    required String action,
  }) async {
    return _toolPermDao.save(null, {
      if (agent != null) 'agent': agent,
      'tool': tool,
      'pattern': pattern,
      'action': action,
      'active': true,
    });
  }

  @override
  Future<void> deleteToolPermission(String id) async {
    return _toolPermDao.delete(id);
  }

  @override
  Future<void> toggleToolPermission(String id, bool active) async {
    return tryMethod(
      () async {
        await _toolPermDao.save(id, {'active': active});
      },
      ToolPermissionsException.new,
      'toggleToolPermission',
    );
  }
}
