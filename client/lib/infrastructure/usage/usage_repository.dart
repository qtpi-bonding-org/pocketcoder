import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../domain/usage/i_usage_repository.dart';
import '../../domain/usage/usage.dart';
import '../../domain/exceptions.dart';
import '../core/collections.dart';
import '../../core/try_operation.dart';

@LazySingleton(as: IUsageRepository)
class UsageRepository implements IUsageRepository {
  final PocketBase _pb;

  UsageRepository(this._pb);

  @override
  Future<List<Usage>> getUsages({
    String? messageId,
    int page = 1,
    int perPage = 30,
  }) async {
    return tryMethod(
      () async {
        String? filter;
        if (messageId != null) {
          filter = 'message_id = "$messageId"';
        }

        final records = await _pb.collection(Collections.usages).getList(
              page: page,
              perPage: perPage,
              filter: filter,
              sort: '-created',
            );

        return records.items
            .map((r) => Usage.fromJson({
                  ...r.toJson(),
                  'id': r.id,
                }))
            .toList();
      },
      RepositoryException.new,
      'getUsages',
    );
  }

  @override
  Future<UsageStats> getUsageStats() async {
    return tryMethod(
      () async {
        final records = await _pb.collection(Collections.usages).getList(
              perPage: 1,
            );

        int totalTokens = 0;
        double totalCost = 0.0;

        for (final record in records.items) {
          totalTokens += record.getIntValue('tokens_prompt') +
              record.getIntValue('tokens_completion') +
              record.getIntValue('tokens_reasoning');
          totalCost += record.getDoubleValue('cost');
        }

        return UsageStats(
          totalTokens: totalTokens,
          totalCost: totalCost,
          totalRequests: records.totalItems,
        );
      },
      RepositoryException.new,
      'getUsageStats',
    );
  }

  @override
  Future<Usage> trackUsage(Usage usage) async {
    return tryMethod(
      () async {
        final record = await _pb.collection(Collections.usages).create(
              body: usage.toJson(),
            );

        return Usage.fromJson({
          ...record.toJson(),
          'id': record.id,
        });
      },
      RepositoryException.new,
      'trackUsage',
    );
  }

  @override
  Stream<List<RecordModel>> watchUsages() async* {
    final controller = StreamController<List<RecordModel>>();

    final unsubscribe = await _pb.collection(Collections.usages).subscribe('*', (e) async {
      try {
        final records = await _pb.collection(Collections.usages).getList();
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