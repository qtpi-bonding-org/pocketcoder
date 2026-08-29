import 'dart:async';

import 'package:pocketbase_drift/pocketbase_drift.dart';
import "package:pocketcoder_flutter/infrastructure/core/logger.dart";
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/domain/auth/auth_session_coordinator.dart';

/// A generic Data Access Object (DAO) for PocketBase collections.
///
/// This provides standard CRUD and reactive capabilities, backed by Drift for
/// offline-first local persistence.
abstract class BaseDao<T> {
  static AuthSessionCoordinator? _coordinator;

  /// Supplies the live session source to DAO streams.
  static void configureSessionCoordinator(AuthSessionCoordinator coordinator) {
    _coordinator = coordinator;
  }

  /// Clears the process-wide session source, primarily for lifecycle teardown
  /// and isolated tests.
  static void clearSessionCoordinator() {
    _coordinator = null;
  }

  final PocketBase _pb;
  final String _collection;
  final T Function(Map<String, dynamic> json) _fromJson;

  BaseDao(
    this._pb,
    this._collection,
    this._fromJson,
  );

  PocketBase get pb => _pb;

  /// Access to the underlying PocketBase collection service.
  /// We cast to $RecordService to access drift-enabled features like watchRecords.
  $RecordService get service => _pb.collection(_collection) as $RecordService;

  /// Streams all records in the collection, including local-only changes.
  Stream<List<T>> watch({
    String? filter,
    String? sort,
    String? expand,
    RequestPolicy? requestPolicy,
  }) {
    if (_pb.authStore.token.isEmpty) {
      return Stream<List<T>>.error(AuthException.notAuthenticated());
    }
    // DAO reads always try the network first, falling back to cache only on
    // failure -- there is no meaningful offline mode here (every screen
    // needs the user's own PocketBase deployment to do anything), so a
    // stale-but-present cache must never outrank fresh server data. This
    // also means a recoverable expired token surfaces as an error (see
    // _cachedThenAuthError below) rather than silently hiding behind an
    // already persisted snapshot; callers that need pure offline resilience
    // instead can opt out with an explicit cacheFirst/cacheOnly override.
    final policy = requestPolicy ?? RequestPolicy.networkFirst;
    Stream<List<T>> records = service
        .watchRecords(
          filter: filter,
          sort: sort,
          expand: expand,
          requestPolicy: policy,
        )
        .map(_mapRecords);
    if (!_pb.authStore.isValid && policy.isNetwork) {
      records = _cachedThenAuthError(records);
    }
    final coordinator = _coordinator;
    if (coordinator == null) return records;
    return _withSessionChanges(records, coordinator);
  }

  Stream<List<T>> _cachedThenAuthError(Stream<List<T>> records) {
    return Stream.multi((multi) {
      var emittedCachedSnapshot = false;
      final subscription = records.listen(
        (value) {
          multi.add(value);
          if (!emittedCachedSnapshot) {
            emittedCachedSnapshot = true;
            multi.addError(AuthException.tokenExpired());
          }
        },
        onError: multi.addError,
        onDone: multi.close,
      );
      multi.onCancel = subscription.cancel;
    });
  }

  Stream<List<T>> _withSessionChanges(
    Stream<List<T>> records,
    AuthSessionCoordinator coordinator,
  ) {
    return Stream.multi((multi) {
      final recordSubscription = records.listen(
        multi.add,
        onError: multi.addError,
        onDone: multi.close,
      );
      final sessionSubscription = coordinator.sessionChanges.listen((snapshot) {
        if (snapshot.state == AuthSessionState.signedOut) {
          multi.addError(AuthException.notAuthenticated());
        }
      });
      multi.onCancel = () async {
        await recordSubscription.cancel();
        await sessionSubscription.cancel();
      };
    });
  }

  /// Fetches a one-time list of all records.
  Future<List<T>> getFullList({
    String? filter,
    String? sort,
    String? expand,
    RequestPolicy? requestPolicy,
  }) async {
    if (_pb.authStore.token.isEmpty) {
      throw AuthException.notAuthenticated();
    }
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
    if (_pb.authStore.token.isEmpty) {
      throw AuthException.notAuthenticated();
    }
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
  ///
  /// Always confirmed against the server before returning -- drift is a read
  /// cache only, never a write queue. Forces [RequestPolicy.networkFirst]
  /// regardless of the app's default read policy (`cacheAndNetwork`), so a
  /// write can never be silently local-only: it either succeeds against the
  /// real server (and the cache is populated from that confirmed response)
  /// or throws immediately, including immediately when offline.
  Future<T> save(String? id, Map<String, dynamic> data) async {
    logDebug('DAO [$_collection]: save(id: $id)');
    try {
      RecordModel record;
      if (id == null || id.isEmpty) {
        // Freezed-generated toJson() always includes an "id" key -- for a
        // brand-new record that's an empty string, not absent. PocketBase's
        // create endpoint rejects that outright (expects either a real
        // custom id or no "id" key at all), so it must never be forwarded.
        final createBody = Map<String, dynamic>.from(data)..remove('id');
        record = await service
            .create(
          body: createBody,
          requestPolicy: RequestPolicy.networkFirst,
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
          requestPolicy: RequestPolicy.networkFirst,
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

  /// Always confirmed against the server -- see [save].
  Future<void> delete(String id) async {
    logDebug('DAO [$_collection]: delete(id: $id)');
    try {
      await service
          .delete(
        id,
        requestPolicy: RequestPolicy.networkFirst,
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
