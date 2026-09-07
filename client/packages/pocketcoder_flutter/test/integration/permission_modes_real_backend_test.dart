// Run:
//   docker compose up -d --wait pocketbase
//   POCKETBASE_SUPERUSER_EMAIL=... POCKETBASE_SUPERUSER_PASSWORD=... \
//   PB_URL=http://127.0.0.1:8090 \
//   flutter test test/integration/permission_modes_real_backend_test.dart
//
// Exercises PermissionModeRepository -- the real client-side path the
// Tool Permissions/permission-modes screens use -- against a real
// PocketBase, not a mocked DAO (see permission_mode_repository_test.dart
// for that). Covers the full round trip: duplicating a seeded system
// preset into a personal mode, editing its rules, and deleting it --
// including that permission_mode_tools.permission_mode's cascadeDelete
// actually removes the duplicated rules server-side when the mode goes.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart' as pocketbase;
import 'package:pocketbase_drift/pocketbase_drift.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder_flutter/domain/models/tool_permission.dart';
import 'package:pocketcoder_flutter/infrastructure/agent_config/agent_config_daos.dart';
import 'package:pocketcoder_flutter/infrastructure/permission_modes/permission_mode_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/permission_modes/tool_permission_dao.dart';

/// Reports a fixed user id, matching PermissionModeRepository.saveMode/
/// duplicateMode which stamp `user` from the authenticated caller rather
/// than trusting a client-supplied value.
class _FixedUserAuthRepository implements IAuthRepository {
  _FixedUserAuthRepository(this.currentUserId);

  @override
  final String? currentUserId;

  @override
  Stream<bool> get connectionStatus => const Stream.empty();
  @override
  Stream<void> get authChanges => const Stream.empty();
  @override
  Future<bool> login(String email, String password) =>
      throw UnimplementedError();
  @override
  Future<void> logout() => throw UnimplementedError();
  @override
  Future<void> clearSession() => throw UnimplementedError();
  @override
  Future<AuthRefreshResult> refreshToken() => throw UnimplementedError();
  @override
  Future<void> verifyServerCompatibility() => throw UnimplementedError();
  @override
  bool get isAuthenticated => true;
  @override
  String? get currentUserEmail => null;
  @override
  String? get currentUserRole => null;
  @override
  String? get currentBaseUrl => null;
  @override
  Future<void> updateBaseUrl(String url) => throw UnimplementedError();
  @override
  Future<void> persistBaseUrl(String url) => throw UnimplementedError();
  @override
  Future<String?> getSavedBaseUrl() => throw UnimplementedError();
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final baseUrl = Platform.environment['PB_URL'] ?? 'http://127.0.0.1:8090';
  final superuserEmail = Platform.environment['POCKETBASE_SUPERUSER_EMAIL'];
  final superuserPassword =
      Platform.environment['POCKETBASE_SUPERUSER_PASSWORD'];

  /// Authenticates as the seeded superuser (bypasses the `users` collection's
  /// admin-only createRule) and returns an ordinary "user"-role test account,
  /// creating it the first time and reusing it on later runs.
  Future<pocketbase.PocketBase> ensureTestUserClient() async {
    if (superuserEmail == null || superuserPassword == null) {
      throw StateError('skip');
    }
    final admin = pocketbase.PocketBase(baseUrl);
    await admin
        .collection('_superusers')
        .authWithPassword(superuserEmail, superuserPassword);

    const email = 'permission-modes-integration-test@pocketcoder.local';
    const password = 'permission-modes-integration-test-pw';
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

  // pocketbase_drift's watch() streams emit synchronously from the local
  // (empty, for a freshly authenticated in-memory client) cache before the
  // real networkFirst fetch lands and re-emits the settled result -- a bare
  // `.first` on a cold stream races that intermediate empty snapshot.
  // Wait for the specific condition each assertion actually needs instead.
  Future<List<T>> firstMatching<T>(
    Stream<List<T>> stream,
    bool Function(List<T> value) predicate,
  ) =>
      stream.firstWhere(predicate);

  group('permission modes (real PocketBase collections)', () {
    test(
      'duplicate a seeded system mode, edit its rules, then delete it -- '
      'all through PermissionModeRepository itself against a real '
      'PocketBase, including cascade-deleting the duplicated rules',
      () async {
        pocketbase.PocketBase plain;
        try {
          plain = await ensureTestUserClient();
        } on StateError {
          markTestSkipped('POCKETBASE_SUPERUSER_EMAIL/PASSWORD not set -- '
              'bring up docker compose (see .env) and export them.');
          return;
        }
        final userId = plain.authStore.record!.id;
        final client = await asDriftClient(plain);
        addTearDown(client.close);
        final repo = PermissionModeRepository(
          PermissionModeDao(client),
          ToolPermissionDao(client),
          _FixedUserAuthRepository(userId),
        );

        const seededNames = ['manual', 'read', 'write', 'auto'];
        final modes = await firstMatching(repo.watchModes(),
            (list) => seededNames.every((n) => list.any((m) => m.name == n)));
        final byName = {for (final m in modes) m.name: m};
        final sourceMode = byName['read']!;
        expect(sourceMode.isSystem, isTrue);
        final sourceRules = await firstMatching(
            repo.watchRules(sourceMode.id), (list) => list.isNotEmpty);
        expect(sourceRules, isNotEmpty,
            reason: 'the seeded "read" mode has read-only allow rules');

        final newName =
            'integration-test-copy-${DateTime.now().millisecondsSinceEpoch}';
        await repo.duplicateMode(source: sourceMode, newName: newName);

        final afterDuplicate = await firstMatching(repo.watchModes(),
            (list) => list.any((m) => m.name == newName));
        final created = afterDuplicate.firstWhere((m) => m.name == newName);
        addTearDown(() async {
          try {
            await repo.deleteMode(created.id);
          } catch (_) {
            // Already deleted by the test body's own delete assertion below.
          }
        });

        expect(created.isSystem, isFalse,
            reason: 'a duplicated mode is always personal, even when its '
                'source was a system preset');
        expect(created.user, userId,
            reason: 'duplicateMode must stamp the authenticated user, not '
                'trust any client-supplied value');

        final duplicatedRules = await firstMatching(
            repo.watchRules(created.id),
            (list) => list.length == sourceRules.length);
        expect(duplicatedRules.length, sourceRules.length,
            reason: 'duplicateMode must copy every rule from the source');
        expect(
          duplicatedRules.map((r) => (r.tool, r.pattern, r.action)).toSet(),
          sourceRules.map((r) => (r.tool, r.pattern, r.action)).toSet(),
        );

        await repo.createRule(
          modeId: created.id,
          tool: 'integration-test-tool',
          action: 'ask',
        );
        var rules = await firstMatching(repo.watchRules(created.id),
            (list) => list.any((r) => r.tool == 'integration-test-tool'));
        var newRule =
            rules.firstWhere((r) => r.tool == 'integration-test-tool');
        expect(newRule.pattern, '*');
        expect(newRule.action, ToolPermissionAction.ask);
        expect(newRule.active, isTrue);

        await repo.updateAction(newRule.id, 'allow');
        rules = await firstMatching(
            repo.watchRules(created.id),
            (list) => list.any((r) =>
                r.id == newRule.id && r.action == ToolPermissionAction.allow));
        newRule = rules.firstWhere((r) => r.id == newRule.id);
        expect(newRule.action, ToolPermissionAction.allow);

        await repo.setActive(newRule.id, false);
        rules = await firstMatching(
            repo.watchRules(created.id),
            (list) =>
                list.any((r) => r.id == newRule.id && r.active == false));
        newRule = rules.firstWhere((r) => r.id == newRule.id);
        expect(newRule.active, isFalse);

        await repo.deleteMode(created.id);
        final afterDeleteModes = await plain
            .collection('permission_modes')
            .getFullList(filter: "id = '${created.id}'");
        expect(afterDeleteModes, isEmpty);
        final afterDeleteRules = await plain
            .collection('permission_mode_tools')
            .getFullList(filter: "permission_mode = '${created.id}'");
        expect(afterDeleteRules, isEmpty,
            reason: 'permission_mode_tools.permission_mode is '
                'cascadeDelete: true -- deleting the mode must delete its '
                'rules with it, not leave them dangling');
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });
}
