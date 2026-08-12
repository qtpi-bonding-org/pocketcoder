import 'package:flutter_aeroform/domain/models/provision_progress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_pro/application/walkthrough/walkthrough_cubit.dart';
import 'package:pocketcoder_pro/domain/deployment/provisioning_walkthrough.dart';

void main() {
  final firstContent = ProvisioningWalkthroughContent(
    sourceCommit: 'a1b2c3d4',
    backend: ProvisionBackendKind.nixos,
    walkthroughs: [
      ProvisioningWalkthrough(
        id: 'nixos-configuration',
        briefings: [
          ProvisioningBriefing(id: 'storage', sectionIds: ['vps-storage']),
          ProvisioningBriefing(id: 'network', sectionIds: ['vps-network']),
        ],
      ),
      ProvisioningWalkthrough(
        id: 'nixos-bootstrap',
        briefings: [
          ProvisioningBriefing(id: 'key', sectionIds: ['bootstrap-key']),
        ],
      ),
    ],
  );

  final changedContent = ProvisioningWalkthroughContent(
    sourceCommit: 'd4c3b2a1',
    backend: ProvisionBackendKind.standardLinux,
    walkthroughs: [
      ProvisioningWalkthrough(
        id: 'debian-bootstrap',
        briefings: [
          ProvisioningBriefing(id: 'status', sectionIds: ['debian-status']),
        ],
      ),
    ],
  );

  test('moves through briefings and records completed progress', () {
    final cubit = WalkthroughCubit()..loadContent(firstContent);

    expect(cubit.state.currentBriefingId, 'nixos-configuration/storage');

    cubit.nextBriefing();
    expect(cubit.state.currentBriefingId, 'nixos-configuration/network');
    expect(
      cubit.state.completedBriefingIds,
      contains('nixos-configuration/storage'),
    );

    cubit.nextBriefing();
    expect(cubit.state.currentBriefingId, 'nixos-bootstrap/key');
    expect(
      cubit.state.completedBriefingIds,
      containsAll([
        'nixos-configuration/storage',
        'nixos-configuration/network',
      ]),
    );

    cubit.nextBriefing();
    expect(cubit.state.isComplete, isTrue);
    expect(
      cubit.state.completedBriefingIds,
      contains('nixos-bootstrap/key'),
    );

    cubit.close();
  });

  test('same source content never resets reader-controlled progress', () {
    final cubit = WalkthroughCubit()..loadContent(firstContent);

    cubit.nextBriefing();
    cubit.setCodeExpanded(true);
    cubit.loadContent(firstContent);

    expect(cubit.state.currentBriefingId, 'nixos-configuration/network');
    expect(cubit.state.isCodeExpanded, isTrue);
    expect(
      cubit.state.completedBriefingIds,
      contains('nixos-configuration/storage'),
    );

    cubit.close();
  });

  test('only a different source identity resets walkthrough progress', () {
    final cubit = WalkthroughCubit()..loadContent(firstContent);

    cubit.nextBriefing();
    cubit.setCodeExpanded(true);
    cubit.loadContent(changedContent);

    expect(cubit.state.currentBriefingId, 'debian-bootstrap/status');
    expect(cubit.state.isCodeExpanded, isFalse);
    expect(cubit.state.completedBriefingIds, isEmpty);
    expect(cubit.state.isComplete, isFalse);

    cubit.close();
  });

  test('skip and resume retain the current briefing and completion history',
      () {
    final cubit = WalkthroughCubit()..loadContent(firstContent);

    cubit.nextBriefing();
    cubit.skip();
    cubit.nextBriefing();

    expect(cubit.state.isSkipped, isTrue);
    expect(cubit.state.currentBriefingId, 'nixos-configuration/network');

    cubit.resume();

    expect(cubit.state.isSkipped, isFalse);
    expect(cubit.state.currentBriefingId, 'nixos-configuration/network');
    expect(
      cubit.state.completedBriefingIds,
      contains('nixos-configuration/storage'),
    );

    cubit.close();
  });

  test('previous crosses a walkthrough boundary without altering completion',
      () {
    final cubit = WalkthroughCubit()..loadContent(firstContent);

    cubit.nextBriefing();
    cubit.nextBriefing();
    cubit.previousBriefing();

    expect(cubit.state.currentBriefingId, 'nixos-configuration/network');
    expect(
      cubit.state.completedBriefingIds,
      containsAll([
        'nixos-configuration/storage',
        'nixos-configuration/network',
      ]),
    );

    cubit.close();
  });
}
