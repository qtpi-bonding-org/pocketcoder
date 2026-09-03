import 'dart:async';

import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:meta/meta.dart';
import 'package:pocketcoder_flutter/domain/settings/i_local_settings_service.dart';
import 'package:pocketcoder_flutter/infrastructure/settings/local_settings_database.dart';

@LazySingleton(as: ILocalSettingsService)
class LocalSettingsService implements ILocalSettingsService {
  LocalSettingsService(this._db) {
    _cacheSub = watchHapticsEnabled().listen((v) => _cachedHapticsEnabled = v);
  }

  final LocalSettingsDatabase _db;
  late final StreamSubscription<bool> _cacheSub;
  bool _cachedHapticsEnabled = true;

  /// This singleton is never disposed in production, so [_cacheSub] is
  /// never cancelled there. A test must call this before closing its
  /// database, or the subscription can outlive the test and throw.
  @visibleForTesting
  Future<void> cancelCacheSubscriptionForTest() => _cacheSub.cancel();

  static const _rowId = 0;

  @override
  bool get hapticsEnabledSync => _cachedHapticsEnabled;

  Future<void> _ensureRow() async {
    final existing = await (_db.select(_db.localSettings)
          ..where((t) => t.id.equals(_rowId)))
        .getSingleOrNull();
    if (existing == null) {
      await _db.into(_db.localSettings).insertOnConflictUpdate(
            LocalSettingsCompanion.insert(id: const Value(_rowId)),
          );
    }
  }

  @override
  Stream<bool> watchHapticsEnabled() async* {
    await _ensureRow();
    yield* (_db.select(_db.localSettings)..where((t) => t.id.equals(_rowId)))
        .watchSingle()
        .map((row) => row.hapticsEnabled);
  }

  @override
  Future<void> setHapticsEnabled(bool enabled) async {
    await _ensureRow();
    await (_db.update(_db.localSettings)
          ..where((t) => t.id.equals(_rowId)))
        .write(LocalSettingsCompanion(hapticsEnabled: Value(enabled)));
  }
}
