import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/domain/deployment/certificate_bundle.dart';
import 'package:pocketcoder_flutter/domain/deployment/certificate_recovery_result.dart';
import 'package:pocketcoder_flutter/domain/os_control/i_root_ssh_command_runner.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_command.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_command_result.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_exception.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/certificate_bundle_store.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/certificate_recovery_service.dart';

const _hostname = '66-228-35-248.sslip.io';

class _FakeRunner implements IRootSshCommandRunner {
  _FakeRunner({this.result, this.error});

  RootSshCommandResult? result;
  Object? error;
  RootSshCommand? lastCommand;
  Uint8List? lastStdin;

  @override
  Future<RootSshCommandResult> run({
    required String instanceId,
    required String host,
    required RootSshCommand command,
    Uint8List? stdin,
    String? shellEnvPrefix,
  }) async {
    lastCommand = command;
    lastStdin = stdin;
    if (error case final error?) throw error;
    return result ?? const RootSshCommandResult(exitCode: 0, stdout: '', stderr: '');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  CertificateBundleStore store() =>
      CertificateBundleStore(const FlutterSecureStorage());

  group('cache', () {
    test('stores the bundle the SSH export returns', () async {
      final runner = _FakeRunner(
        result: RootSshCommandResult(
          exitCode: 0,
          stdout: jsonEncode({
            'hostname': _hostname,
            'issuer': 'acme-v02.api.letsencrypt.org-directory',
            'certificatePemBase64': base64Encode(utf8.encode('CERT')),
            'privateKeyPemBase64': base64Encode(utf8.encode('KEY')),
          }),
          stderr: '',
        ),
      );
      final bundleStore = store();
      final service = CertificateRecoveryService(ssh: runner, store: bundleStore);

      final result = await service.cache(
        deploymentId: 'instance-1',
        host: _hostname,
      );

      expect(result.succeeded, isTrue);
      expect(runner.lastCommand, RootSshCommand.exportCaddyCertificate);
      final cached =
          await bundleStore.read(deploymentId: 'instance-1', hostname: _hostname);
      expect(cached?.certificatePem, 'CERT');
    });

    test('reports sshFailed instead of throwing on a non-zero exit', () async {
      final runner = _FakeRunner(
        result: const RootSshCommandResult(
          exitCode: 1,
          stdout: '',
          stderr: 'no certificate on disk',
        ),
      );
      final service = CertificateRecoveryService(ssh: runner, store: store());

      final result = await service.cache(
        deploymentId: 'instance-1',
        host: _hostname,
      );

      expect(result.outcome, CertificateRecoveryOutcome.sshFailed);
      expect(result.reason, isNotNull);
    });

    test('reports malformedBundle instead of throwing on bad JSON', () async {
      final runner = _FakeRunner(
        result: const RootSshCommandResult(
          exitCode: 0,
          stdout: 'not json',
          stderr: '',
        ),
      );
      final service = CertificateRecoveryService(ssh: runner, store: store());

      final result = await service.cache(
        deploymentId: 'instance-1',
        host: _hostname,
      );

      expect(result.outcome, CertificateRecoveryOutcome.malformedBundle);
    });

    test('reports sshFailed instead of throwing when the transport throws',
        () async {
      final runner = _FakeRunner(error: const RootSshException('closed'));
      final service = CertificateRecoveryService(ssh: runner, store: store());

      final result = await service.cache(
        deploymentId: 'instance-1',
        host: _hostname,
      );

      expect(result.outcome, CertificateRecoveryOutcome.sshFailed);
    });
  });

  group('restore', () {
    test('reports noBundleAvailable without attempting SSH', () async {
      final runner = _FakeRunner();
      final service = CertificateRecoveryService(ssh: runner, store: store());

      final result = await service.restore(
        deploymentId: 'instance-1',
        host: _hostname,
        hostname: _hostname,
      );

      expect(result.outcome, CertificateRecoveryOutcome.noBundleAvailable);
      expect(runner.lastCommand, isNull);
    });

    test('sends the cached bundle over SSH and reports success', () async {
      final bundleStore = store();
      await bundleStore.write(
        deploymentId: 'instance-1',
        bundle: const CertificateBundle(
          hostname: _hostname,
          certificatePem: 'CERT',
          privateKeyPem: 'KEY',
        ),
      );
      final runner = _FakeRunner();
      final service =
          CertificateRecoveryService(ssh: runner, store: bundleStore);

      final result = await service.restore(
        deploymentId: 'instance-1',
        host: _hostname,
        hostname: _hostname,
      );

      expect(result.succeeded, isTrue);
      expect(runner.lastCommand, RootSshCommand.restoreCaddyCertificate);
      expect(runner.lastStdin, isNotNull);
    });

    test('reports sshFailed instead of throwing on a non-zero exit', () async {
      final bundleStore = store();
      await bundleStore.write(
        deploymentId: 'instance-1',
        bundle: const CertificateBundle(
          hostname: _hostname,
          certificatePem: 'CERT',
          privateKeyPem: 'KEY',
        ),
      );
      final runner = _FakeRunner(
        result: const RootSshCommandResult(
          exitCode: 1,
          stdout: '',
          stderr: 'key/certificate mismatch',
        ),
      );
      final service =
          CertificateRecoveryService(ssh: runner, store: bundleStore);

      final result = await service.restore(
        deploymentId: 'instance-1',
        host: _hostname,
        hostname: _hostname,
      );

      expect(result.outcome, CertificateRecoveryOutcome.sshFailed);
    });
  });
}
