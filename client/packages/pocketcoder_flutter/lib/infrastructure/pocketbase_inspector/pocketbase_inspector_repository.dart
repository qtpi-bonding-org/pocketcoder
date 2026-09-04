import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/pocketbase_inspector/i_pocketbase_inspector_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/core/api_endpoints.dart';
import 'package:pocketcoder_flutter/infrastructure/core/logger.dart';

@LazySingleton(as: IPocketbaseInspectorRepository)
class PocketbaseInspectorRepository implements IPocketbaseInspectorRepository {
  PocketbaseInspectorRepository(this._pb);

  final PocketBase _pb;

  @override
  Future<PocketbaseInspectorStats> fetchStats() async {
    final response = await _pb
        .send(StreamingEndpoints.pocketbase, method: 'GET')
        .catchError((Object e, StackTrace stackTrace) {
      logError(
          '🗄️ [PocketbaseInspector] fetchStats request failed', e, stackTrace);
      throw e;
    });

    if (response is List) {
      final Map<String, dynamic> merged = {};
      for (final item in response) {
        if (item is Map<String, dynamic>) merged.addAll(item);
      }
      return PocketbaseInspectorStats.fromJson(merged);
    }

    if (response is Map<String, dynamic>) {
      return PocketbaseInspectorStats.fromJson(response);
    }

    return const PocketbaseInspectorStats();
  }
}
