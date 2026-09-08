import 'package:flutter_test/flutter_test.dart';
import 'package:nav_snapshot/nav_snapshot.dart';
import 'package:pocketcoder_flutter/application/boot/boot_route.dart';
import 'package:pocketcoder_flutter/domain/auth/auth_session_coordinator.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_deployment_auth_status.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_instance_existence_resolver.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_server_readiness_check.dart';

import 'policy_fixture.dart';

void main() {
  group('readiness', () {
    test(
        'resolving waits',
        () => expect(fixture(status: ServerReadinessStatus.resolving).decide(),
            const RouteWait<BootRoute>()));
    test(
        'not provisioned waits out the boot floor on first landing',
        () => expect(
            fixture(
                    status: ServerReadinessStatus.notProvisioned,
                    bootFloorElapsed: false)
                .decide(),
            const RouteWait<BootRoute>()));
    test(
        'not provisioned skips the floor once we have left the boot screen',
        () => expect(
            fixture(
                    status: ServerReadinessStatus.notProvisioned,
                    bootFloorElapsed: false,
                    hasLeftBootScreen: true)
                .decide(),
            const RouteGo<BootRoute>(BootRoute.onboarding)));
    test(
        'not provisioned goes to onboarding once the floor elapses',
        () => expect(
            fixture(status: ServerReadinessStatus.notProvisioned).decide(),
            const RouteGo<BootRoute>(BootRoute.onboarding)));
    test(
        'provisioning goes to deployment progress',
        () => expect(
            fixture(status: ServerReadinessStatus.provisioning).decide(),
            const RouteGo<BootRoute>(BootRoute.deploymentProgress)));
    test(
        'unrecoverable resume goes to deployment progress',
        () => expect(
            fixture(status: ServerReadinessStatus.resumeUnrecoverable).decide(),
            const RouteGo<BootRoute>(BootRoute.deploymentProgress)));
  });

  group('deploy-phase suppression', () {
    test(
        'does not yank the user back once they have moved on',
        () => expect(
            fixture(
                    status: ServerReadinessStatus.provisioning,
                    lastDeployProgressRoute: BootRoute.deploymentProgress,
                    currentRoute: BootRoute.onboarding)
                .decide(),
            const RouteStay<BootRoute>()));
    test(
        'still pushes while the user is where we left them',
        () => expect(
            fixture(
                    status: ServerReadinessStatus.provisioning,
                    lastDeployProgressRoute: BootRoute.deploymentProgress,
                    currentRoute: BootRoute.deploymentProgress)
                .decide(),
            const RouteGo<BootRoute>(BootRoute.deploymentProgress)));
  });

  test(
      'waits until the restore completes',
      () => expect(
          fixture(status: ServerReadinessStatus.ready, restoreSettled: false)
              .decide(),
          const RouteWait<BootRoute>()));

  group('deployment auth', () {
    const waiting = DeploymentAuthPhase.waitingForCredentials;
    test(
        'waiting for credentials on this instance holds',
        () => expect(
            fixture(
                    instanceId: 'i1',
                    deploymentAuth: const DeploymentAuthStatusSnapshot(
                        instanceId: 'i1', phase: waiting))
                .decide(),
            const RouteWait<BootRoute>()));
    test(
        'signing in on this instance holds',
        () => expect(
            fixture(
                    instanceId: 'i1',
                    deploymentAuth: const DeploymentAuthStatusSnapshot(
                        instanceId: 'i1', phase: DeploymentAuthPhase.signingIn))
                .decide(),
            const RouteWait<BootRoute>()));
    test(
        'failed does not hold',
        () => expect(
            fixture(
                    sessionState: AuthSessionState.signedOut,
                    existence: InstanceExistenceResult.exists,
                    deploymentAuth: const DeploymentAuthStatusSnapshot(
                        instanceId: 'i1', phase: DeploymentAuthPhase.failed))
                .decide(),
            const RouteGo<BootRoute>(BootRoute.login)));
    test(
        'authenticated does not hold',
        () => expect(
            fixture(
                    sessionState: AuthSessionState.signedIn,
                    harnessConnected: true,
                    deploymentAuth: const DeploymentAuthStatusSnapshot(
                        instanceId: 'i1',
                        phase: DeploymentAuthPhase.authenticated))
                .decide(),
            const RouteGo<BootRoute>(BootRoute.chats)));
    test(
        'a different instance does not hold',
        () => expect(
            fixture(
                    sessionState: AuthSessionState.signedIn,
                    harnessConnected: true,
                    deploymentAuth: const DeploymentAuthStatusSnapshot(
                        instanceId: 'other',
                        phase: DeploymentAuthPhase.signingIn))
                .decide(),
            const RouteGo<BootRoute>(BootRoute.chats)));
  });

  group('signed out', () {
    test(
        'self-host with no resolver goes straight to login',
        () => expect(
            fixture(
                    sessionState: AuthSessionState.signedOut,
                    hasExistenceResolver: false)
                .decide(),
            const RouteGo<BootRoute>(BootRoute.login)));
    test(
        'existing instance goes to login',
        () => expect(
            fixture(
                    sessionState: AuthSessionState.signedOut,
                    existence: InstanceExistenceResult.exists)
                .decide(),
            const RouteGo<BootRoute>(BootRoute.login)));
    test(
        'gone instance goes to instanceGone',
        () => expect(
            fixture(
                    sessionState: AuthSessionState.signedOut,
                    existence: InstanceExistenceResult.gone)
                .decide(),
            const RouteGo<BootRoute>(BootRoute.instanceGone)));
    test(
        'unknown while still retrying waits',
        () => expect(
            fixture(
                    sessionState: AuthSessionState.signedOut,
                    existenceLoading: true)
                .decide(),
            const RouteWait<BootRoute>()));
    test(
        'unknown after the retries are spent is unverifiable',
        () => expect(
            fixture(
                    sessionState: AuthSessionState.signedOut,
                    existence: InstanceExistenceResult.unknown,
                    existenceExhausted: true)
                .decide(),
            const RouteGo<BootRoute>(BootRoute.instanceUnverifiable)));
    test(
        'a failed existence check is unverifiable, same as exhausted unknown',
        () => expect(
            fixture(
                    sessionState: AuthSessionState.signedOut,
                    existenceFailed: true)
                .decide(),
            const RouteGo<BootRoute>(BootRoute.instanceUnverifiable)));
  });

  group('temporarily unavailable', () {
    test(
        'is signed out when the latch was never confirmed',
        () => expect(
            fixture(
                    sessionState: AuthSessionState.temporarilyUnavailable,
                    existence: InstanceExistenceResult.exists)
                .decide(),
            const RouteGo<BootRoute>(BootRoute.login)));
    test(
        'is lenient when the latch matches',
        () => expect(
            fixture(
                    sessionState: AuthSessionState.temporarilyUnavailable,
                    confirmedLatchKey: ('i1', 'https://server', 'user'),
                    harnessConnected: true)
                .decide(),
            const RouteGo<BootRoute>(BootRoute.chats)));
  });

  group('signed in', () {
    test(
        'without a harness goes to harness auth',
        () => expect(fixture(harnessConnected: false).decide(),
            const RouteGo<BootRoute>(BootRoute.harnessAuth)));
    test(
        'with a harness goes to chats',
        () => expect(fixture(harnessConnected: true).decide(),
            const RouteGo<BootRoute>(BootRoute.chats)));
    test(
        'waits while the harness check is in flight',
        () => expect(fixture(harnessLoading: true).decide(),
            const RouteWait<BootRoute>()));
    test('a confirmed latch already on chats stays without reading harness',
        () {
      final policy = fixture(
          confirmedLatchKey: ('i1', 'https://server', 'user'),
          currentRoute: BootRoute.chats,
          harnessConnected: true);
      final context = EvaluationContext();
      final decision = EvaluationContext.track(context, policy.decide);
      expect(decision, const RouteStay<BootRoute>());
      expect(context.reads, isNot(contains(policy.inputs.harness)));
    });
  });

  test('repeating an evaluation yields the same decision', () {
    final policy = fixture(harnessConnected: true);
    expect(policy.decide(), policy.decide());
  });

  group('onDecisionApplied', () {
    test('confirms the latch on chats even when no navigation occurred', () {
      final policy = fixture(harnessConnected: true);
      policy.decide();
      policy.onDecisionApplied(BootRoute.chats, navigated: false);
      expect(policy.confirmedLatchKey, ('i1', 'https://server', 'user'));
    });
    test('records the deploy-progress push without navigation', () {
      final policy = fixture(status: ServerReadinessStatus.provisioning);
      policy.onDecisionApplied(BootRoute.deploymentProgress, navigated: false);
      expect(policy.lastDeployProgressRoute, BootRoute.deploymentProgress);
    });
    test('onboarding clears the deploy-progress guard', () {
      final policy = fixture(
          status: ServerReadinessStatus.notProvisioned,
          lastDeployProgressRoute: BootRoute.deploymentProgress);
      policy.onDecisionApplied(BootRoute.onboarding, navigated: true);
      expect(policy.lastDeployProgressRoute, isNull);
    });
    test('hasLeftBootScreen is set only when navigation actually happened', () {
      final policy = fixture(status: ServerReadinessStatus.notProvisioned);
      policy.onDecisionApplied(BootRoute.onboarding, navigated: false);
      expect(policy.hasLeftBootScreen, isFalse);
      policy.onDecisionApplied(BootRoute.onboarding, navigated: true);
      expect(policy.hasLeftBootScreen, isTrue);
    });
  });
}
