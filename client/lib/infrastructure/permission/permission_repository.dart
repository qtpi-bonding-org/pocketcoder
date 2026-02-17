import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../domain/permission/i_permission_repository.dart';
import '../../domain/permission/permission_request.dart';
import '../core/collections.dart';

@LazySingleton(as: IPermissionRepository)
class PermissionRepository implements IPermissionRepository {
  final PocketBase _pb;

  PermissionRepository(this._pb);

  @override
  Stream<List<PermissionRequest>> watchPending(String chatId) async* {
    // 1. Initial filtered fetch
    // Note: We filter by 'chat = "..." && status = "draft"'
    // "chat" was added in 1700000010_add_chat_to_permissions.go
    final filter = 'chat = "$chatId" && status = "draft"';

    // Helper to fetch current state
    Future<List<PermissionRequest>> fetch() async {
      final records = await _pb.collection(Collections.permissions).getList(
            filter: filter,
            sort: 'created',
          );
      return records.items
          .map((r) => PermissionRequest.fromJson(r.toJson()))
          .toList();
    }

    // Emit initial
    yield await fetch();

    // 2. Subscribe to ALL changes in this collection
    // We filter by chat locally/re-fetch to avoid MISSING the transition from 'draft' -> 'authorized'
    final controller = StreamController<List<PermissionRequest>>();

    final unsubscribe =
        await _pb.collection(Collections.permissions).subscribe('*', (e) async {
      // If ANY record in the permissions collection changes, we re-fetch our filtered list.
      // This is slightly more heavy but ensures we NEVER miss a status transition.
      try {
        final currentPending = await fetch();
        if (!controller.isClosed) {
          controller.add(currentPending);
        }
      } catch (e) {
        debugPrint('PermissionRepo: Error re-fetching on update: $e');
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
    await _pb.collection(Collections.permissions).update(permissionId, body: {
      'status': 'authorized',
    });
  }

  @override
  Future<void> deny(String permissionId) async {
    await _pb.collection(Collections.permissions).update(permissionId, body: {
      'status': 'denied',
    });
  }
}
