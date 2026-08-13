// Live test for the public root-SSH PocketCoder updater against a real,
// already-deployed user-owned server. It needs no simulator or running app.
//
// Gated behind POCKETCODER_UPDATE_LIVE_TEST=1. Set
// POCKETCODER_UPDATE_TEST_HOST to the server domain or IP and
// POCKETCODER_UPDATE_TEST_KEY_PATH to its root private-key PEM file, and
// POCKETCODER_UPDATE_TEST_HOST_KEY_FINGERPRINT to the pinned OpenSSH MD5
// fingerprint of its Ed25519 host key.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/os_control/i_root_ssh_credentials_provider.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_credentials.dart';
import 'package:pocketcoder_flutter/infrastructure/core/pocketcoder_api_client.dart';
import 'package:pocketcoder_flutter/infrastructure/os_control/ssh_root_command_runner.dart';
import 'package:pocketcoder_flutter/infrastructure/pocketcoder_update/ssh_pocketcoder_update_service.dart';
import 'package:pocketcoder_flutter/infrastructure/release/server_release_status_service.dart';

class _FakeRootSshCredentialsProvider implements IRootSshCredentialsProvider {
  const _FakeRootSshCredentialsProvider(this.credentials);

  final RootSshCredentials credentials;

  @override
  Future<RootSshCredentials?> readRootSshCredentials({
    required String instanceId,
  }) async =>
      credentials;
}

void main() {
  test(
    'runs the real public PocketCoder update sequence against a live server',
    () async {
      if (Platform.environment['POCKETCODER_UPDATE_LIVE_TEST'] != '1') return;

      final host = Platform.environment['POCKETCODER_UPDATE_TEST_HOST'];
      final keyPath = Platform.environment['POCKETCODER_UPDATE_TEST_KEY_PATH'];
      final hostKeyFingerprint =
          Platform.environment['POCKETCODER_UPDATE_TEST_HOST_KEY_FINGERPRINT'];
      if (host == null ||
          host.isEmpty ||
          keyPath == null ||
          keyPath.isEmpty ||
          hostKeyFingerprint == null ||
          hostKeyFingerprint.isEmpty) {
        fail(
          'POCKETCODER_UPDATE_TEST_HOST and '
          'POCKETCODER_UPDATE_TEST_KEY_PATH and '
          'POCKETCODER_UPDATE_TEST_HOST_KEY_FINGERPRINT must be set.',
        );
      }

      final privateKey = await File(keyPath).readAsString();
      final pocketBase = PocketBase('https://$host');
      final commandRunner = SshRootCommandRunner(
        credentialsProvider: _FakeRootSshCredentialsProvider(
          RootSshCredentials(
            privateKeyPem: privateKey,
            hostKeyType: 'ssh-ed25519',
            hostKeyFingerprint: hostKeyFingerprint,
          ),
        ),
      );
      final service = SshPocketCoderUpdateService(
        rootSshCommandRunner: commandRunner,
        pocketBase: pocketBase,
        releaseStatusService: ServerReleaseStatusService(
          pocketBase,
          PocketCoderApiClient.fromPocketBase(pocketBase),
        ),
      );
      final result = await service.updatePocketCoder(
        instanceId: 'live-test-instance',
      );

      expect(
        result.succeeded,
        isTrue,
        reason: 'update command exited ${result.exitCode}:\n'
            '${result.stdout}\n${result.stderr}',
      );
      expect(result.stdout, isNotEmpty);
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
