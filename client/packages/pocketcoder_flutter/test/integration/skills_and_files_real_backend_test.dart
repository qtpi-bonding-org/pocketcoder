// Run:
//   docker compose up -d --wait pocketbase
//   POCKETBASE_SUPERUSER_EMAIL=... POCKETBASE_SUPERUSER_PASSWORD=... \
//   PB_URL=http://127.0.0.1:8090 \
//   flutter test test/integration/skills_and_files_real_backend_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart' as pocketbase;
import 'package:pocketcoder_flutter/domain/models/skill.dart';

void main() {
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

  group('skills (real PocketBase collection)', () {
    test(
      'create -> list -> update -> delete round-trips through the real '
      '`skills` collection the same way SkillsRepository/SkillDao do',
      () async {
        pocketbase.PocketBase client;
        try {
          client = await ensureTestUserClient();
        } on StateError {
          markTestSkipped('POCKETBASE_SUPERUSER_EMAIL/PASSWORD not set -- '
              'bring up docker compose (see .env) and export them.');
          return;
        }

        final name =
            'integration-test-skill-${DateTime.now().millisecondsSinceEpoch}';
        final created = Skill.fromRecord(await client.collection('skills').create(
          body: {
            'name': name,
            'description': 'Created by skills_and_files_real_backend_test.',
            'content': '# Integration test skill\n\nJust a probe.',
          },
        ));
        addTearDown(() async {
          try {
            await client.collection('skills').delete(created.id);
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

        final listed = (await client
                .collection('skills')
                .getFullList(filter: 'active = true', sort: 'name'))
            .map(Skill.fromRecord)
            .toList();
        expect(listed.map((s) => s.id), contains(created.id),
            reason: 'SkillsRepository.listSkills() uses this exact filter');

        final updatedContent = '${created.content}\n\nUpdated.';
        final updated = Skill.fromRecord(await client
            .collection('skills')
            .update(created.id, body: {
          'name': name,
          'description': created.description,
          'content': updatedContent,
        }));
        expect(updated.content, updatedContent);

        await client.collection('skills').delete(created.id);
        final afterDelete = await client
            .collection('skills')
            .getFullList(filter: "id = '${created.id}'");
        expect(afterDelete, isEmpty);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });
}
