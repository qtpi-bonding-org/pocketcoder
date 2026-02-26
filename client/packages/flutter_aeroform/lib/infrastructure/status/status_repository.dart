import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:flutter_aeroform/domain/status/i_status_repository.dart';
import 'package:flutter_aeroform/domain/models/healthcheck.dart';
import 'package:flutter_aeroform/infrastructure/core/collections.dart';
import 'package:flutter_aeroform/infrastructure/core/logger.dart';

@LazySingleton(as: IStatusRepository)
class StatusRepository implements IStatusRepository {
  final PocketBase _pb;

  StatusRepository(this._pb);

  @override
  Future<bool> checkPocketBaseHealth() async {
    try {
      final response = await _pb.health.check();
      return response.code == 200;
    } catch (e) {
      logError('StatusRepository: PocketBase health check failed', e);
      return false;
    }
  }

  @override
  Future<List<Healthcheck>> getHealthchecks() async {
    try {
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
