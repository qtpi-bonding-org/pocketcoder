import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/memory/i_memory_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/core/api_endpoints.dart';
import 'package:pocketcoder_flutter/infrastructure/core/logger.dart';

@LazySingleton(as: IMemoryRepository)
class MemoryRepository implements IMemoryRepository {
  MemoryRepository(this._pb);

  final PocketBase _pb;

  @override
  Future<MemoryStats> fetchStats() async {
    final response = await _pb
        .send(StreamingEndpoints.memory, method: 'GET')
        .catchError((Object e, StackTrace stackTrace) {
      logError('🧠 [Memory] fetchStats request failed', e, stackTrace);
      throw e;
    });

    if (response is List) {
      final Map<String, dynamic> merged = {};
      for (final item in response) {
        if (item is Map<String, dynamic>) merged.addAll(item);
      }
      return MemoryStats.fromJson(merged);
    }

    if (response is Map<String, dynamic>) {
      return MemoryStats.fromJson(response);
    }

    return const MemoryStats();
  }
}
