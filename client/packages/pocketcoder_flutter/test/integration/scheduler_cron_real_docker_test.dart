import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart' as pocketbase;
import 'package:pocketbase_drift/pocketbase_drift.dart';
import 'package:pocketcoder_flutter/domain/scheduler/friendly_schedule.dart';
import 'package:pocketcoder_flutter/infrastructure/core/pocketcoder_api_client.dart';
import 'package:pocketcoder_flutter/infrastructure/scheduler/schedule_owner_dao.dart';
import 'package:pocketcoder_flutter/infrastructure/scheduler/scheduler_repository.dart';

/// The friendly schedule picker (frequency/day/time) never lets the user
/// type a cron string directly -- it always goes through
/// [FriendlySchedule.toCron]. This test proves those generated strings are
/// actually accepted by the real backend validation
/// (server/pocketbase/internal/api/schedules.go, which rejects anything
/// `cron.NewSchedule` can't parse), not just internally self-consistent
/// with our own [FriendlySchedule.tryParseCron]. Requires a running
/// `docker compose` stack (see .env) with POCKETBASE_SUPERUSER_EMAIL/
/// PASSWORD exported.
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final baseUrl = Platform.environment['PB_URL'] ?? 'http://127.0.0.1:8090';
  final superuserEmail = Platform.environment['POCKETBASE_SUPERUSER_EMAIL'];
  final superuserPassword =
      Platform.environment['POCKETBASE_SUPERUSER_PASSWORD'];

  test(
    'every cron shape FriendlySchedule can generate is accepted by the '
    'real PocketBase schedule_owners validation',
    () async {
      if (superuserEmail == null || superuserPassword == null) {
        markTestSkipped('POCKETBASE_SUPERUSER_EMAIL/PASSWORD not set -- '
            'bring up docker compose (see .env) and export them.');
        return;
      }

      final admin = pocketbase.PocketBase(baseUrl);
      await admin
          .collection('_superusers')
          .authWithPassword(superuserEmail, superuserPassword);

      const email = 'scheduler-cron-e2e-test@pocketcoder.local';
      const password = 'scheduler-cron-e2e-test-password';
      for (final existing in await admin
          .collection('users')
          .getFullList(filter: "email = '$email'")) {
        await admin.collection('users').delete(existing.id);
      }
      final user = await admin.collection('users').create(body: {
        'email': email,
        'password': password,
        'passwordConfirm': password,
        'role': 'user',
        'verified': true,
      });
      addTearDown(() => admin.collection('users').delete(user.id));

      final verifyClient = pocketbase.PocketBase(baseUrl);
      await verifyClient.collection('users').authWithPassword(email, password);
      final token = verifyClient.authStore.token;
      final authRecord = verifyClient.authStore.record;

      final store = $AuthStore(save: (_) async {});
      store.save(token, authRecord);
      final client = $PocketBase.database(
        baseUrl,
        inMemory: true,
        authStore: store,
        requestPolicy: RequestPolicy.networkFirst,
      );
      addTearDown(client.close);
      final schemaJson = await rootBundle.loadString('assets/pb_schema.json');
      final decoded = jsonDecode(schemaJson);
      final schemaList = decoded is Map
          ? decoded['items'] as List<dynamic>
          : decoded as List<dynamic>;
      await client.setSchema(jsonEncode(schemaList));

      final repo = SchedulerRepository(
        PocketCoderApiClient(dio: Dio(BaseOptions(baseUrl: baseUrl))),
        ScheduleOwnerDao(client),
      );

      final cases = <String, FriendlySchedule>{
        'hourly': FriendlySchedule(frequency: ScheduleFrequency.hourly),
        'daily at 09:00': FriendlySchedule(
            frequency: ScheduleFrequency.daily, hour: 9, minute: 0),
        'daily at 23:59': FriendlySchedule(
            frequency: ScheduleFrequency.daily, hour: 23, minute: 59),
        'weekly Mon/Wed/Fri at 08:15': FriendlySchedule(
            frequency: ScheduleFrequency.weekly,
            hour: 8,
            minute: 15,
            daysOfWeek: {1, 3, 5}),
        'weekly Sun/Sat at 00:00': FriendlySchedule(
            frequency: ScheduleFrequency.weekly,
            hour: 0,
            minute: 0,
            daysOfWeek: {0, 6}),
      };

      for (final entry in cases.entries) {
        final cron = entry.value.toCron();
        final created = await repo.createSchedule(
          displayName: 'cron e2e ${entry.key}',
          cron: cron,
          prompt: 'echo hello',
        );
        addTearDown(() => repo.deleteSchedule(created.id));

        // createSchedule succeeding at all already proves the server's
        // `cron.NewSchedule` validation accepted the string (it returns a
        // 400 -- surfaced as a thrown SchedulerException -- otherwise).
        // Re-fetch to also confirm it was actually persisted as sent.
        final stored =
            await client.collection('schedule_owners').getOne(created.id);
        expect(stored.get<String>('cron'), cron,
            reason: 'server should persist the exact cron string generated '
                'for "${entry.key}"');

        // And that the round-trip through our own reverse-parser matches --
        // the edit dialog depends on this to preload the picker correctly.
        final reparsed = FriendlySchedule.tryParseCron(stored.get<String>('cron'));
        expect(reparsed, isNotNull, reason: 'stored cron for "${entry.key}" '
            'should still be recognised by tryParseCron');
        expect(reparsed!.frequency, entry.value.frequency);
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
