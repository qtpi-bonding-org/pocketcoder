import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/domain/release/server_release_status.dart';

const _digestA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _digestB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

void main() {
  test('parses authenticated update metadata and data boundary', () {
    final snapshot = ServerReleaseStatusSnapshot.fromStatus({
      'current': {
        'releaseDigest': _digestA,
        'serverVersion': '1.0.0',
        'dataVersion': 1,
      },
      'metadataStatus': {
        'status': 'update-available',
        'checkedAt': '2026-08-12T20:00:00Z',
        'availableReleaseDigest': _digestB,
        'availableVersion': '1.1.0',
        'availableDataVersion': 2,
        'downloadBytes': 123,
        'requiredDiskBytes': 456,
        'normalRollbackAvailableAfterSuccess': false,
      },
    });

    expect(snapshot.status, ServerReleaseStatus.updateAvailable);
    expect(snapshot.currentVersion, '1.0.0');
    expect(snapshot.availableVersion, '1.1.0');
    expect(snapshot.crossesDataVersion, isTrue);
    expect(snapshot.needsAttention, isTrue);
    expect(snapshot.normalRollbackAvailableAfterSuccess, isFalse);
  });

  test('parses bounded critical warning metadata', () {
    final snapshot = ServerReleaseStatusSnapshot.fromStatus({
      'current': {
        'releaseDigest': _digestA,
        'serverVersion': '1.0.0',
        'dataVersion': 1,
      },
      'metadataStatus': {
        'status': 'critical-release-warning',
        'reasonCode': 'health-regression',
        'summary': 'This release can lose task output.',
      },
    });

    expect(snapshot.status, ServerReleaseStatus.criticalReleaseWarning);
    expect(snapshot.reasonCode, 'health-regression');
    expect(snapshot.summary, 'This release can lose task output.');
  });

  test('parses deployment/app/server contract versions from compatibility',
      () {
    final snapshot = ServerReleaseStatusSnapshot.fromStatus({
      'current': {
        'releaseDigest': _digestA,
        'serverVersion': '1.0.0',
        'dataVersion': 1,
        'deploymentContractVersion': 3,
        'compatibility': {
          'app': {'contractVersion': 2},
          'server': {'apiVersion': 1},
        },
      },
      'metadataStatus': {'status': 'current'},
    });

    expect(snapshot.deploymentContractVersion, 3);
    expect(snapshot.appContractVersion, 2);
    expect(snapshot.serverApiVersion, 1);
  });

  test('leaves contract versions null when compatibility is absent', () {
    final snapshot = ServerReleaseStatusSnapshot.fromStatus({
      'current': {
        'releaseDigest': _digestA,
        'serverVersion': '1.0.0',
        'dataVersion': 1,
      },
      'metadataStatus': {'status': 'current'},
    });

    expect(snapshot.deploymentContractVersion, isNull);
    expect(snapshot.appContractVersion, isNull);
    expect(snapshot.serverApiVersion, isNull);
  });
}
