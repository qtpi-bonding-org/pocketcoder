import 'dart:async';
import 'package:pocketbase_drift/pocketbase_drift.dart';
import 'logger.dart';

/// A generic Data Access Object (DAO) for PocketBase collections.
///
/// This provides standard CRUD and reactive capabilities, backed by Drift for
/// offline-first local persistence.
abstract class BaseDao<T> {
  final PocketBase _pb;
  final String _collection;
  final T Function(Map<String, dynamic> json) _fromJson;

  BaseDao(
    this._pb,
    this._collection,
    this._fromJson,
  );

  /// Access to the underlying PocketBase collection service.
  /// We cast to $RecordService to access drift-enabled features like watchRecords.
  $RecordService get service => _pb.collection(_collection) as $RecordService;

  /// Streams all records in the collection, including local-only changes.
  Stream<List<T>> watch({
    String? filter,
    String? sort,
    String? expand,
  }) {
    return service
        .watchRecords(
          filter: filter,
          sort: sort,
          expand: expand,
        )
        .map(_mapRecords);
  }

  /// Fetches a one-time list of all records.
  Future<List<T>> getFullList({
    String? filter,
    String? sort,
    String? expand,
    RequestPolicy? requestPolicy,
  }) async {
    logDebug(
        'DAO [$_collection]: getFullList(filter: $filter, policy: $requestPolicy)');
    try {
      final records = await service
          .getFullList(
        filter: filter,
        sort: sort,
        expand: expand,
        requestPolicy: requestPolicy,
      )
          .timeout(const Duration(seconds: 10), onTimeout: () {
        logWarning('DAO [$_collection]: getFullList TIMEOUT after 10s');
        throw TimeoutException('PocketBase getFullList timed out');
      });
      logDebug(
          'DAO [$_collection]: getFullList returned ${records.length} records');
      return _mapRecords(records);
    } catch (e, stack) {
      logError('DAO [$_collection]: getFullList failed', e, stack);
      rethrow;
    }
  }

  /// Fetches a single record by ID.
  Future<T> getOne(
    String id, {
    String? expand,
    RequestPolicy? requestPolicy,
  }) async {
    logDebug('DAO [$_collection]: getOne(id: $id, policy: $requestPolicy)');
    try {
      final record = await service
          .getOne(
        id,
        expand: expand,
        requestPolicy: requestPolicy,
      )
          .timeout(const Duration(seconds: 10), onTimeout: () {
        logWarning('DAO [$_collection]: getOne($id) TIMEOUT after 10s');
        throw TimeoutException('PocketBase getOne timed out');
      });
      logDebug('DAO [$_collection]: getOne($id) returned record');
      return _mapRecord(record);
    } catch (e, stack) {
      logError('DAO [$_collection]: getOne($id) failed', e, stack);
      rethrow;
    }
  }

  /// Persists a record (creates if ID is missing or empty).
  Future<T> save(
    String? id,
    Map<String, dynamic> data, {
    RequestPolicy? requestPolicy,
  }) async {
    logDebug('DAO [$_collection]: save(id: $id)');
    try {
      RecordModel record;
      if (id == null || id.isEmpty) {
        record = await service
            .create(
          body: data,
          requestPolicy: requestPolicy,
        )
            .timeout(const Duration(seconds: 10), onTimeout: () {
          logWarning('DAO [$_collection]: create TIMEOUT after 10s');
          throw TimeoutException('PocketBase create timed out');
        });
      } else {
        record = await service
            .update(
          id,
          body: data,
          requestPolicy: requestPolicy,
        )
            .timeout(const Duration(seconds: 10), onTimeout: () {
          logWarning('DAO [$_collection]: update($id) TIMEOUT after 10s');
          throw TimeoutException('PocketBase update timed out');
        });
      }
      logDebug('DAO [$_collection]: save complete');
      return _mapRecord(record);
    } catch (e, stack) {
      logError('DAO [$_collection]: save failed', e, stack);
      rethrow;
    }
  }

  Future<void> delete(String id, {RequestPolicy? requestPolicy}) async {
    logDebug('DAO [$_collection]: delete(id: $id)');
    try {
      await service
          .delete(
        id,
        requestPolicy: requestPolicy,
      )
          .timeout(const Duration(seconds: 10), onTimeout: () {
        logWarning('DAO [$_collection]: delete($id) TIMEOUT after 10s');
        throw TimeoutException('PocketBase delete timed out');
      });
      logDebug('DAO [$_collection]: delete complete');
    } catch (e, stack) {
      logError('DAO [$_collection]: delete failed', e, stack);
      rethrow;
    }
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  List<T> _mapRecords(List<RecordModel> records) {
    return records.map(_mapRecord).toList();
  }

  T _mapRecord(RecordModel record) {
    try {
      // Official SDK Bridge: Leverage record.toJson() as the source of truth.
      // This includes id, created, updated, and all data fields automatically.
      final json = record.toJson();

      // Sanitization: Fix empty date strings that would crash DateTime.parse.
      json.forEach((key, value) {
        if (value == '' &&
            (key.endsWith('_at') ||
                key == 'created' ||
                key == 'updated' ||
                key.startsWith('last_'))) {
          json[key] = null;
        }
      });

      return _fromJson(json);
    } catch (e, stack) {
      logError('DAO [$_collection]: Mapping record failed for ID: ${record.id}',
          e, stack);
      rethrow;
    }
  }
}
