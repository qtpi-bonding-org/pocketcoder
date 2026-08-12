import 'package:flutter_aeroform/domain/models/provision_progress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_pro/application/walkthrough/walkthrough_cubit.dart';
import 'package:pocketcoder_pro/domain/deployment/walkthrough.dart';

void main() {
  final firstContent = WalkthroughContent(
    sourceCommit: 'a1b2c3d4',
    backend: ProvisionBackendKind.nixos,
    walkthroughs: [
      Walkthrough(
        id: 'nixos-configuration',
        briefs: [
          WalkthroughBrief(id: 'storage', sectionIds: ['vps-storage']),
          WalkthroughBrief(id: 'network', sectionIds: ['vps-network']),
        ],
      ),
      Walkthrough(
        id: 'nixos-bootstrap',
        briefs: [
          WalkthroughBrief(id: 'key', sectionIds: ['bootstrap-key']),
        ],
      ),
    ],
  );

  final changedContent = WalkthroughContent(
    sourceCommit: 'd4c3b2a1',
    backend: ProvisionBackendKind.standardLinux,
    walkthroughs: [
      Walkthrough(
        id: 'debian-bootstrap',
        briefs: [
          WalkthroughBrief(id: 'status', sectionIds: ['debian-status']),
        ],
      ),
    ],
  );

  test('moves through briefs and records completed progress', () {
    final cubit = WalkthroughCubit()..loadContent(firstContent);

    expect(cubit.state.currentBriefId, 'nixos-configuration/storage');

    cubit.nextBrief();
    expect(cubit.state.currentBriefId, 'nixos-configuration/network');
    expect(
      cubit.state.completedBriefIds,
      contains('nixos-configuration/storage'),
    );

    cubit.nextBrief();
    expect(cubit.state.currentBriefId, 'nixos-bootstrap/key');
    expect(
      cubit.state.completedBriefIds,
      containsAll([
        'nixos-configuration/storage',
        'nixos-configuration/network',
      ]),
    );

    cubit.nextBrief();
    expect(cubit.state.isComplete, isTrue);
    expect(
      cubit.state.completedBriefIds,
      contains('nixos-bootstrap/key'),
    );

    cubit.close();
  });

  test('same source content never resets reader-controlled progress', () {
    final cubit = WalkthroughCubit()..loadContent(firstContent);

    cubit.nextBrief();
    cubit.setCodeExpanded(true);
    cubit.loadContent(firstContent);

    expect(cubit.state.currentBriefId, 'nixos-configuration/network');
    expect(cubit.state.isCodeExpanded, isTrue);
    expect(
      cubit.state.completedBriefIds,
      contains('nixos-configuration/storage'),
    );

    cubit.close();
  });

  test('only a different source identity resets walkthrough progress', () {
    final cubit = WalkthroughCubit()..loadContent(firstContent);

    cubit.nextBrief();
    cubit.setCodeExpanded(true);
    cubit.loadContent(changedContent);

    expect(cubit.state.currentBriefId, 'debian-bootstrap/status');
    expect(cubit.state.isCodeExpanded, isFalse);
    expect(cubit.state.completedBriefIds, isEmpty);
    expect(cubit.state.isComplete, isFalse);

    cubit.close();
  });

  test('skip and resume retain the current brief and completion history', () {
    final cubit = WalkthroughCubit()..loadContent(firstContent);

    cubit.nextBrief();
    cubit.skip();
    cubit.nextBrief();

    expect(cubit.state.isSkipped, isTrue);
    expect(cubit.state.currentBriefId, 'nixos-configuration/network');

    cubit.resume();

    expect(cubit.state.isSkipped, isFalse);
    expect(cubit.state.currentBriefId, 'nixos-configuration/network');
    expect(
      cubit.state.completedBriefIds,
      contains('nixos-configuration/storage'),
    );

    cubit.close();
  });

  test('previous crosses a walkthrough boundary without altering completion',
      () {
    final cubit = WalkthroughCubit()..loadContent(firstContent);

    cubit.nextBrief();
    cubit.nextBrief();
    cubit.previousBrief();

    expect(cubit.state.currentBriefId, 'nixos-configuration/network');
    expect(
      cubit.state.completedBriefIds,
      containsAll([
        'nixos-configuration/storage',
        'nixos-configuration/network',
      ]),
    );

    cubit.close();
  });
}
