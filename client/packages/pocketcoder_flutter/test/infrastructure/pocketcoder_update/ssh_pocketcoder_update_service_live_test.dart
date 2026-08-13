// Live test for the public root-SSH PocketCoder updater against a real,
// already-deployed user-owned server. It needs no simulator or running app.
//
// Gated behind POCKETCODER_UPDATE_LIVE_TEST=1. Set
// POCKETCODER_UPDATE_TEST_HOST to the server domain or IP and
// POCKETCODER_UPDATE_TEST_KEY_PATH to its root private-key PEM file.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/os_control/i_root_ssh_key_provider.dart';
import 'package:pocketcoder_flutter/infrastructure/pocketcoder_update/ssh_pocketcoder_update_service.dart';
import 'package:pocketcoder_flutter/infrastructure/release/server_release_status_service.dart';

class _FakeRootSshKeyProvider implements IRootSshKeyProvider {
  const _FakeRootSshKeyProvider(this.privateKey);

  final String privateKey;

  @override
  Future<String?> readRootSshPrivateKey({required String instanceId}) async =>
      privateKey;
}

void main() {
  test(
    'runs the real public PocketCoder update sequence against a live server',
    () async {
      if (Platform.environment['POCKETCODER_UPDATE_LIVE_TEST'] != '1') return;

      final host = Platform.environment['POCKETCODER_UPDATE_TEST_HOST'];
      final keyPath = Platform.environment['POCKETCODER_UPDATE_TEST_KEY_PATH'];
      if (host == null || host.isEmpty || keyPath == null || keyPath.isEmpty) {
        fail(
          'POCKETCODER_UPDATE_TEST_HOST and '
          'POCKETCODER_UPDATE_TEST_KEY_PATH must be set.',
        );
      }

      final privateKey = await File(keyPath).readAsString();
      final pocketBase = PocketBase('https://$host');
      final service = SshPocketCoderUpdateService(
        rootSshKeyProvider: _FakeRootSshKeyProvider(privateKey),
        pocketBase: pocketBase,
        releaseStatusService: ServerReleaseStatusService(pocketBase),
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
