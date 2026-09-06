import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_deployment_auth_status.dart';

void main() {
  test('defines the shared deployment authentication status contract', () {
    expect(DeploymentAuthPhase.values, [
      DeploymentAuthPhase.waitingForCredentials,
      DeploymentAuthPhase.signingIn,
      DeploymentAuthPhase.authenticated,
      DeploymentAuthPhase.failed,
    ]);

    const snapshot = DeploymentAuthStatusSnapshot(
      instanceId: 'instance-1',
      phase: DeploymentAuthPhase.authenticated,
      error: null,
    );

    expect(snapshot.instanceId, 'instance-1');
    expect(snapshot.phase, DeploymentAuthPhase.authenticated);
    expect(snapshot.error, isNull);

    final status = _FakeDeploymentAuthStatus(snapshot);
    expect(status.current, same(snapshot));
    expect(status.changes, isA<Stream<void>>());
  });
}

class _FakeDeploymentAuthStatus implements IDeploymentAuthStatus {
  _FakeDeploymentAuthStatus(this._current);

  final DeploymentAuthStatusSnapshot _current;

  @override
  DeploymentAuthStatusSnapshot get current => _current;

  @override
  Stream<void> get changes => const Stream<void>.empty();
}
