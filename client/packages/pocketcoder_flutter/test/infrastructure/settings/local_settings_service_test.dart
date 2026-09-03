import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/infrastructure/settings/local_settings_database.dart';
import 'package:pocketcoder_flutter/infrastructure/settings/local_settings_service.dart';

void main() {
  late LocalSettingsDatabase db;
  late LocalSettingsService service;

  setUp(() {
    db = LocalSettingsDatabase(NativeDatabase.memory());
    service = LocalSettingsService(db);
  });

  tearDown(() async {
    // The service's constructor starts a background subscription that
    // outlives this test's synchronous body -- cancel it before closing
    // the database, or it can throw against the next test's fresh db.
    await service.cancelCacheSubscriptionForTest();
    await db.close();
  });

  test('hapticsEnabledSync defaults to true before anything is loaded', () {
    expect(service.hapticsEnabledSync, isTrue);
  });

  test('watchHapticsEnabled emits true on first subscribe with no row yet',
      () async {
    expect(await service.watchHapticsEnabled().first, isTrue);
  });

  test('setHapticsEnabled persists and watchHapticsEnabled reflects it',
      () async {
    final values = <bool>[];
    final sub = service.watchHapticsEnabled().listen(values.add);
    addTearDown(sub.cancel);
    await pumpEventQueue();

    await service.setHapticsEnabled(false);
    await pumpEventQueue();

    expect(values, [true, false]);
  });

  test('hapticsEnabledSync updates after setHapticsEnabled', () async {
    await service.setHapticsEnabled(false);
    await pumpEventQueue();

    expect(service.hapticsEnabledSync, isFalse);
  });

  test('a second service instance over the same database sees the '
      'persisted value', () async {
    await service.setHapticsEnabled(false);

    final second = LocalSettingsService(db);
    addTearDown(second.cancelCacheSubscriptionForTest);
    expect(await second.watchHapticsEnabled().first, isFalse);
  });
}
