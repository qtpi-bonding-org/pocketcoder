import 'package:pocketbase_drift/pocketbase_drift.dart';

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
    final records = await service.getFullList(
      filter: filter,
      sort: sort,
      expand: expand,
      requestPolicy: requestPolicy,
    );
    return _mapRecords(records);
  }

  /// Fetches a single record by ID.
  Future<T> getOne(
    String id, {
    String? expand,
    RequestPolicy? requestPolicy,
  }) async {
    final record = await service.getOne(
      id,
      expand: expand,
      requestPolicy: requestPolicy,
    );
    return _mapRecord(record);
  }

  /// Persists a record (creates if ID is missing or empty).
  Future<T> save(
    String? id,
    Map<String, dynamic> data, {
    RequestPolicy? requestPolicy,
  }) async {
    RecordModel record;
    if (id == null || id.isEmpty) {
      record = await service.create(
        body: data,
        requestPolicy: requestPolicy,
      );
    } else {
      record = await service.update(
        id,
        body: data,
        requestPolicy: requestPolicy,
      );
    }
    return _mapRecord(record);
  }

  /// Deletes a record.
  Future<void> delete(String id, {RequestPolicy? requestPolicy}) async {
    await service.delete(
      id,
      requestPolicy: requestPolicy,
    );
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  List<T> _mapRecords(List<RecordModel> records) {
    return records.map(_mapRecord).toList();
  }

  T _mapRecord(RecordModel record) {
    // Merge the record ID into the data map so the domain model's fromJson
    // can pick it up. Standard PocketBase records keep ID outside 'data'.
    final json = {
      ...record.data,
      'id': record.id,
      'created': record.get<String>('created'),
      'updated': record.get<String>('updated'),
      'expand': record.expand,
    };
    return _fromJson(json);
  }
}
