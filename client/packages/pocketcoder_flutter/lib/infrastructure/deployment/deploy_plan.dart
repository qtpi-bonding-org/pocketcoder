import 'package:flutter_aeroform/domain/deployment/idempotent_operation.dart';
import 'package:flutter_aeroform/domain/storage/i_secure_storage.dart';
import 'package:pocketcoder_flutter/domain/deployment/readiness_update.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/ca_pin_fetcher.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/deployment_readiness_poll_operation.dart';

/// The deploy track's plan -- deliberately one element. Kept as a
/// list-returning function (not a bare operation constructor call) so it
/// matches the provisioning track's plan-function shape and stays
/// extensible if a future revision splits deploy into more operations.
List<IdempotentOperation> planDeployOperations({
  required Stream<ReadinessUpdate> Function({required String hostname})
      readinessSource,
  required ISecureStorage secureStorage,
  required CaPinFetcher caPinFetcher,
  required Future<bool> Function() isCurrentAttemptStillLive,
}) {
  return [
    DeploymentReadinessPollOperation(
      readinessSource: readinessSource,
      secureStorage: secureStorage,
      caPinFetcher: caPinFetcher,
      isCurrentAttemptStillLive: isCurrentAttemptStillLive,
    ),
  ];
}
