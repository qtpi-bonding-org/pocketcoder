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
import 'package:pocketcoder_flutter/infrastructure/deployment/caddy_ca_pin_store.dart';

class MockSshRunner extends Mock implements IRootSshCommandRunner {}

class MockCaPinWriter extends Mock implements CaPinWriter {}

void main() {
  late MockSshRunner sshRunner;
  late CaddyCaPinStore pinStore;
  late MockCaPinWriter pinningHttpClient;
  late CaPinFetcher fetcher;

  setUpAll(() {
    registerFallbackValue(RootSshCommand.exportCaddyCaFingerprint);
  });

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    sshRunner = MockSshRunner();
    pinStore = CaddyCaPinStore(FlutterSecureStorage());
    pinningHttpClient = MockCaPinWriter();
    fetcher = CaPinFetcher(
      sshCommandRunner: sshRunner,
      pinStore: pinStore,
      pinningHttpClient: pinningHttpClient,
      mutex: CaPinMutex(),
    );
  });

  String exportJson(String fingerprint, String pem) => jsonEncode({
        'fingerprint': fingerprint,
        'certificatePemBase64': base64.encode(utf8.encode(pem)),
      });

  test('fetches via SSH, writes to the durable store, and updates the pin',
      () async {
    when(() => sshRunner.run(
          instanceId: any(named: 'instanceId'),
          host: any(named: 'host'),
          command: RootSshCommand.exportCaddyCaFingerprint,
        )).thenAnswer((_) async => RootSshCommandResult(
          exitCode: 0,
          stdout: exportJson('abc123', '-----BEGIN CERTIFICATE-----...'),
          stderr: '',
        ));
    when(() => pinningHttpClient.updatePin(any())).thenReturn(null);

    await fetcher.fetchAndPin(
      instanceId: '999',
      host: '203.0.113.10',
      isCurrentAttemptStillLive: () async => true,
    );

    final stored = await pinStore.read(deploymentId: '999');
    expect(stored!.fingerprint, 'abc123');
    verify(() => pinningHttpClient.updatePin(stored.certificatePem)).called(1);
  });

  test('restores an existing pin and skips SSH', () async {
    await pinStore.write(
      deploymentId: '999',
      pin: const CaddyCaPin(fingerprint: 'already-pinned', certificatePem: 'x'),
    );
    when(() => pinningHttpClient.updatePin(any())).thenReturn(null);

    await fetcher.fetchAndPin(
      instanceId: '999',
      host: '203.0.113.10',
      isCurrentAttemptStillLive: () async => true,
    );

    verifyNever(() => sshRunner.run(
          instanceId: any(named: 'instanceId'),
          host: any(named: 'host'),
          command: any(named: 'command'),
        ));
    verify(() => pinningHttpClient.updatePin('x')).called(1);
  });

  test('writes when the attempt is still current', () async {
    when(() => sshRunner.run(
          instanceId: any(named: 'instanceId'),
          host: any(named: 'host'),
          command: RootSshCommand.exportCaddyCaFingerprint,
        )).thenAnswer((_) async => RootSshCommandResult(
          exitCode: 0,
          stdout: exportJson('abc123', 'pem'),
          stderr: '',
        ));
    when(() => pinningHttpClient.updatePin(any())).thenReturn(null);

    await fetcher.fetchAndPin(
      instanceId: '999',
      host: '203.0.113.10',
      isCurrentAttemptStillLive: () async => true,
    );

    expect(await pinStore.read(deploymentId: '999'), isNotNull);
  });

  test('discards the fetched pin when the attempt is no longer current',
      () async {
    when(() => sshRunner.run(
          instanceId: any(named: 'instanceId'),
          host: any(named: 'host'),
          command: RootSshCommand.exportCaddyCaFingerprint,
        )).thenAnswer((_) async => RootSshCommandResult(
          exitCode: 0,
          stdout: exportJson('abc123', 'pem'),
          stderr: '',
        ));

    await fetcher.fetchAndPin(
      instanceId: '999',
      host: '203.0.113.10',
      isCurrentAttemptStillLive: () async => false,
    );

    expect(await pinStore.read(deploymentId: '999'), isNull);
    verifyNever(() => pinningHttpClient.updatePin(any()));
  });

  test('does not throw on a non-zero SSH exit code', () async {
    when(() => sshRunner.run(
              instanceId: any(named: 'instanceId'),
              host: any(named: 'host'),
              command: RootSshCommand.exportCaddyCaFingerprint,
            ))
        .thenAnswer((_) async => const RootSshCommandResult(
            exitCode: 1, stdout: '', stderr: 'no such file'));

    await expectLater(
      fetcher.fetchAndPin(
        instanceId: '999',
        host: '203.0.113.10',
        isCurrentAttemptStillLive: () async => true,
      ),
      completes,
    );
  });

  test('serializes the write and prevents a double-write race', () async {
    var sshCallCount = 0;
    when(() => sshRunner.run(
          instanceId: any(named: 'instanceId'),
          host: any(named: 'host'),
          command: RootSshCommand.exportCaddyCaFingerprint,
        )).thenAnswer((_) async {
      sshCallCount++;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return RootSshCommandResult(
        exitCode: 0,
        stdout: exportJson('abc123', 'pem'),
        stderr: '',
      );
    });
    when(() => pinningHttpClient.updatePin(any())).thenReturn(null);

    await Future.wait([
      fetcher.fetchAndPin(
          instanceId: '999',
          host: '203.0.113.10',
          isCurrentAttemptStillLive: () async => true),
      fetcher.fetchAndPin(
          instanceId: '999',
          host: '203.0.113.10',
          isCurrentAttemptStillLive: () async => true),
    ]);

    final stored = await pinStore.read(deploymentId: '999');
    expect(stored!.fingerprint, 'abc123');
    expect(sshCallCount, 2);
    verify(() => pinningHttpClient.updatePin(any())).called(1);
  });

  group('forceRefetch', () {
    test(
        're-fetches over SSH even when a pin is already stored, and '
        'reports true when the fingerprint actually changed', () async {
      await pinStore.write(
        deploymentId: '999',
        pin: const CaddyCaPin(
            fingerprint: 'old-fingerprint', certificatePem: 'old-pem'),
      );
      when(() => sshRunner.run(
            instanceId: any(named: 'instanceId'),
            host: any(named: 'host'),
            command: RootSshCommand.exportCaddyCaFingerprint,
          )).thenAnswer((_) async => RootSshCommandResult(
            exitCode: 0,
            stdout: exportJson('new-fingerprint', 'new-pem'),
            stderr: '',
          ));
      when(() => pinningHttpClient.updatePin(any())).thenReturn(null);

      final changed = await fetcher.forceRefetch(
        instanceId: '999',
        host: '203.0.113.10',
      );

      expect(changed, isTrue);
      verify(() => sshRunner.run(
            instanceId: any(named: 'instanceId'),
            host: any(named: 'host'),
            command: RootSshCommand.exportCaddyCaFingerprint,
          )).called(1);
      final stored = await pinStore.read(deploymentId: '999');
      expect(stored!.fingerprint, 'new-fingerprint');
      verify(() => pinningHttpClient.updatePin('new-pem')).called(1);
    });

    test(
        'reports false when the freshly-fetched CA matches what was '
        'already stored -- the pin was not the actual problem', () async {
      await pinStore.write(
        deploymentId: '999',
        pin: const CaddyCaPin(fingerprint: 'same', certificatePem: 'same-pem'),
      );
      when(() => sshRunner.run(
            instanceId: any(named: 'instanceId'),
            host: any(named: 'host'),
            command: RootSshCommand.exportCaddyCaFingerprint,
          )).thenAnswer((_) async => RootSshCommandResult(
            exitCode: 0,
            stdout: exportJson('same', 'same-pem'),
            stderr: '',
          ));
      when(() => pinningHttpClient.updatePin(any())).thenReturn(null);

      final changed = await fetcher.forceRefetch(
        instanceId: '999',
        host: '203.0.113.10',
      );

      expect(changed, isFalse);
    });

    test('reports false when the SSH fetch itself fails', () async {
      when(() => sshRunner.run(
                instanceId: any(named: 'instanceId'),
                host: any(named: 'host'),
                command: RootSshCommand.exportCaddyCaFingerprint,
              ))
          .thenAnswer((_) async => const RootSshCommandResult(
              exitCode: 1, stdout: '', stderr: 'boom'));

      final changed = await fetcher.forceRefetch(
        instanceId: '999',
        host: '203.0.113.10',
      );

      expect(changed, isFalse);
    });
  });
}
