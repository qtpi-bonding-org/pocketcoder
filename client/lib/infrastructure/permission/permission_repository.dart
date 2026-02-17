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
}
