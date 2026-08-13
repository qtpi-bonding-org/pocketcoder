import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/domain/release/server_release_status.dart';
import 'package:pocketcoder_flutter/application/pocketcoder_update/pocketcoder_update_cubit.dart';
import 'package:pocketcoder_flutter/domain/pocketcoder_update/i_pocketcoder_update_service.dart';
import 'package:pocketcoder_flutter/domain/pocketcoder_update/pocketcoder_update_result.dart';

const _digest =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

class _FakeUpdateService implements IPocketCoderUpdateService {
  int updates = 0;

  @override
  Future<ServerReleaseStatusSnapshot> inspect() async =>
      ServerReleaseStatusSnapshot(
        status: ServerReleaseStatus.updateAvailable,
        currentVersion: '1.0.0',
        currentDataVersion: 1,
        currentReleaseDigest: _digest,
        checkedAt: DateTime.utc(2026, 8, 12),
        availableVersion: '1.1.0',
        availableDataVersion: 2,
      );

  @override
  Future<PocketCoderUpdateResult> updatePocketCoder(
      {required String instanceId}) async {
    updates += 1;
    return const PocketCoderUpdateResult(
        exitCode: 0, stdout: 'updated', stderr: '');
  }
}

void main() {
  test('loads preview and keeps upgrade user initiated', () async {
    final service = _FakeUpdateService();
    final cubit = PocketCoderUpdateCubit(service);

    await cubit.load();

    expect(cubit.state.preview?.availableVersion, '1.1.0');
    expect(cubit.state.preview?.crossesDataVersion, isTrue);
    expect(service.updates, 0);
    await cubit.close();
  });

  test('records explicit data-boundary confirmation before update', () async {
    final service = _FakeUpdateService();
    final cubit = PocketCoderUpdateCubit(service);
    await cubit.load();

    cubit.confirmUpgrade();
    await cubit.update('instance-1');

    expect(cubit.state.upgradeConfirmed, isTrue);
    expect(cubit.state.result?.succeeded, isTrue);
    expect(service.updates, 1);
    await cubit.close();
  });
}
