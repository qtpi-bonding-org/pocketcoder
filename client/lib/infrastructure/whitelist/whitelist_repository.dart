import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../domain/whitelist/i_whitelist_repository.dart';
import '../../domain/whitelist/whitelist_action.dart';
import '../../domain/whitelist/whitelist_target.dart';
import '../core/collections.dart';

@LazySingleton(as: IWhitelistRepository)
class WhitelistRepository implements IWhitelistRepository {
  final PocketBase _pb;

  WhitelistRepository(this._pb);

  @override
  Future<List<WhitelistTarget>> getTargets() async {
    final records = await _pb.collection(Collections.whitelistTargets).getFullList(
          sort: '-created',
        );
    return records
        .map((r) => WhitelistTarget.fromJson({
              ...r.toJson(),
              'id': r.id,
              'created': r.created,
              'updated': r.updated,
            }))
        .toList();
  }

  @override
  Future<List<WhitelistAction>> getActions() async {
    final records = await _pb.collection(Collections.whitelistActions).getFullList(
          sort: '-created',
          expand: 'target',
        );
    return records
        .map((r) => WhitelistAction.fromJson({
              ...r.toJson(),
              'id': r.id,
              'created': r.created,
              'updated': r.updated,
              'expand': r.expand,
            }))
        .toList();
  }

  @override
  Future<WhitelistTarget> createTarget(
      String name, String pattern, String type) async {
    final record = await _pb.collection(Collections.whitelistTargets).create(body: {
      'name': name,
      'pattern': pattern,
      'type': type,
    });
    return WhitelistTarget.fromJson({
      ...record.toJson(),
      'id': record.id,
      'created': record.created,
      'updated': record.updated,
    });
  }

  @override
  Future<void> deleteTarget(String id) async {
    await _pb.collection(Collections.whitelistTargets).delete(id);
  }

  @override
  Future<WhitelistAction> createAction(String command, String targetId) async {
    final record = await _pb.collection(Collections.whitelistActions).create(body: {
      'command': command,
      'target': targetId,
      'is_active': true,
    });
    // Fetch again to expand? Or just return basic.
    // Usually standard create doesn't expand unless requested, but let's keep it simple.
    // We might need to fetch it to get the expanded target if the UI relies on it immediately.
    // For now, let's just return what we have, UI might need to refresh or handle null target.
    return WhitelistAction.fromJson({
      ...record.toJson(),
      'id': record.id,
      'created': record.created,
      'updated': record.updated,
    });
  }

  @override
  Future<void> deleteAction(String id) async {
    await _pb.collection(Collections.whitelistActions).delete(id);
  }

  @override
  Future<void> toggleAction(String id, bool isActive) async {
    await _pb.collection(Collections.whitelistActions).update(id, body: {
      'is_active': isActive,
    });
  }
}
