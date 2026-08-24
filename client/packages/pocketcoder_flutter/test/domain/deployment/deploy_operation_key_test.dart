import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/domain/deployment/deploy_operation_key.dart';

void main() {
  test('maps every known wire value to its operation key', () {
    expect(
      DeployOperationKeyX.fromWireName('configuring_operating_system'),
      DeployOperationKey.configuringOperatingSystem,
    );
    expect(
      DeployOperationKeyX.fromWireName('fetching_release'),
      DeployOperationKey.fetchingRelease,
    );
    expect(
      DeployOperationKeyX.fromWireName('loading_images'),
      DeployOperationKey.loadingImages,
    );
    expect(
      DeployOperationKeyX.fromWireName('compose_up'),
      DeployOperationKey.composeUp,
    );
    expect(
      DeployOperationKeyX.fromWireName('bootstrap_complete'),
      DeployOperationKey.bootstrapComplete,
    );
  });

  test('returns null for an unknown or missing wire value, not a default', () {
    expect(DeployOperationKeyX.fromWireName('some_future_phase'), isNull);
    expect(DeployOperationKeyX.fromWireName(null), isNull);
    expect(DeployOperationKeyX.fromWireName(''), isNull);
  });

  test('declaration order is the canonical operation sequence', () {
    expect(DeployOperationKey.values, [
      DeployOperationKey.waitingForConnection,
      DeployOperationKey.configuringOperatingSystem,
      DeployOperationKey.fetchingRelease,
      DeployOperationKey.loadingImages,
      DeployOperationKey.composeUp,
      DeployOperationKey.bootstrapComplete,
      DeployOperationKey.ready,
    ]);
  });
}
