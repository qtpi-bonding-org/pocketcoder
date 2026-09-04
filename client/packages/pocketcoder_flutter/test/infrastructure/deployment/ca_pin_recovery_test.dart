import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/domain/deployment/caddy_ca_pin.dart';
import 'package:pocketcoder_flutter/domain/os_control/i_root_ssh_command_runner.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_command.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_command_result.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/ca_pin_fetcher.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/ca_pin_mutex.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/ca_pin_recovery.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/caddy_ca_pin_store.dart';

class MockSshRunner extends Mock implements IRootSshCommandRunner {}

class MockCaPinWriter extends Mock implements CaPinWriter {}

class FakeCurrentDeploymentLookup implements CurrentDeploymentLookup {
  FakeCurrentDeploymentLookup(this.current);

  @override
  ({String instanceId, String host})? current;
}

void main() {
  late MockSshRunner sshRunner;
  late CaddyCaPinStore pinStore;
  late MockCaPinWriter pinningHttpClient;
  late CaPinFetcher fetcher;
  late FakeCurrentDeploymentLookup lookup;
  late CaPinRecovery recovery;

  setUpAll(() {
    registerFallbackValue(RootSshCommand.exportCaddyCaFingerprint);
  });

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    sshRunner = MockSshRunner();
    pinStore = CaddyCaPinStore(FlutterSecureStorage());
    pinningHttpClient = MockCaPinWriter();
    when(() => pinningHttpClient.updatePin(any())).thenReturn(null);
    fetcher = CaPinFetcher(
      sshCommandRunner: sshRunner,
      pinStore: pinStore,
      pinningHttpClient: pinningHttpClient,
      mutex: CaPinMutex(),
    );
    await pinStore.write(
      deploymentId: 'inst-1',
      pin: const CaddyCaPin(fingerprint: 'old', certificatePem: 'old-pem'),
    );
    lookup = FakeCurrentDeploymentLookup(
      (instanceId: 'inst-1', host: 'deploy.example'),
    );
    recovery = CaPinRecovery(caPinFetcher: fetcher, currentDeployment: lookup);
  });

  void stubSsh(String fingerprint, String pem) {
    when(() => sshRunner.run(
          instanceId: any(named: 'instanceId'),
          host: any(named: 'host'),
          command: RootSshCommand.exportCaddyCaFingerprint,
        )).thenAnswer((_) async => RootSshCommandResult(
          exitCode: 0,
          stdout:
              '{"fingerprint":"$fingerprint","certificatePemBase64":"${_b64(pem)}"}',
          stderr: '',
        ));
  }

  test(
      're-fetches and reports true when the request is for the current '
      "deployment's own host and the CA actually changed", () async {
    stubSsh('new', 'new-pem');

    final recovered = await recovery.recoverIfStale(
      requestUrl: Uri.parse('https://deploy.example/api/collections/chats'),
    );

    expect(recovered, isTrue);
    verify(() => pinningHttpClient.updatePin('new-pem')).called(1);
  });

  test(
      'does nothing for a request against an unrelated host -- must never '
      "SSH into the deployment over an OAuth relay or captive-portal "
      'failure', () async {
    final recovered = await recovery.recoverIfStale(
      requestUrl: Uri.parse('https://oauth.relay.pocketcoder.org/callback'),
    );

    expect(recovered, isFalse);
    verifyNever(() => sshRunner.run(
          instanceId: any(named: 'instanceId'),
          host: any(named: 'host'),
          command: any(named: 'command'),
        ));
  });

  test('does nothing when no deployment is currently known', () async {
    lookup.current = null;

    final recovered = await recovery.recoverIfStale(
      requestUrl: Uri.parse('https://deploy.example/api/health'),
    );

    expect(recovered, isFalse);
    verifyNever(() => sshRunner.run(
          instanceId: any(named: 'instanceId'),
          host: any(named: 'host'),
          command: any(named: 'command'),
        ));
  });

  test(
      'does nothing when nothing was ever pinned for this deployment yet '
      "-- that's fetchAndPin's job, not recovery's", () async {
    await pinStore.clear('inst-1');

    final recovered = await recovery.recoverIfStale(
      requestUrl: Uri.parse('https://deploy.example/api/health'),
    );

    expect(recovered, isFalse);
    verifyNever(() => sshRunner.run(
          instanceId: any(named: 'instanceId'),
          host: any(named: 'host'),
          command: any(named: 'command'),
        ));
  });

  test('does not re-attempt SSH again within the cooldown window', () async {
    stubSsh('new', 'new-pem');
    var callCount = 0;
    when(() => sshRunner.run(
          instanceId: any(named: 'instanceId'),
          host: any(named: 'host'),
          command: RootSshCommand.exportCaddyCaFingerprint,
        )).thenAnswer((_) async {
      callCount++;
      return RootSshCommandResult(
        exitCode: 0,
        stdout:
            '{"fingerprint":"new","certificatePemBase64":"${_b64('new-pem')}"}',
        stderr: '',
      );
    });
    final uri = Uri.parse('https://deploy.example/api/health');

    await recovery.recoverIfStale(requestUrl: uri);
    await recovery.recoverIfStale(requestUrl: uri);

    expect(callCount, 1);
  });
}

String _b64(String pem) => base64.encode(utf8.encode(pem));
