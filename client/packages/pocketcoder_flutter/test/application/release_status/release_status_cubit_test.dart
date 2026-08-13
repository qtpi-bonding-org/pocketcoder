import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/application/release_status/release_status_cubit.dart';
import 'package:pocketcoder_flutter/domain/release/i_server_release_status_service.dart';
import 'package:pocketcoder_flutter/domain/release/server_release_status.dart';

const _digest =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

class _FakeReleaseStatusService implements IServerReleaseStatusService {
  _FakeReleaseStatusService(this.snapshot);

  final ServerReleaseStatusSnapshot snapshot;
  final auth = StreamController<bool>.broadcast();
  bool signedIn = true;
  int inspections = 0;

  @override
  Stream<bool> get authenticationChanges => auth.stream;

  @override
  bool get isAuthenticated => signedIn;

  @override
  Future<ServerReleaseStatusSnapshot> inspect() async {
    inspections += 1;
    return snapshot;
  }
}

ServerReleaseStatusSnapshot _snapshot(ServerReleaseStatus status) =>
    ServerReleaseStatusSnapshot(
      status: status,
      currentVersion: '1.0.0',
      currentDataVersion: 1,
      currentReleaseDigest: _digest,
      checkedAt: DateTime.utc(2026, 8, 12),
      availableVersion: '1.1.0',
      availableDataVersion: 1,
    );

void main() {
  test('loads on start and dismisses only an ordinary update notice', () async {
    final service = _FakeReleaseStatusService(
      _snapshot(ServerReleaseStatus.updateAvailable),
    );
    final cubit = ReleaseStatusCubit(service)..start();
    await Future<void>.delayed(Duration.zero);

    expect(service.inspections, 1);
    expect(cubit.state.shouldShowNotice, isTrue);

    cubit.dismissUpdateNotice();
    expect(cubit.state.shouldShowNotice, isFalse);
    await cubit.close();
    await service.auth.close();
  });

  test('critical release warning cannot be dismissed', () async {
    final service = _FakeReleaseStatusService(
      _snapshot(ServerReleaseStatus.criticalReleaseWarning),
    );
    final cubit = ReleaseStatusCubit(service)..start();
    await Future<void>.delayed(Duration.zero);

    cubit.dismissUpdateNotice();

    expect(cubit.state.shouldShowNotice, isTrue);
    await cubit.close();
    await service.auth.close();
  });
}
