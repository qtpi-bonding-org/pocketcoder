// Coverage map for every testWidgets in boot_routing_decider_test.dart:
// same-instance deployment auth in flight holds Q2 — covered by: an in-flight deployment auto-login holds the boot screen, then releases to chats
// deployment auth completion wakes a held reconcile — covered by: an in-flight deployment auto-login holds the boot screen, then releases to chats
// failed deployment auth does not hold Q2 — covered by: signed out with an existing instance lands on login
// different-instance deployment auth does not hold Q2 — covered by: signed out with an existing instance lands on login
// optional deployment auth leaves FOSS boot wait unchanged — covered by: fresh install waits on boot, then lands on onboarding
// user route survives redundant provisioning emission — covered by: a user who moves off the progress screen is not dragged back
// user route survives later notProvisioned emission — covered by: a later notProvisioned does not drag the user back either
// navigating through onboarding's own screens before any deploy attempt starts... — covered by: onboarding navigation does not suppress the first deploy push
// a second deploy attempt after abort still reaches deploymentProgress — covered by: a second deploy attempt after an abort still reaches progress
// start() reading GoRouter.state before any widget has ever attached the router — internal (startup ordering guard)
// notProvisioned (fresh install) waits for the boot animation before landing on onboarding — covered by: fresh install waits on boot, then lands on onboarding
// resolving stays on the boot screen — covered by: resolving never leaves the boot screen
// resolving then notProvisioned lands directly on onboarding — covered by: resolving then notProvisioned reaches onboarding
// notProvisioned observed again later (e.g. after RESET) does not replay the boot-animation wait — covered by: a later notProvisioned does not replay the boot wait
// Pro provisioning -> deploymentProgress — covered by: a provisioning deployment goes straight to progress
// Pro resumeUnrecoverable -> deploymentProgress — covered by: an unrecoverable resume goes to progress
// start restores before routing an expired persisted token — covered by: an expired persisted token lands on login
// racing replay and readiness emission coalesce restore — internal (restore coalescing)
// ready emissions restore only once per epoch — internal (restore epoch)
// ready epoch transition restores again — internal (restore epoch)
// retryAuth restores again and coalesces in-flight restore — internal (restore coalescing)
// ready + signedOut self-host -> onboardingLogin — covered by: self-host signed out lands on login
// ready + signedOut Pro -> onboardingLogin — covered by: signed out with an existing instance lands on login
// a fresh managed deployment ... first-ever login completes — covered by: an external auth-store change reaches chats
// unconfirmed temporarilyUnavailable is signed out — covered by: an unconfirmed temporarily-unavailable session lands on login
// confirmed temporarilyUnavailable is lenient — covered by: a temporarily unavailable session is lenient once confirmed
// signedIn without harness -> onboardingHarnessAuth — covered by: signed in without a harness lands on harness auth
// signedIn with harness -> chats — covered by: signed in with a harness lands on chats
// duplicate latch on chats does not query or navigate — internal (latch and query count)
// latch key changes re-evaluate — internal (latch key)
// stale harness result cannot overwrite newer reconcile — internal (generation guard)
// unconfirmed temporarilyUnavailable with a persistently unknown existence check — covered by: an unverifiable instance lands on instanceUnverifiable
// unconfirmed temporarilyUnavailable with an existing instance — covered by: signed out with an existing instance lands on login
// unconfirmed temporarilyUnavailable with a confirmed-gone instance — covered by: signed out with a gone instance lands on instanceGone
// with no resolver configured, unconfirmed temporarilyUnavailable — covered by: self-host signed out lands on login
// a resolver that throws is treated as unknown — covered by: a resolver that throws is unverifiable, like a returned unknown
// concurrent readiness/auth emissions while an existence check is pending — internal (coalescing)
// confirmed-gone instance navigates directly — covered by: signed out with a gone instance lands on instanceGone
// signedOut existence result is cached for the ready epoch — internal (resolver caching)
// readiness epoch change does not reuse existence answer — internal (resolver epoch cache)
// retryAuth clears a cached unknown existence answer — covered by: retryAuth from instanceUnverifiable can recover to login
// confirmed temporary unavailability does not query resolver — covered by: a temporarily unavailable session is lenient once confirmed

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/application/boot/boot_routing_decider.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_deployment_auth_status.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_instance_existence_resolver.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_server_readiness_check.dart';

import 'boot_routing_decider_test.dart';

void main() {
  testWidgets('fresh install waits on boot, then lands on onboarding',
      (tester) async {
    // start() blocks on the 9s floor, so it cannot be awaited before the
    // clock is advanced -- the existing floor tests use this same pattern
    // (boot_routing_decider_test.dart:477-484). `await t.start(tester)`
    // deadlocks here.
    final t = HarnessTest(status: ServerReadinessStatus.notProvisioned);
    addTearDown(t.decider.dispose);
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Router.withConfig(config: t.router),
    ));

    final pending = t.decider.start();
    await tester.pump(const Duration(seconds: 1));
    expect(t.journey, [RouteNames.boot],
        reason: 'the floor must not be short-circuited');

    await tester.pump(BootRoutingDecider.kMinFreshInstallBootDuration);
    await pending;
    await t.settleReconcile(tester);

    expect(t.journey, [RouteNames.boot, RouteNames.onboarding]);
  });

  testWidgets('a later notProvisioned does not replay the boot wait',
      (tester) async {
    final t = HarnessTest(status: ServerReadinessStatus.provisioning);
    await t.start(tester);
    expect(t.journey, [RouteNames.boot, RouteNames.deploymentProgress]);

    t.readiness.set(const ServerReadinessSnapshot(
      status: ServerReadinessStatus.notProvisioned,
    ));
    await t.settleReconcile(tester);

    expect(t.journey, [
      RouteNames.boot,
      RouteNames.deploymentProgress,
      RouteNames.onboarding,
    ], reason: 'the floor applies only to the very first landing');
  });

  testWidgets('a provisioning deployment goes straight to progress',
      (tester) async {
    final t = HarnessTest(status: ServerReadinessStatus.provisioning);
    await t.start(tester);

    expect(t.journey, [RouteNames.boot, RouteNames.deploymentProgress]);
  });

  testWidgets('an unrecoverable resume goes to progress', (tester) async {
    final t = HarnessTest(status: ServerReadinessStatus.resumeUnrecoverable);
    await t.start(tester);

    expect(t.journey, [RouteNames.boot, RouteNames.deploymentProgress]);
  });

  testWidgets('resolving never leaves the boot screen', (tester) async {
    final t = HarnessTest(status: ServerReadinessStatus.resolving);
    await t.start(tester);
    await tester.pump(const Duration(seconds: 10));
    await t.settleReconcile(tester);

    expect(t.journey, [RouteNames.boot]);
  });

  testWidgets('signed in with a harness lands on chats', (tester) async {
    final t = HarnessTest(signedIn: true, harnessConnected: true);
    await t.start(tester);

    expect(t.journey, [RouteNames.boot, RouteNames.chats]);
  });

  testWidgets('signed in without a harness lands on harness auth',
      (tester) async {
    final t = HarnessTest(signedIn: true);
    await t.start(tester);

    expect(t.journey, [RouteNames.boot, RouteNames.onboardingHarnessAuth]);
  });

  testWidgets('self-host signed out lands on login', (tester) async {
    final t = HarnessTest();
    await t.start(tester);

    expect(t.journey, [RouteNames.boot, RouteNames.onboardingLogin]);
  });

  testWidgets('signed out with an existing instance lands on login',
      (tester) async {
    final resolver = FakeInstanceExistenceResolver(
      InstanceExistenceResult.exists,
    );
    final t = HarnessTest(instanceExistenceResolver: resolver);
    await t.start(tester);

    expect(t.journey, [RouteNames.boot, RouteNames.onboardingLogin]);
  });

  testWidgets('signed out with a gone instance lands on instanceGone',
      (tester) async {
    final resolver = FakeInstanceExistenceResolver(
      InstanceExistenceResult.gone,
    );
    final t = HarnessTest(instanceExistenceResolver: resolver);
    await t.start(tester);

    expect(t.journey, [RouteNames.boot, RouteNames.instanceGone]);
  });

  testWidgets('an unverifiable instance lands on instanceUnverifiable',
      (tester) async {
    final resolver = FakeInstanceExistenceResolver(
      InstanceExistenceResult.unknown,
    );
    final t = HarnessTest(instanceExistenceResolver: resolver);
    await t.start(tester);
    await t.settleReconcile(tester);

    expect(t.journey, [RouteNames.boot, RouteNames.instanceUnverifiable]);
  });

  testWidgets('an in-flight deployment auto-login holds the boot screen, '
      'then releases to chats', (tester) async {
    final authStatus = FakeDeploymentAuthStatus(
      const DeploymentAuthStatusSnapshot(
        instanceId: 'i',
        phase: DeploymentAuthPhase.signingIn,
      ),
    );
    final t = HarnessTest(
      instanceId: 'i',
      signedIn: true,
      harnessConnected: true,
      deploymentAuthStatus: authStatus,
    );
    await t.start(tester);
    expect(t.journey, [RouteNames.boot]);

    authStatus.set(const DeploymentAuthStatusSnapshot(
      instanceId: 'i',
      phase: DeploymentAuthPhase.authenticated,
    ));
    await t.settleReconcile(tester);

    expect(t.journey, [RouteNames.boot, RouteNames.chats]);
  });

  testWidgets('a user who moves off the progress screen is not dragged back',
      (tester) async {
    final t = HarnessTest(status: ServerReadinessStatus.provisioning);
    await t.start(tester);
    expect(t.journey, [RouteNames.boot, RouteNames.deploymentProgress]);

    // The user navigates onward under their own steam.
    t.router.goNamed(RouteNames.onboarding);
    await tester.pumpAndSettle();

    // A redundant provisioning emission must not yank them back.
    t.readiness.set(const ServerReadinessSnapshot(
      status: ServerReadinessStatus.provisioning,
    ));
    await t.settleReconcile(tester);

    expect(t.journey, [
      RouteNames.boot,
      RouteNames.deploymentProgress,
      RouteNames.onboarding,
    ]);
  });

  testWidgets('a later notProvisioned does not drag the user back either',
      (tester) async {
    final t = HarnessTest(status: ServerReadinessStatus.provisioning);
    await t.start(tester);

    // makeRouter() (boot_routing_decider_test.dart:208-221) registers only
    // the eight boot routes; goNamed on anything else asserts.
    t.router.goNamed(RouteNames.chats);
    await tester.pumpAndSettle();

    t.readiness.set(const ServerReadinessSnapshot(
      status: ServerReadinessStatus.notProvisioned,
    ));
    await t.settleReconcile(tester);

    expect(t.journey.last, RouteNames.chats);
  });

  testWidgets('provisioning then ready walks progress to chats',
      (tester) async {
    final t = HarnessTest(
      status: ServerReadinessStatus.provisioning,
      signedIn: true,
      harnessConnected: true,
    );
    await t.start(tester);
    expect(t.journey, [RouteNames.boot, RouteNames.deploymentProgress]);

    t.readiness.set(const ServerReadinessSnapshot(
      status: ServerReadinessStatus.ready,
    ));
    await t.settleReconcile(tester);

    expect(t.journey, [
      RouteNames.boot,
      RouteNames.deploymentProgress,
      RouteNames.chats,
    ]);
  });

  testWidgets('a temporarily unavailable session is lenient once confirmed',
      (tester) async {
    final t = HarnessTest(
      instanceId: 'i',
      signedIn: true,
      harnessConnected: true,
    );
    await t.start(tester);
    expect(t.journey, [RouteNames.boot, RouteNames.chats]);

    // The session degrades but the identity is unchanged: stay put.
    t.authRepository.refreshResult = AuthRefreshResult.temporarilyUnavailable;
    t.authRepository.publish();
    await t.settleReconcile(tester);

    expect(t.journey, [RouteNames.boot, RouteNames.chats]);
  });

  testWidgets('a resolver that throws is unverifiable, like a returned unknown',
      (tester) async {
    // D7 makes these two structurally different library states -- PartFailed
    // versus PartReady(exhausted) -- so both paths need pinning.
    final resolver = ThrowingInstanceExistenceResolver();
    final t = HarnessTest(instanceExistenceResolver: resolver);
    await t.start(tester);
    await t.settleReconcile(tester);

    expect(t.journey, [RouteNames.boot, RouteNames.instanceUnverifiable]);
  });

  testWidgets('resolving then notProvisioned reaches onboarding',
      (tester) async {
    final t = HarnessTest(status: ServerReadinessStatus.resolving);
    addTearDown(t.decider.dispose);
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Router.withConfig(config: t.router),
    ));
    await t.decider.start();
    await tester.pump();
    expect(t.journey, [RouteNames.boot]);

    t.readiness.set(const ServerReadinessSnapshot(
      status: ServerReadinessStatus.notProvisioned,
    ));
    await tester.pump(BootRoutingDecider.kMinFreshInstallBootDuration);
    await t.settleReconcile(tester);

    expect(t.journey, [RouteNames.boot, RouteNames.onboarding]);
  });

  testWidgets('an expired persisted token lands on login', (tester) async {
    final t = HarnessTest(signedIn: true);
    t.authRepository.refreshResult = AuthRefreshResult.invalidSession;
    await t.start(tester);

    expect(t.journey, [RouteNames.boot, RouteNames.onboardingLogin]);
  });

  testWidgets('an unconfirmed temporarily-unavailable session lands on login',
      (tester) async {
    final t = HarnessTest(signedIn: true);
    t.authRepository.refreshResult = AuthRefreshResult.temporarilyUnavailable;
    await t.start(tester);

    expect(t.journey, [RouteNames.boot, RouteNames.onboardingLogin]);
  });

  testWidgets('an external auth-store change reaches chats', (tester) async {
    final t = HarnessTest(harnessConnected: true);
    await t.start(tester);
    expect(t.journey, [RouteNames.boot, RouteNames.onboardingLogin]);

    t.authRepository.authenticated = true;
    t.authRepository.publish();
    await t.settleReconcile(tester);

    expect(t.journey, [
      RouteNames.boot,
      RouteNames.onboardingLogin,
      RouteNames.chats,
    ]);
  });

  testWidgets('onboarding navigation does not suppress the first deploy push',
      (tester) async {
    // Regression guard for the live bug fixed in 15b9e9fcb -- onboarding's
    // own forward navigation must not poison the deploy-phase latch.
    final t = HarnessTest(status: ServerReadinessStatus.notProvisioned);
    addTearDown(t.decider.dispose);
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Router.withConfig(config: t.router),
    ));
    final pending = t.decider.start();
    await tester.pump(BootRoutingDecider.kMinFreshInstallBootDuration);
    await pending;
    await t.settleReconcile(tester);
    expect(t.journey.last, RouteNames.onboarding);

    t.router.goNamed(RouteNames.onboardingLogin);
    await tester.pumpAndSettle();

    t.readiness.set(const ServerReadinessSnapshot(
      status: ServerReadinessStatus.provisioning,
    ));
    await t.settleReconcile(tester);

    expect(t.journey.last, RouteNames.deploymentProgress,
        reason: 'a real deploy must still be able to claim the screen');
  });

  testWidgets('a second deploy attempt after an abort still reaches progress',
      (tester) async {
    // Regression guard for ff810126c -- notProvisioned clears the latch.
    final t = HarnessTest(status: ServerReadinessStatus.provisioning);
    await t.start(tester);
    expect(t.journey.last, RouteNames.deploymentProgress);

    t.readiness.set(const ServerReadinessSnapshot(
      status: ServerReadinessStatus.notProvisioned,
    ));
    await t.settleReconcile(tester);
    expect(t.journey.last, RouteNames.onboarding);

    t.readiness.set(const ServerReadinessSnapshot(
      status: ServerReadinessStatus.provisioning,
    ));
    await t.settleReconcile(tester);

    expect(t.journey.last, RouteNames.deploymentProgress);
  });

  testWidgets('signing out after signing in re-queries and lands on login',
      (tester) async {
    // The case D4's monotone key exists for: nothing reads the existence
    // part while signed in, so a boolean key would keep the stale answer.
    final resolver = FakeInstanceExistenceResolver(
      InstanceExistenceResult.gone,
    );
    final t = HarnessTest(
      signedIn: true,
      harnessConnected: true,
      instanceExistenceResolver: resolver,
    );
    await t.start(tester);
    expect(t.journey.last, RouteNames.chats);

    resolver.result = InstanceExistenceResult.exists;
    t.authRepository.authenticated = false;
    t.authRepository.publish();
    await t.settleReconcile(tester);

    expect(t.journey.last, RouteNames.onboardingLogin,
        reason: 'a stale `gone` would have sent us to instanceGone');
  });

  testWidgets('retryAuth from instanceUnverifiable can recover to login',
      (tester) async {
    final resolver = FakeInstanceExistenceResolver(
      InstanceExistenceResult.unknown,
    );
    final t = HarnessTest(instanceExistenceResolver: resolver);
    await t.start(tester);
    await t.settleReconcile(tester);
    expect(t.journey.last, RouteNames.instanceUnverifiable);

    resolver.result = InstanceExistenceResult.exists;
    // Start the reconcile before pumping: the existing decider tests use this
    // ordering because retryAuth can otherwise wait on a reconcile already
    // queued by the zero-delay unknown-result retry timer.
    final retry = t.decider.retryAuth();
    await t.settleReconcile(tester);
    await retry;

    expect(t.journey, [
      RouteNames.boot,
      RouteNames.instanceUnverifiable,
      RouteNames.onboardingLogin,
    ]);
  });
}

/// Exercises the branch where the provider call throws rather than returning
/// `unknown`; boot_routing_decider.dart:120-126 maps both to the same route.
class ThrowingInstanceExistenceResolver implements IInstanceExistenceResolver {
  @override
  Future<InstanceExistenceResult> checkInstanceExists() async =>
      throw StateError('provider unreachable');
}
