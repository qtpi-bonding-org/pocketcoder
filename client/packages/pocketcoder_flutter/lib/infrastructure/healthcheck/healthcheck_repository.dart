import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/healthcheck/i_healthcheck_repository.dart';
import "package:pocketcoder_flutter/domain/models/healthcheck.dart";
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import "package:pocketcoder_flutter/domain/models/collections.dart";
import 'package:pocketcoder_flutter/core/try_operation.dart';

@LazySingleton(as: IHealthcheckRepository)
class HealthcheckRepository implements IHealthcheckRepository {
  final PocketBase _pb;

  HealthcheckRepository(this._pb);

  @override
  Future<List<Healthcheck>> getHealthchecks() async {
    return tryMethod(
      () async {
        // Deliberate exception: this pre-login deployment probe must work
        // without an authenticated session.
        final records = await _pb.collection(Collections.healthchecks).getList(
              sort: 'name',
            );

        return records.items
            .map((r) => Healthcheck.fromJson({
                  ...r.toJson(),
                  'id': r.id,
                }))
            .toList();
      },
      RepositoryException.new,
      'getHealthchecks',
    );
  }

  @override
  Future<Healthcheck?> getServiceStatus(String serviceName) async {
    return tryMethod(
      () async {
        // Deliberate exception: status is queried before login.
        final record = await _pb.collection(Collections.healthchecks).getFirstListItem(
              'name = "$serviceName"',
            );

        return Healthcheck.fromJson({
          ...record.toJson(),
          'id': record.id,
        });
      },
      RepositoryException.new,
      'getServiceStatus',
    );
  }

  @override
  Stream<List<RecordModel>> watchHealthchecks() async* {
    final controller = StreamController<List<RecordModel>>();

    // Deliberate exception: this pre-login connectivity stream must work
    // without an authenticated session.
    final unsubscribe = await _pb.collection(Collections.healthchecks).subscribe('*', (e) async {
      try {
        // Deliberate exception: this follow-up health probe is part of the
        // same unauthenticated pre-login connectivity stream.
        final records = await _pb.collection(Collections.healthchecks).getList();
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