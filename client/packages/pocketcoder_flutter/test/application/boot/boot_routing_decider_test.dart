import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/application/boot/boot_routing_decider.dart';
import 'package:pocketcoder_flutter/domain/auth/auth_session_coordinator.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_instance_existence_resolver.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_server_readiness_check.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/i_harness_auth_repository.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/harness_auth_models.dart';
import 'package:pocketcoder_flutter/domain/models/credential_selection.dart';
import 'package:pocketcoder_flutter/domain/models/harness_oauth_account.dart';

class FakeReadiness implements IServerReadinessCheck {
  FakeReadiness(this._snapshot);
  ServerReadinessSnapshot _snapshot;
  final changes = StreamController<ServerReadinessSnapshot>.broadcast();
  @override
  ServerReadinessSnapshot get current => _snapshot;
  @override
  Stream<ServerReadinessSnapshot> get readinessChanges => changes.stream;
  void set(ServerReadinessSnapshot value) {
    _snapshot = value;
    changes.add(value);
  }

  @override
  Future<void> initialize() async {}
  @override
  Future<void> retry() async {}
}

class FakeAuthRepository implements IAuthRepository {
  bool authenticated;
  AuthRefreshResult refreshResult;
  String? userId = 'user';
  String? baseUrl = 'https://server';
  int refreshCalls = 0;
  Future<AuthRefreshResult>? refreshOverride;
  final changes = StreamController<void>.broadcast();
  FakeAuthRepository(
      {this.authenticated = false,
      this.refreshResult = AuthRefreshResult.refreshed});
  void publish() => changes.add(null);
  @override
  Stream<bool> get connectionStatus => const Stream.empty();
  @override
  Stream<void> get authChanges => changes.stream;
  @override
  bool get isAuthenticated => authenticated;
  @override
  String? get currentUserId => userId;
  @override
  String? get currentUserEmail => null;
  @override
  String? get currentUserRole => null;
  @override
  String? get currentBaseUrl => baseUrl;
  @override
  Future<AuthRefreshResult> refreshToken() async {
    refreshCalls++;
    if (refreshOverride != null) return refreshOverride!;
    return refreshResult;
  }

  @override
  Future<bool> login(String email, String password) async => true;
  @override
  Future<void> logout() async {
    authenticated = false;
  }

  @override
  Future<void> clearSession() async {
    authenticated = false;
  }

  @override
  Future<void> verifyServerCompatibility() async {}
  @override
  Future<void> updateBaseUrl(String url) async {
    baseUrl = url;
  }

  @override
  Future<void> persistBaseUrl(String url) async {
    baseUrl = url;
  }

  @override
  Future<String?> getSavedBaseUrl() async => baseUrl;
}

class FakeHarness implements IHarnessAuthRepository {
  bool connected;
  int calls = 0;
  Future<bool>? resultOverride;
  bool overrideOnce = false;
  FakeHarness({this.connected = false});
  @override
  Future<bool> hasEffectiveHarnessConnection() async {
    calls++;
    if (resultOverride != null) {
      final result = resultOverride!;
      if (overrideOnce) {
        resultOverride = null;
      }
      return result;
    }
    return connected;
  }

  @override
  Stream<List<HarnessOauthAccount>> watchHarnessOAuthAccounts() =>
      const Stream.empty();
  @override
  Future<List<HarnessOauthAccount>> fetchHarnessOAuthAccounts() =>
      Future.value(const []);
  @override
  Stream<List<CredentialSelection>> watchCredentialSelections() =>
      const Stream.empty();
  @override
  Future<HarnessAuthStatus> status(
          {required String harnessId,
          required String provider,
          String? accountId,
          String? attemptId}) async =>
      throw UnimplementedError();
  @override
  Future<HarnessAuthStatus> start(
          {required String harnessId,
          required String provider,
          required String mode,
          required String visibility,
          String? accountId,
          String? accountName}) async =>
      throw UnimplementedError();
  @override
  Future<HarnessAuthStatus> poll(
          {required String harnessId,
          required String provider,
          String? accountId,
          String? attemptId}) async =>
      throw UnimplementedError();
  @override
  Future<HarnessAuthStatus> submit(
          {required String harnessId,
          required String provider,
          required String code,
          String? accountId,
          String? attemptId}) async =>
      throw UnimplementedError();
  @override
  Future<HarnessAuthStatus> cancel(
          {required String harnessId,
          required String provider,
          String? accountId,
          String? attemptId}) async =>
      throw UnimplementedError();
  @override
  Future<HarnessAuthStatus> disconnect(
          {required String harnessId,
          required String provider,
          String? accountId}) async =>
      throw UnimplementedError();
}

class FakeInstanceExistenceResolver implements IInstanceExistenceResolver {
  FakeInstanceExistenceResolver(this.result, {this.authRepository, this.readiness});
  InstanceExistenceResult result;
  FakeAuthRepository? authRepository;
  FakeReadiness? readiness;
  int calls = 0;

  Object? throwError;
  Future<InstanceExistenceResult>? resultOverride;
  Completer<void>? clearGate;

  @override
  Future<InstanceExistenceResult> checkInstanceExists() async {
    calls++;
    final error = throwError;
    if (error != null) throw error;
    final override = resultOverride;
    final outcome = override != null ? await override : result;
    if (outcome == InstanceExistenceResult.gone) {
      readiness?.set(const ServerReadinessSnapshot(
          status: ServerReadinessStatus.notProvisioned));
      await authRepository?.clearSession();
      authRepository?.publish();
      final gate = clearGate;
      if (gate != null) await gate.future;
    }
    return outcome;
  }
}

GoRouter makeRouter() => GoRouter(initialLocation: '/boot', routes: [
      for (final pair in const [
        ('boot', '/boot'),
        ('onboarding', '/onboarding'),
        ('onboardingLogin', '/login'),
        ('onboardingHarnessAuth', '/harness'),
        ('chats', '/chats'),
        ('deploymentProgress', '/deployment'),
        ('instanceUnverifiable', '/instance-unverifiable'),
      ])
        GoRoute(
            name: pair.$1, path: pair.$2, builder: (_, __) => const SizedBox()),
    ]);

class HarnessTest {
  late final FakeReadiness readiness;
  late final FakeAuthRepository authRepository;
  late final AuthSessionCoordinator auth;
  late final FakeHarness harness;
  late final GoRouter router;
  late final BootRoutingDecider decider;
  HarnessTest(
      {ServerReadinessStatus status = ServerReadinessStatus.ready,
      String? instanceId,
      bool signedIn = false,
      bool harnessConnected = false,
      IInstanceExistenceResolver? instanceExistenceResolver}) {
    readiness = FakeReadiness(
        ServerReadinessSnapshot(status: status, instanceId: instanceId));
    authRepository = FakeAuthRepository(authenticated: signedIn);
    auth = AuthSessionCoordinator(authRepository);
    harness = FakeHarness(connected: harnessConnected);
    router = makeRouter();
    decider = BootRoutingDecider(
        readinessCheck: readiness,
        authCoordinator: auth,
        harnessAuthRepository: harness,
        router: router,
        instanceExistenceResolver: instanceExistenceResolver);
  }
  Future<void> start(WidgetTester tester) async {
    addTearDown(decider.dispose);
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Router.withConfig(config: router),
    ));
    await decider.start();
    await tester.pump();
  }
}

void main() {
  testWidgets(
      'start() reading GoRouter.state before any widget has ever attached '
      'the router (the real main() ordering -- runApp() schedules a build, '
      'it does not synchronously run one before the next line executes) '
      'does not crash', (tester) async {
    final readiness = FakeReadiness(const ServerReadinessSnapshot(
        status: ServerReadinessStatus.ready, instanceId: 'i'));
    final authRepository = FakeAuthRepository(authenticated: true);
    final auth = AuthSessionCoordinator(authRepository);
    final harness = FakeHarness(connected: true);
    final router = makeRouter();
    final decider = BootRoutingDecider(
        readinessCheck: readiness,
        authCoordinator: auth,
        harnessAuthRepository: harness,
        router: router);
    addTearDown(decider.dispose);

    // No tester.pumpWidget -- router.state's RouteMatchList is empty here.
    await decider.start();
  });

  testWidgets('notProvisioned -> onboarding', (tester) async {
    final t = HarnessTest(status: ServerReadinessStatus.notProvisioned);
    await t.start(tester);
    expect(t.router.state.name, RouteNames.onboarding);
  });
  testWidgets(
      'Pro provisioning -> deploymentProgress (route name only, no extra: payload)',
      (tester) async {
    final t = HarnessTest(
        status: ServerReadinessStatus.provisioning, instanceId: 'i');
    await t.start(tester);
    expect(t.router.state.name, RouteNames.deploymentProgress);
  });
  testWidgets('Pro resumeUnrecoverable -> deploymentProgress (route name only)',
      (tester) async {
    final t = HarnessTest(
        status: ServerReadinessStatus.resumeUnrecoverable, instanceId: 'i');
    await t.start(tester);
    expect(t.router.state.name, RouteNames.deploymentProgress);
  });
  testWidgets('start restores before routing an expired persisted token',
      (tester) async {
    final t = HarnessTest(signedIn: true);
    t.authRepository.refreshResult = AuthRefreshResult.invalidSession;
    await t.start(tester);
    expect(t.authRepository.refreshCalls, 1);
    expect(t.router.state.name, RouteNames.onboardingLogin);
  });
  testWidgets('racing replay and readiness emission coalesce restore',
      (tester) async {
    final t = HarnessTest(signedIn: true);
    await t.start(tester);
    final restores = t.authRepository.refreshCalls;
    t.readiness.changes.add(t.readiness.current);
    t.authRepository.publish();
    await tester.pump();
    expect(t.authRepository.refreshCalls, restores);
  });
  testWidgets('ready emissions restore only once per epoch', (tester) async {
    final t = HarnessTest(signedIn: true);
    await t.start(tester);
    t.readiness.changes.add(t.readiness.current);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(t.authRepository.refreshCalls, 1);
  });
  testWidgets('ready epoch transition restores again', (tester) async {
    final t = HarnessTest(signedIn: true);
    await t.start(tester);
    t.readiness.set(const ServerReadinessSnapshot(
        status: ServerReadinessStatus.provisioning));
    await tester.pump();
    t.readiness.set(
        const ServerReadinessSnapshot(status: ServerReadinessStatus.ready));
    await tester.pump();
    await tester.pump();
    expect(t.authRepository.refreshCalls, 2);
  });
  testWidgets('retryAuth restores again and coalesces in-flight restore',
      (tester) async {
    final t = HarnessTest(signedIn: true);
    await t.start(tester);
    await t.decider.retryAuth();
    expect(t.authRepository.refreshCalls, 2);
  });
  testWidgets('ready + signedOut self-host -> onboardingLogin', (tester) async {
    final t = HarnessTest();
    await t.start(tester);
    expect(t.router.state.name, RouteNames.onboardingLogin);
  });
  testWidgets('ready + signedOut Pro -> deploymentProgress', (tester) async {
    final t = HarnessTest(instanceId: 'i');
    await t.start(tester);
    expect(t.router.state.name, RouteNames.deploymentProgress);
  });
  testWidgets(
      'a fresh managed deployment -- ready+signedOut at start, then a '
      'first-ever login completes via an external auth-store change (not '
      'a decider-owned restore()) -- must not strand the user on '
      'deploymentProgress', (tester) async {
    final t = HarnessTest(instanceId: 'i', harnessConnected: true);
    await t.start(tester);
    expect(t.router.state.name, RouteNames.deploymentProgress);

    t.authRepository.authenticated = true;
    t.authRepository.publish();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));

    expect(t.router.state.name, RouteNames.chats);
  });
  testWidgets('unconfirmed temporarilyUnavailable is signed out',
      (tester) async {
    final t = HarnessTest(signedIn: true);
    t.authRepository.refreshResult = AuthRefreshResult.temporarilyUnavailable;
    await t.start(tester);
    expect(t.router.state.name, RouteNames.onboardingLogin);
  });
  testWidgets('confirmed temporarilyUnavailable is lenient', (tester) async {
    final t = HarnessTest(signedIn: true, harnessConnected: true);
    await t.start(tester);
    t.authRepository.refreshResult = AuthRefreshResult.temporarilyUnavailable;
    t.authRepository.publish();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(t.router.state.name, RouteNames.chats);
  });
  testWidgets('signedIn without harness -> onboardingHarnessAuth',
      (tester) async {
    final t = HarnessTest(signedIn: true);
    await t.start(tester);
    expect(t.router.state.name, RouteNames.onboardingHarnessAuth);
  });
  testWidgets('signedIn with harness -> chats', (tester) async {
    final t = HarnessTest(signedIn: true, harnessConnected: true);
    await t.start(tester);
    expect(t.router.state.name, RouteNames.chats);
  });
  testWidgets('duplicate latch on chats does not query or navigate',
      (tester) async {
    final t = HarnessTest(signedIn: true, harnessConnected: true);
    await t.start(tester);
    final calls = t.harness.calls;
    t.readiness.changes.add(t.readiness.current);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(t.harness.calls, calls);
    expect(t.router.state.name, RouteNames.chats);
  });
  testWidgets('latch key changes re-evaluate', (tester) async {
    final t = HarnessTest(signedIn: true, harnessConnected: true);
    await t.start(tester);
    t.authRepository.userId = 'other';
    t.authRepository.publish();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(t.harness.calls, 2);
  });
  testWidgets('stale harness result cannot overwrite newer reconcile',
      (tester) async {
    final t = HarnessTest(signedIn: true);
    final first = Completer<bool>();
    t.harness.resultOverride = first.future;
    t.harness.overrideOnce = true;
    final pending = t.start(tester);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    t.harness.connected = true;
    t.readiness.changes.add(t.readiness.current);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    first.complete(false);
    await tester.runAsync(() => pending);
    expect(t.router.state.name, RouteNames.chats);
  });

  testWidgets(
      'unconfirmed temporarilyUnavailable with an unknown existence check '
      'routes to instanceUnverifiable instead of signing out', (tester) async {
    final resolver = FakeInstanceExistenceResolver(InstanceExistenceResult.unknown);
    final t = HarnessTest(
        signedIn: true,
        instanceId: 'i',
        instanceExistenceResolver: resolver);
    t.authRepository.refreshResult = AuthRefreshResult.temporarilyUnavailable;
    await t.start(tester);
    expect(resolver.calls, 1);
    expect(t.router.state.name, RouteNames.instanceUnverifiable);
  });

  testWidgets(
      'unconfirmed temporarilyUnavailable with a confirmed-existing '
      'instance still routes to signOutDestination, unchanged from before',
      (tester) async {
    final resolver = FakeInstanceExistenceResolver(InstanceExistenceResult.exists);
    final t = HarnessTest(
        signedIn: true,
        instanceId: 'i',
        instanceExistenceResolver: resolver);
    t.authRepository.refreshResult = AuthRefreshResult.temporarilyUnavailable;
    await t.start(tester);
    expect(resolver.calls, 1);
    expect(t.router.state.name, RouteNames.deploymentProgress);
  });

  testWidgets(
      'unconfirmed temporarilyUnavailable with a confirmed-gone instance '
      'lets the resolver clear both readiness and the session, which '
      're-routes to onboarding via the normal readiness/sessionChanges '
      'reconcile -- no direct navigation from this branch', (tester) async {
    final resolver = FakeInstanceExistenceResolver(InstanceExistenceResult.gone);
    final t = HarnessTest(
        signedIn: true,
        instanceId: 'i',
        instanceExistenceResolver: resolver);
    resolver.authRepository = t.authRepository;
    resolver.readiness = t.readiness;
    t.authRepository.refreshResult = AuthRefreshResult.temporarilyUnavailable;
    await t.start(tester);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(resolver.calls, 1);
    expect(t.authRepository.authenticated, isFalse);
    expect(t.router.state.name, RouteNames.onboarding);
  });

  testWidgets(
      'with no resolver configured (self-host), unconfirmed '
      'temporarilyUnavailable behaves exactly as before -- straight to '
      'signOutDestination', (tester) async {
    final t = HarnessTest(signedIn: true);
    t.authRepository.refreshResult = AuthRefreshResult.temporarilyUnavailable;
    await t.start(tester);
    expect(t.router.state.name, RouteNames.onboardingLogin);
  });

  testWidgets(
      'a resolver that throws is treated as unknown -- routes to '
      'instanceUnverifiable and does not crash reconcile', (tester) async {
    final resolver = FakeInstanceExistenceResolver(InstanceExistenceResult.exists)
      ..throwError = Exception('provider unreachable');
    final t = HarnessTest(
        signedIn: true,
        instanceId: 'i',
        instanceExistenceResolver: resolver);
    t.authRepository.refreshResult = AuthRefreshResult.temporarilyUnavailable;
    await t.start(tester);
    expect(t.router.state.name, RouteNames.instanceUnverifiable);
  });

  testWidgets(
      'concurrent readiness/auth emissions while an existence check is '
      'still pending are coalesced into a single resolver call, not one '
      'per emission', (tester) async {
    final resolver = FakeInstanceExistenceResolver(InstanceExistenceResult.unknown);
    final gate = Completer<InstanceExistenceResult>();
    resolver.resultOverride = gate.future;
    final t = HarnessTest(
        signedIn: true,
        instanceId: 'i',
        instanceExistenceResolver: resolver);
    t.authRepository.refreshResult = AuthRefreshResult.temporarilyUnavailable;

    final pending = t.start(tester);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(resolver.calls, 1);
    // authRepository.publish() is deliberately not used here -- it flips
    // FakeAuthRepository's session state to signedIn, not
    // temporarilyUnavailable.
    t.readiness.changes.add(t.readiness.current);
    t.readiness.changes.add(t.readiness.current);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));

    gate.complete(InstanceExistenceResult.unknown);
    await tester.runAsync(() => pending);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));

    expect(resolver.calls, 1);
    expect(t.router.state.name, RouteNames.instanceUnverifiable);
  });

  testWidgets(
      'a confirmed-gone instance never navigates directly from the '
      'temporarilyUnavailable branch itself -- only the resolver\'s own '
      'ordered clear (readiness -> session), observed later via the '
      'normal reconcile listeners, is what actually moves the router',
      (tester) async {
    final resolver = FakeInstanceExistenceResolver(InstanceExistenceResult.gone);
    final gate = Completer<void>();
    resolver.clearGate = gate;
    final t = HarnessTest(
        signedIn: true,
        instanceId: 'i',
        instanceExistenceResolver: resolver);
    resolver.authRepository = t.authRepository;
    resolver.readiness = t.readiness;
    t.authRepository.refreshResult = AuthRefreshResult.temporarilyUnavailable;

    final pending = t.start(tester);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(t.router.state.name, RouteNames.onboarding);

    gate.complete();
    await tester.runAsync(() => pending);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));

    expect(resolver.calls, 1);
    expect(t.router.state.name, RouteNames.onboarding);
  });
}
