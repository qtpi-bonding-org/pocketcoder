import 'dart:async';

import 'package:flutter_aeroform/domain/deployment/cancellation_token.dart';
import 'package:flutter_aeroform/domain/deployment/context_key.dart';
import 'package:flutter_aeroform/domain/deployment/recovery_outcome.dart';
import 'package:flutter_aeroform/domain/models/instance.dart';
import 'package:flutter_aeroform/domain/storage/i_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/domain/deployment/deploy_context_keys.dart';
import 'package:pocketcoder_flutter/domain/deployment/deploy_operation_key.dart';
import 'package:pocketcoder_flutter/domain/deployment/readiness_update.dart';
import 'package:pocketcoder_flutter/domain/deployment/server_status_document.dart';
import 'package:pocketcoder_flutter/domain/os_control/i_root_ssh_command_runner.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_command.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_command_result.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/ca_pin_fetcher.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/ca_pin_mutex.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/caddy_ca_pin_store.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/deployment_readiness_poll_operation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MockSecureStorage extends Mock implements ISecureStorage {}

class FakeReadinessSource {
  FakeReadinessSource(this.updates);
  final List<ReadinessUpdate> updates;

  Stream<ReadinessUpdate> monitor({required String hostname}) =>
      Stream.fromIterable(updates);
}

ReadinessUpdate _update(DeployOperationKey key, {bool terminalError = false}) =>
    ReadinessUpdate(
      operationKey: key,
      pollingAttempt: 1,
      statusTransportAuthenticated: true,
      statusDocument: ServerStatusDocument(
        schema: 3,
        runId: 'run-1',
        operation: key.name,
        updatedAt: DateTime.utc(2026, 1, 1),
        raw: const {},
        errorCode: terminalError ? 'DEPLOY_FAILED' : null,
        errorMessage: terminalError ? 'deploy failed' : null,
        detail: null,
        attempt: terminalError ? 3 : 1,
        maxAttempts: 3,
        sshHostKey: null,
      ),
    );

Instance _instance() => Instance(
      id: '999',
      label: 'provisioned-attempt-1',
      ipAddress: '203.0.113.10',
      status: InstanceStatus.running,
      created: DateTime.utc(2026, 1, 1),
      region: 'us-east',
      planType: 'g6-standard-2',
      provider: 'linode',
    );

class _NoopSshRunner implements IRootSshCommandRunner {
  @override
  Future<RootSshCommandResult> run({
    required String instanceId,
    required String host,
    required RootSshCommand command,
    dynamic stdin,
    String? shellEnvPrefix,
  }) async =>
      RootSshCommandResult(exitCode: 1, stdout: '', stderr: 'noop');
}

class _NoopPinningClient implements CaPinWriter {
  @override
  void updatePin(String certificatePem) {}
}

CaPinFetcher _fetcher() => CaPinFetcher(
      sshCommandRunner: _NoopSshRunner(),
      pinStore: CaddyCaPinStore(FlutterSecureStorage()),
      pinningHttpClient: _NoopPinningClient(),
      mutex: CaPinMutex(),
    );

void main() {
  late MockSecureStorage secureStorage;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    secureStorage = MockSecureStorage();
    when(() => secureStorage.getInstanceCredentials(any()))
        .thenAnswer((_) async => null);
  });

  DeploymentReadinessPollOperation makeOperation(
    Stream<ReadinessUpdate> Function({required String hostname}) source,
  ) => DeploymentReadinessPollOperation(
        readinessSource: source,
        secureStorage: secureStorage,
        caPinFetcher: _fetcher(),
        isCurrentAttemptStillLive: () async => true,
      );

  test('key and resultKey are correct', () {
    final op = makeOperation(FakeReadinessSource([]).monitor);
    expect(op.key, 'deploy_readiness_poll');
    expect(op.resultKey, deployReadyKey);
  });

  test('returns true when the stream reaches ready', () async {
    final op = makeOperation(FakeReadinessSource([
      _update(DeployOperationKey.configuringOperatingSystem),
      _update(DeployOperationKey.composeUp),
      _update(DeployOperationKey.ready),
    ]).monitor);
    final context = OperationContext()..set(instanceContextKey, _instance());
    expect(await op.run(context, CancellationToken()), isTrue);
  });

  test('throws when the stream ends on a terminal error', () async {
    final op = makeOperation(FakeReadinessSource([
      _update(DeployOperationKey.composeUp, terminalError: true),
    ]).monitor);
    final context = OperationContext()..set(instanceContextKey, _instance());
    expect(() => op.run(context, CancellationToken()), throwsA(isA<StateError>()));
  });

  test('throws when the stream ends with no terminal signal', () async {
    final op = makeOperation(FakeReadinessSource([
      _update(DeployOperationKey.composeUp),
    ]).monitor);
    final context = OperationContext()..set(instanceContextKey, _instance());
    expect(() => op.run(context, CancellationToken()), throwsA(isA<Exception>()));
  });

  test('checks the cancellation token per update and stops early', () async {
    final cancel = CancellationToken();
    final controller = StreamController<ReadinessUpdate>();
    Stream<ReadinessUpdate> source({required String hostname}) => controller.stream;
    final op = makeOperation(source);
    final context = OperationContext()..set(instanceContextKey, _instance());
    final future = op.run(context, cancel);
    controller.add(_update(DeployOperationKey.configuringOperatingSystem));
    await Future<void>.delayed(Duration.zero);
    cancel.cancel();
    controller.add(_update(DeployOperationKey.composeUp));
    await expectLater(future, throwsA(isA<StateError>()));
    await controller.close();
  });

  test('recover() is always Absent', () async {
    final op = makeOperation(FakeReadinessSource([]).monitor);
    final outcome = await op.recover(OperationContext(), CancellationToken());
    expect(outcome, isA<Absent<bool>>());
  });
}
