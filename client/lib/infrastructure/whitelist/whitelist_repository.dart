import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../domain/whitelist/i_whitelist_repository.dart';
import '../../domain/whitelist/whitelist_action.dart';
import '../../domain/whitelist/whitelist_target.dart';
import '../../domain/exceptions.dart';
import '../core/collections.dart';
import '../../core/try_operation.dart';

@LazySingleton(as: IWhitelistRepository)
class WhitelistRepository implements IWhitelistRepository {
  final PocketBase _pb;

  WhitelistRepository(this._pb);

  @override
  Future<List<WhitelistTarget>> getTargets() async {
    return tryMethod(
      () async {
        final records = await _pb.collection(Collections.whitelistTargets).getFullList(
              sort: '-created',
            );
        return records.map((r) {
          return WhitelistTarget.fromJson({
            ...r.toJson(),
            'id': r.id,
            'created': r.get<String>('created'),
            'updated': r.get<String>('updated'),
          });
        }).toList();
      },
      WhitelistException.new,
      'getTargets',
    );
  }

  @override
  Future<List<WhitelistAction>> getActions() async {
    return tryMethod(
      () async {
        final records = await _pb.collection(Collections.whitelistActions).getFullList(
              sort: '-created',
              expand: 'target',
            );
        return records.map((r) {
          return WhitelistAction.fromJson({
            ...r.toJson(),
            'id': r.id,
            'created': r.get<String>('created'),
            'updated': r.get<String>('updated'),
            'expand': r.expand,
          });
        }).toList();
      },
      WhitelistException.new,
      'getActions',
    );
  }

  @override
  Future<WhitelistTarget> createTarget(
      String name, String pattern, String type) async {
    return tryMethod(
      () async {
        final record = await _pb.collection(Collections.whitelistTargets).create(body: {
          'name': name,
          'pattern': pattern,
          'type': type,
        });
        return WhitelistTarget.fromJson({
          ...record.toJson(),
          'id': record.id,
          'created': record.get<String>('created'),
          'updated': record.get<String>('updated'),
        });
      },
      WhitelistException.new,
      'createTarget',
    );
  }

  @override
  Future<void> deleteTarget(String id) async {
    return tryMethod(
      () async => _pb.collection(Collections.whitelistTargets).delete(id),
      WhitelistException.new,
      'deleteTarget',
    );
  }

  @override
  Future<WhitelistAction> createAction(String command, String targetId) async {
    return tryMethod(
      () async {
        final record = await _pb.collection(Collections.whitelistActions).create(body: {
          'command': command,
          'target': targetId,
          'is_active': true,
        });
        return WhitelistAction.fromJson({
          ...record.toJson(),
          'id': record.id,
          'created': record.get<String>('created'),
          'updated': record.get<String>('updated'),
        });
      },
      WhitelistException.new,
      'createAction',
    );
  }

  @override
  Future<void> deleteAction(String id) async {
    return tryMethod(
      () async => _pb.collection(Collections.whitelistActions).delete(id),
      WhitelistException.new,
      'deleteAction',
    );
  }

  @override
  Future<void> toggleAction(String id, bool isActive) async {
    return tryMethod(
      () async {
        await _pb.collection(Collections.whitelistActions).update(id, body: {
          'is_active': isActive,
        });
      },
      WhitelistException.new,
      'toggleAction',
    );
  }
}
