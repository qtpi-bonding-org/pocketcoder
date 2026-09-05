// Local (docker-compose, no VPS) check that the "skills" collection and the
// workspace "files" API actually work end-to-end against a REAL PocketBase
// server -- not a mock DAO, not a Go unit test bypassing HTTP/JSON. Uses the
// real Dart domain model (Skill.fromJson) and the real generated
// pocketcoder_api FilesApi client -- the exact request/response encoding the
// Flutter app uses -- so a pass here means the Flutter SkillsRepository and
// FilesRepository code paths work against this deployment too.
//
// Skills: exercises the create/list/update/delete round trip the real
// SkillsRepository/SkillDao drive (client/packages/pocketcoder_flutter/lib/
// infrastructure/skills/), against the real `skills` PocketBase collection
// and its real API rules (server/pocketbase/pb_migrations/schema.json).
//
// Files: exercises GET /api/pocketcoder/v1/files-tree and
// /api/pocketcoder/v1/files (server/pocketbase/internal/filesystem/
// filesystem.go), which serve the shared `workspace` docker volume mounted
// directly into the pocketbase container -- the same volume real harness
// containers get their own workspace derived from
// (server/pocketbase/internal/dockerapi). A probe file is written into that
// volume via `docker exec` against the real pocketbase container before
// asserting the real FilesApi client can list/read it back.
//
// Run:
//   docker compose up -d --wait pocketbase
//   POCKETBASE_SUPERUSER_EMAIL=... POCKETBASE_SUPERUSER_PASSWORD=... \
//   PB_URL=http://127.0.0.1:8090 \
//   flutter test test/integration/skills_and_files_real_backend_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart' as pocketbase;
import 'package:pocketcoder_api/pocketcoder_api.dart' as generated;
import 'package:pocketcoder_flutter/domain/models/skill.dart';

void main() {
  final baseUrl = Platform.environment['PB_URL'] ?? 'http://127.0.0.1:8090';
  final superuserEmail = Platform.environment['POCKETBASE_SUPERUSER_EMAIL'];
  final superuserPassword =
      Platform.environment['POCKETBASE_SUPERUSER_PASSWORD'];
  final pocketbaseContainer =
      Platform.environment['POCKETBASE_CONTAINER'] ?? 'pocketcoder-pocketbase';

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

  group('files (real workspace file API)', () {
    test(
      'a file written into the shared workspace volume is visible through '
      'the real listWorkspaceFileTree/getWorkspaceFile API the same way '
      'FilesRepository reads it',
      () async {
        pocketbase.PocketBase client;
        try {
          client = await ensureTestUserClient();
        } on StateError {
          markTestSkipped('POCKETBASE_SUPERUSER_EMAIL/PASSWORD not set -- '
              'bring up docker compose (see .env) and export them.');
          return;
        }

        const probeDir = '.skills-files-integration-test';
        const probeFile = 'probe.txt';
        final probeContent =
            'probe-${DateTime.now().millisecondsSinceEpoch}\n';

        Future<ProcessResult> dockerExec(List<String> shellArgs) => Process.run(
              'docker',
              ['exec', pocketbaseContainer, 'sh', '-c', ...shellArgs],
            );

        final write = await dockerExec([
          'mkdir -p /workspace/$probeDir && '
              'printf %s "\$1" > /workspace/$probeDir/$probeFile',
          'sh',
          probeContent,
        ]);
        if (write.exitCode != 0) {
          fail('could not write the probe file via `docker exec` into '
              '$pocketbaseContainer -- is the real docker-compose stack up? '
              '(${write.stderr})');
        }
        addTearDown(() => dockerExec(['rm -rf /workspace/$probeDir']));

        final dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          headers: {'Authorization': client.authStore.token},
        ));
        final filesApi = generated.FilesApi(dio, generated.standardSerializers);

        final treeResp = await filesApi.listWorkspaceFileTree(path: probeDir);
        expect(treeResp.statusCode, 200);
        final entries = treeResp.data?.entries.toList() ?? const [];
        final probeEntry =
            entries.where((e) => e.name == probeFile).firstOrNull;
        expect(probeEntry, isNotNull,
            reason: 'listWorkspaceFileTree(path: "$probeDir") returned '
                '${entries.map((e) => e.name).toList()}, expected to find '
                '"$probeFile" written directly into the shared workspace '
                'volume');
        expect(probeEntry!.isDir, isFalse);
        expect(probeEntry.size, utf8.encode(probeContent).length);

        final fileResp =
            await filesApi.getWorkspaceFile(path: '$probeDir/$probeFile');
        expect(fileResp.statusCode, 200);
        expect(utf8.decode(fileResp.data ?? const []), probeContent);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });
}
