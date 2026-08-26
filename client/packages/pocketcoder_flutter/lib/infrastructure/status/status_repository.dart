import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:pocketbase_drift/pocketbase_drift.dart';
import 'package:pocketcoder_flutter/domain/status/i_status_repository.dart';
import 'package:pocketcoder_flutter/domain/models/healthcheck.dart';
import 'package:pocketcoder_flutter/domain/models/collections.dart';
import 'package:pocketcoder_flutter/infrastructure/core/logger.dart';

@LazySingleton(as: IStatusRepository)
class StatusRepository implements IStatusRepository {
  final PocketBase _pb;

  StatusRepository(this._pb);

  @override
  Future<bool> checkPocketBaseHealth() async {
    try {
      final response = await _pb.health.check();
      final healthy = response.code == 200;
      if (healthy && _pb is $PocketBase) {
        // Self-heal a stale offline flag left by a spurious connectivity_plus
        // event at cold start (see AuthRepository._refireConnectivityCheck).
        await _pb.connectivity.checkConnectivity();
      }
      return healthy;
    } catch (e) {
      logError('StatusRepository: PocketBase health check failed', e);
      return false;
    }
  }

  @override
  Future<List<Healthcheck>> getHealthchecks() async {
    try {
      // Deliberate exception: health status is required before login.
      final records =
          await _pb.collection(Collections.healthchecks).getFullList(
                sort: 'name',
              );
      return records
          .map((r) => Healthcheck.fromJson({
                ...r.toJson(),
                'id': r.id,
              }))
          .toList();
    } catch (e) {
      logError('StatusRepository: Failed to get healthchecks', e);
      return [];
    }
  }

  @override
  Stream<List<Healthcheck>> watchHealthchecks() async* {
    final controller = StreamController<List<Healthcheck>>();

    // Initial fetch
    final initial = await getHealthchecks();
    controller.add(initial);

    // Deliberate exception: this is a pre-login deployment status stream.
    final unsubscribe = await _pb
        .collection(Collections.healthchecks)
        .subscribe('*', (e) async {
      final updated = await getHealthchecks();
      if (!controller.isClosed) {
        controller.add(updated);
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
