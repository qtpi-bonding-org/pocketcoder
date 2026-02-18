import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../domain/permission/i_permission_repository.dart';
import '../../domain/permission/permission_request.dart';
import '../../domain/exceptions.dart';
import '../core/collections.dart';
import '../core/logger.dart';
import '../../core/try_operation.dart';

@LazySingleton(as: IPermissionRepository)
class PermissionRepository implements IPermissionRepository {
  final PocketBase _pb;

  PermissionRepository(this._pb);

  @override
  Stream<List<PermissionRequest>> watchPending(String chatId) async* {
    // Helper to fetch current state
    Future<List<PermissionRequest>> fetch() async {
      return tryMethod(
        () async {
          final filter = 'chat = "$chatId" && status = "draft"';
          final records = await _pb.collection(Collections.permissions).getList(
                filter: filter,
                sort: 'created',
              );
          return records.items
              .map((r) => PermissionRequest.fromJson(r.toJson()))
              .toList();
        },
        PermissionException.new,
        'watchPending.fetch',
      );
    }

    // Emit initial
    yield await fetch();

    // Subscribe to changes
    final controller = StreamController<List<PermissionRequest>>();

    final unsubscribe = await _pb.collection(Collections.permissions).subscribe('*', (e) async {
      try {
        final currentPending = await fetch();
        if (!controller.isClosed) {
          controller.add(currentPending);
        }
      } catch (e, stack) {
        logError('Error re-fetching permissions on update', e, stack);
      }
    });

    try {
      yield* controller.stream;
    } finally {
      unsubscribe();
      controller.close();
    }
  }

  @override
  Future<void> authorize(String permissionId) async {
    return tryMethod(
      () async {
        await _pb.collection(Collections.permissions).update(permissionId, body: {
          'status': 'authorized',
        });
      },
      PermissionException.new,
      'authorize',
    );
  }

  @override
  Future<void> deny(String permissionId) async {
    return tryMethod(
      () async {
        await _pb.collection(Collections.permissions).update(permissionId, body: {
          'status': 'denied',
        });
      },
      PermissionException.new,
      'deny',
    );
  }

  /// Evaluate a permission request via the custom endpoint
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
        final response = await _pb.send('/api/pocketcoder/permission', method: 'POST', body: {
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

        return PermissionResponse.fromJson(response);
      },
      PermissionException.new,
      'evaluatePermission',
    );
  }
}

/// Response from the permission evaluation endpoint
class PermissionResponse {
  final bool permitted;
  final String id;
  final String status;

  PermissionResponse({
    required this.permitted,
    required this.id,
    required this.status,
  });

  factory PermissionResponse.fromJson(Map<String, dynamic> json) {
    return PermissionResponse(
      permitted: json['permitted'] as bool,
      id: json['id'] as String,
      status: json['status'] as String,
    );
  }
}
