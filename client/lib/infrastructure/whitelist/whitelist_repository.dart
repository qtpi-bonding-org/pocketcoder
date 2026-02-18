import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:json_annotation/json_annotation.dart';
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
        final records =
            await _pb.collection(Collections.whitelistTargets).getFullList(
                  sort: '-created',
                );
        return records.map((r) {
          return WhitelistTarget.fromJson({
            ...r.toJson(),
            'id': r.id,
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
        final records =
            await _pb.collection(Collections.whitelistActions).getFullList(
                  sort: '-created',
                );
        return records.map((r) {
          return WhitelistAction.fromJson({
            ...r.toJson(),
            'id': r.id,
          });
        }).toList();
      },
      WhitelistException.new,
      'getActions',
    );
  }

  @override
  Future<WhitelistTarget> createTarget(String name, String pattern) async {
    return tryMethod(
      () async {
        final record =
            await _pb.collection(Collections.whitelistTargets).create(body: {
          'name': name,
          'pattern': pattern,
          'active': true,
        });
        return WhitelistTarget.fromJson({
          ...record.toJson(),
          'id': record.id,
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
  Future<WhitelistAction> createAction(
    String permission, {
    String kind = 'pattern',
    String? value,
  }) async {
    return tryMethod(
      () async {
        final record =
            await _pb.collection(Collections.whitelistActions).create(body: {
          'permission': permission,
          'kind': kind,
          'value': value,
          'active': true,
        });
        return WhitelistAction.fromJson({
          ...record.toJson(),
          'id': record.id,
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
  Future<void> toggleAction(String id, bool active) async {
    return tryMethod(
      () async {
        await _pb.collection(Collections.whitelistActions).update(id, body: {
          'active': active,
        });
      },
      WhitelistException.new,
      'toggleAction',
    );
  }
}
