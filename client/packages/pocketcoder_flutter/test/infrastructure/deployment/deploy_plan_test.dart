import 'package:flutter_aeroform/domain/storage/i_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/domain/os_control/i_root_ssh_command_runner.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_command.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_command_result.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/ca_pin_fetcher.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/ca_pin_mutex.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/caddy_ca_pin_store.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/deploy_plan.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MockSecureStorage extends Mock implements ISecureStorage {}

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

void main() {
  test('the deploy track is exactly one operation, keyed '
      'deploy_readiness_poll', () {
    final operations = planDeployOperations(
      readinessSource: ({required hostname}) => const Stream.empty(),
      secureStorage: MockSecureStorage(),
      caPinFetcher: CaPinFetcher(
        sshCommandRunner: _NoopSshRunner(),
        pinStore: CaddyCaPinStore(FlutterSecureStorage()),
        pinningHttpClient: _NoopPinningClient(),
        mutex: CaPinMutex(),
      ),
      isCurrentAttemptStillLive: () async => true,
    );
    expect(operations.length, 1);
    expect(operations.single.key, 'deploy_readiness_poll');
  });
}
