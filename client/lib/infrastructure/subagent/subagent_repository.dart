import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../domain/subagent/i_subagent_repository.dart';
import '../../domain/subagent/subagent.dart';
import '../../domain/exceptions.dart';
import '../core/collections.dart';
import '../../core/try_operation.dart';

@LazySingleton(as: ISubagentRepository)
class SubagentRepository implements ISubagentRepository {
  final PocketBase _pb;

  SubagentRepository(this._pb);

  @override
  Future<List<Subagent>> getSubagents() async {
    return tryMethod(
      () async {
        final records = await _pb.collection(Collections.subagents).getList(
              sort: '-created',
            );

        return records.items
            .map((r) => Subagent.fromJson({
                  ...r.toJson(),
                  'id': r.id,
                }))
            .toList();
      },
      RepositoryException.new,
      'getSubagents',
    );
  }

  @override
  Future<Subagent?> getSubagent(String subagentId) async {
    return tryMethod(
      () async {
        final record = await _pb.collection(Collections.subagents).getOne(subagentId);

        return Subagent.fromJson({
          ...record.toJson(),
          'id': record.id,
        });
      },
      RepositoryException.new,
      'getSubagent',
    );
  }

  @override
  Stream<List<RecordModel>> watchSubagents() async* {
    final controller = StreamController<List<RecordModel>>();

    final unsubscribe = await _pb.collection(Collections.subagents).subscribe('*', (e) async {
      try {
        final records = await _pb.collection(Collections.subagents).getList();
        if (!controller.isClosed) {
          controller.add(records.items);
        }
      } catch (_) {
        // Log error but don't crash
      }
    });

    try {
      yield* controller.stream;
    } finally {
      unsubscribe();
      controller.close();
    }
  }
}