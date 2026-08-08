// Live test: exercises the REAL SshServerUpdateService (the actual class
// the app's "Update Server" button calls, not a manual ssh-CLI equivalent)
// against a real, already-deployed box. Pure Dart -- no Flutter widgets
// involved, so this needs no simulator/device and no running app.
//
// Gated behind SERVER_UPDATE_LIVE_TEST=1 (real SSH exec against a real
// box, not run in normal test sweeps). Needs SERVER_UPDATE_TEST_HOST (the
// box's sslip.io domain or IP) and SERVER_UPDATE_TEST_KEY_PATH (a locally
// readable file holding the root private key PEM for that box -- e.g. the
// key file the golden-path test persists when AEROFORM_KEEP_INSTANCE is
// on).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';

import 'package:flutter_aeroform/domain/models/instance_credentials.dart';
import 'package:flutter_aeroform/domain/models/provision_session.dart';
import 'package:flutter_aeroform/domain/storage/i_secure_storage.dart';

import 'package:pocketcoder_pro/infrastructure/server_update/ssh_server_update_service.dart';

/// Minimal ISecureStorage that only implements what SshServerUpdateService
/// actually calls (getInstanceCredentials) -- everything else throws if
/// touched, since this test has no business exercising OAuth/cert storage.
class _FakeSecureStorage implements ISecureStorage {
  final InstanceCredentials credentials;
  _FakeSecureStorage(this.credentials);

  @override
  Future<InstanceCredentials?> getInstanceCredentials(
          String instanceId) async =>
      credentials;

  @override
  Future<void> storeAccessToken(String token) => throw UnimplementedError();
  @override
  Future<String?> getAccessToken() => throw UnimplementedError();
  @override
  Future<void> storeRefreshToken(String token) => throw UnimplementedError();
  @override
  Future<String?> getRefreshToken() => throw UnimplementedError();
  @override
  Future<void> storeTokenExpiration(DateTime expiresAt) =>
      throw UnimplementedError();
  @override
  Future<DateTime?> getTokenExpiration() => throw UnimplementedError();
  @override
  Future<void> storeCodeVerifier(String codeVerifier) =>
      throw UnimplementedError();
  @override
  Future<String?> getCodeVerifier() => throw UnimplementedError();
  @override
  Future<void> storeInstanceCredentials(InstanceCredentials c) =>
      throw UnimplementedError();
  @override
  Future<void> clearAll() => throw UnimplementedError();
  @override
  Future<void> storeProvisionSession(ProvisionSession session) =>
      throw UnimplementedError();
  @override
  Future<ProvisionSession?> getProvisionSession() =>
      throw UnimplementedError();
  @override
  Future<void> clearProvisionSession(String sessionId) =>
      throw UnimplementedError();
  @override
  Future<void> clearAuthCredentials() => throw UnimplementedError();
  @override
  Future<void> clearInstanceSecrets(String instanceId) =>
      throw UnimplementedError();
}

void main() {
  test(
    'SshServerUpdateService runs the real update sequence against a live box',
    () async {
      if (Platform.environment['SERVER_UPDATE_LIVE_TEST'] != '1') {
        // ignore: avoid_print
        print('Skipping: set SERVER_UPDATE_LIVE_TEST=1 to run this live.');
        return;
      }

      final host = Platform.environment['SERVER_UPDATE_TEST_HOST'];
      final keyPath = Platform.environment['SERVER_UPDATE_TEST_KEY_PATH'];
      if (host == null || host.isEmpty || keyPath == null || keyPath.isEmpty) {
        fail(
            'SERVER_UPDATE_TEST_HOST and SERVER_UPDATE_TEST_KEY_PATH must be set.');
      }

      final privateKey = await File(keyPath).readAsString();
      const instanceId = 'live-test-instance';

      final credentials = InstanceCredentials(
        instanceId: instanceId,
        rootSshPrivateKey: privateKey,
      );

      final pocketBase = PocketBase('https://$host');
      final service = SshServerUpdateService(
        _FakeSecureStorage(credentials),
        pocketBase,
      );

      // ignore: avoid_print
      print('Running the real update sequence against $host...');
      final result = await service.updateServer(instanceId: instanceId);

      // ignore: avoid_print
      print('exitCode=${result.exitCode}');
      // ignore: avoid_print
      print('--- stdout (last 2000 chars) ---');
      // ignore: avoid_print
      print(result.stdout.length > 2000
          ? result.stdout.substring(result.stdout.length - 2000)
          : result.stdout);
      if (result.stderr.isNotEmpty) {
        // ignore: avoid_print
        print('--- stderr ---');
        // ignore: avoid_print
        print(result.stderr);
      }

      // exitCode is the ONLY reliable success signal here (the shell
      // command is `... && docker compose up -d`, so a nonzero exit means
      // some step failed). Docker's own progress-line formatting is not
      // stable to assert on: which lines appear (build summaries,
      // "Container ... Started") depends on whether anything actually
      // changed since the last run (this command is correctly idempotent
      // -- a no-op run when nothing changed prints neither) and on
      // BuildKit's non-TTY rendering over SSH, both observed directly
      // across repeated real runs against a live box.
      expect(result.succeeded, isTrue,
          reason:
              'update command exited ${result.exitCode}:\n${result.stdout}\n${result.stderr}');
      expect(result.stdout, isNotEmpty);
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
