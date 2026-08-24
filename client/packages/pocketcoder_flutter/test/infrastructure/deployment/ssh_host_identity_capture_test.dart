import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_aeroform/domain/models/instance_credentials.dart';
import 'package:flutter_aeroform/domain/storage/i_secure_storage.dart';
import 'package:pocketcoder_pro/domain/deployment/deploy_operation_key.dart';
import 'package:pocketcoder_pro/domain/deployment/readiness_update.dart';
import 'package:pocketcoder_pro/domain/deployment/server_status_document.dart';
import 'package:pocketcoder_pro/infrastructure/deployment/ssh_host_identity_capture.dart';

class MockSecureStorage extends Mock implements ISecureStorage {}

void main() {
  late MockSecureStorage secureStorage;

  setUpAll(() {
    registerFallbackValue(const InstanceCredentials(
      instanceId: 'fallback',
      rootSshPrivateKey: 'fallback',
      rootSshHostKeyType: null,
      rootSshHostKeyFingerprint: null,
    ));
  });
  setUp(() => secureStorage = MockSecureStorage());

  ReadinessUpdate updateWithHostKey(ServerSshHostKey? hostKey) => ReadinessUpdate(
        operationKey: DeployOperationKey.composeUp,
        pollingAttempt: 1,
        statusTransportAuthenticated: true,
        statusDocument: ServerStatusDocument(
          schema: 3,
          runId: 'run-1',
          operation: 'compose_up',
          updatedAt: DateTime.utc(2026, 1, 1),
          raw: const {},
          errorCode: null,
          errorMessage: null,
          detail: null,
          attempt: 1,
          maxAttempts: 1,
          sshHostKey: hostKey,
        ),
      );

  test('does nothing when the update carries no ssh host key', () async {
    await captureSshHostIdentity(
      secureStorage: secureStorage,
      instanceId: '999',
      update: updateWithHostKey(null),
    );
    verifyNever(() => secureStorage.storeInstanceCredentials(any()));
  });

  test('does nothing when there are no stored credentials to attach to',
      () async {
    when(() => secureStorage.getInstanceCredentials('999'))
        .thenAnswer((_) async => null);
    await captureSshHostIdentity(
      secureStorage: secureStorage,
      instanceId: '999',
      update: updateWithHostKey(const ServerSshHostKey(
        type: 'ed25519',
        fingerprint: 'SHA256:abc',
      )),
    );
    verifyNever(() => secureStorage.storeInstanceCredentials(any()));
  });

  test('does nothing when a fingerprint is already pinned (never '
      'overwrites)', () async {
    when(() => secureStorage.getInstanceCredentials('999')).thenAnswer(
        (_) async => const InstanceCredentials(
              instanceId: '999',
              rootSshPrivateKey: 'fake-private-key',
              rootSshHostKeyType: 'ed25519',
              rootSshHostKeyFingerprint: 'SHA256:already-pinned',
            ));
    await captureSshHostIdentity(
      secureStorage: secureStorage,
      instanceId: '999',
      update: updateWithHostKey(const ServerSshHostKey(
        type: 'ed25519',
        fingerprint: 'SHA256:new',
      )),
    );
    verifyNever(() => secureStorage.storeInstanceCredentials(any()));
  });

  test('stores the host key when credentials exist with no fingerprint '
      'pinned yet', () async {
    const credentials = InstanceCredentials(
      instanceId: '999',
      rootSshPrivateKey: 'fake-private-key',
      rootSshHostKeyType: null,
      rootSshHostKeyFingerprint: null,
    );
    when(() => secureStorage.getInstanceCredentials('999'))
        .thenAnswer((_) async => credentials);
    when(() => secureStorage.storeInstanceCredentials(any()))
        .thenAnswer((_) async {});

    await captureSshHostIdentity(
      secureStorage: secureStorage,
      instanceId: '999',
      update: updateWithHostKey(const ServerSshHostKey(
        type: 'ed25519',
        fingerprint: 'SHA256:new',
      )),
    );

    final captured = verify(
      () => secureStorage.storeInstanceCredentials(captureAny()),
    ).captured.single as InstanceCredentials;
    expect(captured.rootSshHostKeyType, 'ed25519');
    expect(captured.rootSshHostKeyFingerprint, 'SHA256:new');
  });
}
