import 'dart:async';

import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/application/server_control/server_control_cubit.dart';
import 'package:pocketcoder_flutter/application/server_control/server_control_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/release/server_release_status.dart';
import 'package:pocketcoder_flutter/domain/security/i_local_auth_gate.dart';
import 'package:pocketcoder_flutter/domain/server_control/i_provider_console_link.dart';
import 'package:pocketcoder_flutter/domain/server_control/i_server_connection_details_provider.dart';
import 'package:pocketcoder_flutter/domain/server_control/i_server_control_service.dart';
import 'package:pocketcoder_flutter/domain/server_control/server_control_result.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/core/in_app_browser_launcher.dart';
import 'package:pocketcoder_flutter/presentation/server_control/server_control_view.dart';

const _digest =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

class _FakeService implements IServerControlService {
  final calls = <ServerControlOperation>[];
  final pending = <ServerControlOperation, Future<ServerControlResult>>{};
  ServerReleaseStatusSnapshot? release;

  @override
  Future<String?> readPublicKey({required String instanceId}) =>
      throw UnimplementedError();

  String? privateKey;

  @override
  Future<String?> readPrivateKey({required String instanceId}) async =>
      privateKey;

  @override
  Future<ServerReleaseStatusSnapshot> inspectRelease() async => release!;

  @override
  Future<ServerControlResult> restartPocketCoder(
          {required String instanceId}) =>
      _call(ServerControlOperation.restartPocketCoder);

  @override
  Future<ServerControlResult> updatePocketCoder({required String instanceId}) =>
      _call(ServerControlOperation.updatePocketCoder);

  @override
  Future<ServerControlResult> restartNixOs({required String instanceId}) =>
      _call(ServerControlOperation.restartNixOs);

  @override
  Future<ServerControlResult> updateNixOs({required String instanceId}) =>
      _call(ServerControlOperation.updateNixOs);

  @override
  Future<ServerControlResult> saveBackup({required String instanceId}) =>
      _call(ServerControlOperation.saveBackup);

  @override
  Future<ServerControlResult> restoreBackup({required String instanceId}) =>
      _call(ServerControlOperation.restoreBackup);

  Future<ServerControlResult> _call(ServerControlOperation operation) {
    calls.add(operation);
    return pending[operation]!;
  }
}

class _FakeConnectionDetails implements IServerConnectionDetailsProvider {
  const _FakeConnectionDetails({this.adminPassword});

  @override
  final String? adminPassword;

  @override
  bool get isAvailable => true;

  @override
  String? get ipAddress => null;

  @override
  String? get httpsEndpoint => null;

  @override
  String? get adminIdentity => null;
}

class _FakeLocalAuthGate implements ILocalAuthGate {
  _FakeLocalAuthGate({this.approve = true});

  bool approve;

  @override
  Future<bool> authenticate({required String reason}) async => approve;
}

class _FakeProviderConsoleLink implements IProviderConsoleLink {
  _FakeProviderConsoleLink({this.uri});

  final Uri? uri;

  @override
  Future<Uri?> resolve() async => uri;
}

class _FakeInAppBrowserLauncher implements InAppBrowserLauncher {
  Uri? opened;

  @override
  Future<bool> open(Uri uri) async {
    opened = uri;
    return true;
  }
}

Widget _app(
  ServerControlCubit cubit, {
  IProviderConsoleLink? providerConsoleLink,
  InAppBrowserLauncher? inAppBrowserLauncher,
}) =>
    MaterialApp.router(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: GoRouter(
        initialLocation: '/server-control',
        routes: [
          GoRoute(
            path: '/server-control',
            builder: (_, __) => BlocProvider.value(
              value: cubit,
              child: ServerControlView(
                instanceId: 'instance-1',
                inAppBrowserLauncher:
                    inAppBrowserLauncher ?? _FakeInAppBrowserLauncher(),
                providerConsoleLink: providerConsoleLink,
              ),
            ),
          ),
          GoRoute(
            path: '/from',
            builder: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );

ServerReleaseStatusSnapshot _release() => ServerReleaseStatusSnapshot(
      status: ServerReleaseStatus.current,
      currentVersion: '2.0.0',
      currentDataVersion: 1,
      currentReleaseDigest: _digest,
      checkedAt: DateTime.utc(2026, 8, 14),
    );

ServerControlResult _success(ServerControlOperation operation) =>
    ServerControlResult(
      command: ServerControlCubit.commandFor(operation),
      exitCode: 0,
      stdout: 'backup complete',
      stderr: '',
    );

ServerControlResult _failure(ServerControlOperation operation) =>
    ServerControlResult(
      command: ServerControlCubit.commandFor(operation),
      exitCode: 1,
      stdout: '',
      stderr: 'permission denied',
    );

void main() {
  testWidgets('renders all six controls and release status', (tester) async {
    final service = _FakeService()..release = _release();
    final cubit = ServerControlCubit(service, _FakeLocalAuthGate());
    await tester.pumpWidget(_app(cubit));

    expect(find.text('RELEASE STATUS: CHECKING'), findsOneWidget);
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.serverControlGroupPocketCoder), findsOneWidget);
    expect(find.text(l10n.serverControlGroupNixOs), findsOneWidget);
    expect(find.text(l10n.serverControlGroupData), findsOneWidget);
    expect(find.text(l10n.serverControlActionRestart), findsNWidgets(2));
    expect(find.text(l10n.serverControlActionUpdate), findsNWidgets(2));
    expect(find.text(l10n.serverControlActionSave), findsOneWidget);
    expect(find.text(l10n.serverControlActionRestore), findsOneWidget);
    await cubit.inspectRelease();
    await tester.pump();
    expect(find.textContaining('RELEASE STATUS: CURRENT'), findsOneWidget);
    expect(find.textContaining('CURRENT: 2.0.0'), findsOneWidget);
    await cubit.close();
  });

  testWidgets('renders available version and contract versions when present',
      (tester) async {
    final service = _FakeService()
      ..release = ServerReleaseStatusSnapshot(
        status: ServerReleaseStatus.updateAvailable,
        currentVersion: '2.0.0',
        currentDataVersion: 1,
        currentReleaseDigest: _digest,
        checkedAt: DateTime.utc(2026, 8, 14),
        availableVersion: '2.1.0',
        appContractVersion: 2,
        serverApiVersion: 1,
        deploymentContractVersion: 3,
        nixosVersion: '26.05',
      );
    final cubit = ServerControlCubit(service, _FakeLocalAuthGate());
    await tester.pumpWidget(_app(cubit));
    await cubit.inspectRelease();
    await tester.pump();

    expect(find.textContaining('AVAILABLE: 2.1.0'), findsOneWidget);
    expect(
      find.textContaining('CONTRACTS: APP v2 · SERVER v1 · DEPLOYMENT v3'),
      findsOneWidget,
    );
    expect(find.textContaining('NIXOS: 26.05'), findsOneWidget);
    await cubit.close();
  });

  testWidgets('omits available/contract lines when absent', (tester) async {
    final service = _FakeService()..release = _release();
    final cubit = ServerControlCubit(service, _FakeLocalAuthGate());
    await tester.pumpWidget(_app(cubit));
    await cubit.inspectRelease();
    await tester.pump();

    expect(find.textContaining('AVAILABLE:'), findsNothing);
    expect(find.textContaining('CONTRACTS:'), findsNothing);
    expect(find.textContaining('NIXOS:'), findsNothing);
    await cubit.close();
  });

  testWidgets(
      'shows the SSH public key with copy when present, nothing '
      'when absent', (tester) async {
    final service = _FakeService()..release = _release();
    final cubit = ServerControlCubit(service, _FakeLocalAuthGate());
    await tester.pumpWidget(_app(cubit));

    expect(find.byType(SelectableText), findsNothing);

    cubit.emit(cubit.state.copyWith(publicKey: 'ssh-ed25519 AAAA test'));
    await tester.pump();

    expect(find.textContaining('ssh-ed25519 AAAA test'), findsOneWidget);
    await cubit.close();
  });

  testWidgets('server control is a footer destination without BACK',
      (tester) async {
    final service = _FakeService()..release = _release();
    final cubit = ServerControlCubit(service, _FakeLocalAuthGate());
    final router = GoRouter(
      initialLocation: '/server-control',
      routes: [
        GoRoute(
          path: '/server-control',
          builder: (_, __) => BlocProvider.value(
            value: cubit,
            child: ServerControlView(
              instanceId: 'instance-1',
              inAppBrowserLauncher: _FakeInAppBrowserLauncher(),
            ),
          ),
        ),
        GoRoute(
          path: '/from',
          builder: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ));
    expect(find.text('BACK'), findsNothing);
    await cubit.close();
  });

  testWidgets('requires confirmation before delegating an operation',
      (tester) async {
    final service = _FakeService();
    final cubit = ServerControlCubit(service, _FakeLocalAuthGate());
    final future = Future.value(_success(ServerControlOperation.saveBackup));
    service.pending[ServerControlOperation.saveBackup] = future;
    await tester.pumpWidget(_app(cubit));

    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    expect(find.text('confirm server control'), findsOneWidget);
    expect(service.calls, isEmpty);
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(service.calls, isEmpty);

    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CONFIRM'));
    await tester.pump();
    expect(service.calls, [ServerControlOperation.saveBackup]);
    await cubit.close();
  });

  testWidgets('disables controls while busy', (tester) async {
    // A release is set so inspectRelease() succeeds on its first attempt --
    // otherwise the retry path's real 1s Future.delayed hangs forever under
    // testWidgets' FakeAsync zone, since cubit.run() (and any Timer it
    // schedules) is already bound to that zone by the time it's invoked
    // below; wrapping the await afterward in runAsync does not move it.
    final service = _FakeService()..release = _release();
    final cubit = ServerControlCubit(service, _FakeLocalAuthGate());
    final pending = Completer<ServerControlResult>();
    service.pending[ServerControlOperation.restartNixOs] = pending.future;
    await tester.pumpWidget(_app(cubit));
    final run = cubit.run(
      operation: ServerControlOperation.restartNixOs,
      instanceId: 'instance-1',
    );
    await tester.pump();
    expect(cubit.state.status, UiFlowStatus.loading);
    // The control-group IgnorePointers are what busy state disables --
    // unrelated shell chrome (nav, etc.) also uses IgnorePointer for other
    // reasons, so scope this to the actual operation buttons, not the tree.
    for (final label in ['RESTART', 'UPDATE', 'SAVE', 'RESTORE']) {
      for (final finder in find.text(label).evaluate()) {
        final ignorePointer = tester.widget<IgnorePointer>(find
            .ancestor(
              of: find.byWidget(finder.widget),
              matching: find.byType(IgnorePointer),
            )
            .first);
        expect(ignorePointer.ignoring, isTrue,
            reason: '$label should be disabled while busy');
      }
    }
    pending.complete(_success(ServerControlOperation.restartNixOs));
    await run;
    await cubit.close();
  });

  testWidgets('renders command output and errors', (tester) async {
    final service = _FakeService();
    final cubit = ServerControlCubit(service, _FakeLocalAuthGate());
    final result = _success(ServerControlOperation.saveBackup);
    service.pending[ServerControlOperation.saveBackup] = Future.value(result);
    await tester.pumpWidget(_app(cubit));
    await cubit.run(
      operation: ServerControlOperation.saveBackup,
      instanceId: 'instance-1',
    );
    await tester.pump();
    expect(find.text(r'$ saveBackup'), findsOneWidget);
    expect(find.text('OUTPUT'), findsOneWidget);
    await tester.tap(find.text('OUTPUT'));
    await tester.pump();
    expect(find.text('backup complete'), findsOneWidget);
    await cubit.close();
  });

  testWidgets('renders failed command output', (tester) async {
    final service = _FakeService();
    final cubit = ServerControlCubit(service, _FakeLocalAuthGate());
    service.pending[ServerControlOperation.updateNixOs] =
        Future.value(_failure(ServerControlOperation.updateNixOs));
    await tester.pumpWidget(_app(cubit));

    // No release set on _FakeService, so inspectRelease()'s retry path hits
    // a real 1s Future.delayed -- runAsync escapes the FakeAsync zone that
    // testWidgets otherwise traps it in, where nothing ever advances it.
    await tester.runAsync(() => cubit.run(
          operation: ServerControlOperation.updateNixOs,
          instanceId: 'instance-1',
        ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OUTPUT'));
    await tester.pumpAndSettle();

    expect(find.textContaining('permission denied'), findsOneWidget);
    await cubit.close();
  });

  testWidgets('reveals the admin password only after local auth succeeds',
      (tester) async {
    final service = _FakeService();
    final gate = _FakeLocalAuthGate(approve: false);
    final cubit = ServerControlCubit(
      service,
      gate,
      const _FakeConnectionDetails(adminPassword: 'secret-pw'),
    );
    await tester.pumpWidget(_app(cubit));

    expect(find.textContaining('•' * 'secret-pw'.length), findsOneWidget);
    await tester.tap(find.text('SHOW'));
    await tester.pumpAndSettle();
    expect(find.textContaining('secret-pw'), findsNothing);

    gate.approve = true;
    await tester.tap(find.text('SHOW'));
    await tester.pumpAndSettle();
    expect(find.textContaining('secret-pw'), findsOneWidget);

    await tester.tap(find.text('HIDE'));
    await tester.pumpAndSettle();
    expect(find.textContaining('secret-pw'), findsNothing);
    await cubit.close();
  });

  testWidgets('reveals the private key only after local auth succeeds',
      (tester) async {
    final service = _FakeService()..privateKey = 'PRIVATE-KEY-PEM';
    final gate = _FakeLocalAuthGate(approve: false);
    final cubit = ServerControlCubit(service, gate);
    await tester.pumpWidget(_app(cubit));
    cubit.emit(cubit.state.copyWith(publicKey: 'ssh-ed25519 AAAA test'));
    await tester.pump();

    expect(find.textContaining('PRIVATE-KEY-PEM'), findsNothing);
    await tester.tap(find.text('SHOW').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('PRIVATE-KEY-PEM'), findsNothing);

    gate.approve = true;
    await tester.tap(find.text('SHOW').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('PRIVATE-KEY-PEM'), findsOneWidget);
    await cubit.close();
  });

  group('provider console button', () {
    testWidgets('is absent when no providerConsoleLink is supplied',
        (tester) async {
      final service = _FakeService()..release = _release();
      final cubit = ServerControlCubit(service, _FakeLocalAuthGate());
      await tester.pumpWidget(_app(cubit));

      expect(find.text('PROVIDER WEB PORTAL'), findsNothing);
      await cubit.close();
    });

    testWidgets('opens the resolved URL in the in-app browser when tapped',
        (tester) async {
      final service = _FakeService()..release = _release();
      final cubit = ServerControlCubit(service, _FakeLocalAuthGate());
      final launcher = _FakeInAppBrowserLauncher();
      await tester.pumpWidget(_app(
        cubit,
        providerConsoleLink: _FakeProviderConsoleLink(
          uri: Uri.parse('https://cloud.linode.com/linodes/42'),
        ),
        inAppBrowserLauncher: launcher,
      ));

      expect(find.text('PROVIDER WEB PORTAL'), findsOneWidget);
      await tester.tap(find.text('PROVIDER WEB PORTAL'));
      await tester.pumpAndSettle();

      expect(launcher.opened, Uri.parse('https://cloud.linode.com/linodes/42'));
      await cubit.close();
    });

    testWidgets(
        'shows a snackbar instead of opening a browser when there '
        'is no active instance', (tester) async {
      final service = _FakeService()..release = _release();
      final cubit = ServerControlCubit(service, _FakeLocalAuthGate());
      final launcher = _FakeInAppBrowserLauncher();
      await tester.pumpWidget(_app(
        cubit,
        providerConsoleLink: _FakeProviderConsoleLink(uri: null),
        inAppBrowserLauncher: launcher,
      ));

      await tester.tap(find.text('PROVIDER WEB PORTAL'));
      await tester.pumpAndSettle();

      expect(launcher.opened, isNull);
      expect(find.textContaining('No active provider-managed instance'),
          findsOneWidget);
      await cubit.close();
    });
  });
}
