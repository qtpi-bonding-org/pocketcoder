import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/os_control/i_root_ssh_key_provider.dart';
import 'package:pocketcoder_flutter/domain/pocketcoder_update/pocketcoder_update_exception.dart';
import 'package:pocketcoder_flutter/domain/release/i_server_release_status_service.dart';
import 'package:pocketcoder_flutter/domain/release/server_release_status.dart';
import 'package:pocketcoder_flutter/infrastructure/pocketcoder_update/ssh_pocketcoder_update_service.dart';

class _KeyProvider implements IRootSshKeyProvider {
  const _KeyProvider(this.privateKey);

  final String? privateKey;

  @override
  Future<String?> readRootSshPrivateKey({required String instanceId}) async =>
      privateKey;
}

class _ReleaseStatusService implements IServerReleaseStatusService {
  static final snapshot = ServerReleaseStatusSnapshot(
    status: ServerReleaseStatus.current,
    currentVersion: '1.0.0',
    currentDataVersion: 1,
    currentReleaseDigest: 'a' * 64,
    checkedAt: null,
  );

  @override
  Stream<bool> get authenticationChanges => const Stream.empty();

  @override
  bool get isAuthenticated => true;

  @override
  Future<ServerReleaseStatusSnapshot> inspect() async => snapshot;
}

SshPocketCoderUpdateService _service(String? privateKey) =>
    SshPocketCoderUpdateService(
      rootSshKeyProvider: _KeyProvider(privateKey),
      pocketBase: PocketBase('https://example.com'),
      releaseStatusService: _ReleaseStatusService(),
    );

void main() {
  test('delegates release inspection', () async {
    expect(await _service(null).inspect(), _ReleaseStatusService.snapshot);
  });

  test('refuses update without stored root credentials', () async {
    await expectLater(
      _service(null).updatePocketCoder(instanceId: 'instance'),
      throwsA(
        isA<PocketCoderUpdateException>().having(
          (error) => error.message,
          'message',
          contains('No stored root credentials'),
        ),
      ),
    );
  });

  test('refuses an invalid root SSH key before connecting', () async {
    await expectLater(
      _service('not-a-private-key').updatePocketCoder(instanceId: 'instance'),
      throwsA(
        isA<PocketCoderUpdateException>().having(
          (error) => error.message,
          'message',
          contains('could not be parsed'),
        ),
      ),
    );
  });
}
