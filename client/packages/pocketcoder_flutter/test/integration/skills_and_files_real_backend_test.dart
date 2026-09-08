// Run:
//   docker compose up -d --wait pocketbase
//   POCKETBASE_SUPERUSER_EMAIL=... POCKETBASE_SUPERUSER_PASSWORD=... \
//   PB_URL=http://127.0.0.1:8090 \
//   flutter test test/integration/skills_and_files_real_backend_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart' as pocketbase;
import 'package:pocketbase_drift/pocketbase_drift.dart';
import 'package:pocketcoder_flutter/infrastructure/skills/skill_dao.dart';
import 'package:pocketcoder_flutter/infrastructure/skills/skills_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final baseUrl = Platform.environment['PB_URL'] ?? 'http://127.0.0.1:8090';
  final superuserEmail = Platform.environment['POCKETBASE_SUPERUSER_EMAIL'];
  final superuserPassword =
      Platform.environment['POCKETBASE_SUPERUSER_PASSWORD'];

  /// Authenticates as the seeded superuser (bypasses the `users` collection's
  /// admin-only createRule) and returns an ordinary "user"-role test account,
  /// creating it the first time and reusing it on later runs -- this test
  /// never needs a pre-seeded API_TEST_EMAIL/AGENT_TEST_EMAIL account.
  Future<pocketbase.PocketBase> ensureTestUserClient() async {
    if (superuserEmail == null || superuserPassword == null) {
      throw StateError('skip');
    }
    final admin = pocketbase.PocketBase(baseUrl);
    await admin
        .collection('_superusers')
        .authWithPassword(superuserEmail, superuserPassword);

    const email = 'skills-files-integration-test@pocketcoder.local';
    const password = 'skills-files-integration-test-pw';
    final existing =
        await admin.collection('users').getFullList(filter: "email = '$email'");
    if (existing.isEmpty) {
      await admin.collection('users').create(body: {
        'email': email,
        'password': password,
        'passwordConfirm': password,
        'role': 'user',
        'verified': true,
      });
    }

    final userClient = pocketbase.PocketBase(baseUrl);
    await userClient.collection('users').authWithPassword(email, password);
    return userClient;
  }

  Future<$PocketBase> asDriftClient(pocketbase.PocketBase plain) async {
    final store = $AuthStore(save: (_) async {});
    store.save(plain.authStore.token, plain.authStore.record);
    final drift = $PocketBase.database(
      baseUrl,
      inMemory: true,
      authStore: store,
      requestPolicy: RequestPolicy.networkFirst,
    );
    final schemaJson = await rootBundle.loadString('assets/pb_schema.json');
    final decoded = jsonDecode(schemaJson);
    final schemaList =
        decoded is Map ? decoded['items'] as List<dynamic> : decoded as List<dynamic>;
    await drift.setSchema(jsonEncode(schemaList));
    return drift;
  }

  group('skills (real PocketBase collection)', () {
    test(
      'create -> list -> update -> delete round-trips through '
      'SkillsRepository itself against a real PocketBase',
      () async {
        pocketbase.PocketBase plain;
        try {
          plain = await ensureTestUserClient();
        } on StateError {
          markTestSkipped('POCKETBASE_SUPERUSER_EMAIL/PASSWORD not set -- '
              'bring up docker compose (see .env) and export them.');
          return;
        }
        final client = await asDriftClient(plain);
        addTearDown(client.close);
        final repo = SkillsRepository(SkillDao(client));

        final name =
            'integration-test-skill-${DateTime.now().millisecondsSinceEpoch}';
        final created = await repo.createSkill(
          name: name,
          description: 'Created by skills_and_files_real_backend_test.',
          content: '# Integration test skill\n\nJust a probe.',
          global: true,
        );
        addTearDown(() async {
          try {
            await repo.deleteSkill(created.id);
          } catch (_) {
            // Already deleted by the test body's own delete assertion below.
          }
        });

        expect(created.name, name);
        expect(created.active, isTrue,
            reason: 'RegisterAgentFileHooks\' create hook always sets '
                'active = true for a new skill');
        expect(created.isSystem, isFalse,
            reason: 'the create hook forces is_system = false for a '
                'user-created skill regardless of what the client sent');

        final listed = await repo.listSkills();
        expect(listed.map((s) => s.id), contains(created.id));

        final updatedContent = '${created.content}\n\nUpdated.';
        final updated = await repo.updateSkill(
          id: created.id,
          name: name,
          description: created.description,
          content: updatedContent,
        );
        expect(updated.content, updatedContent);

        await repo.deleteSkill(created.id);
        final afterDelete = await client
            .collection('skills')
            .getFullList(filter: "id = '${created.id}'");
        expect(afterDelete, isEmpty);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });
}
