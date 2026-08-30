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
import 'package:pocketcoder_flutter/domain/server_control/i_server_connection_details_provider.dart';
import 'package:pocketcoder_flutter/domain/server_control/i_server_control_service.dart';
import 'package:pocketcoder_flutter/domain/server_control/server_control_result.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
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

Widget _app(ServerControlCubit cubit) => MaterialApp.router(
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
              child: const ServerControlView(instanceId: 'instance-1'),
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
  testWidgets('renders all five controls and release status', (tester) async {
    final service = _FakeService()..release = _release();
    final cubit = ServerControlCubit(service, _FakeLocalAuthGate());
    await tester.pumpWidget(_app(cubit));

    expect(find.text('RELEASE STATUS: CHECKING'), findsOneWidget);
    final l10n = lookupAppLocalizations(const Locale('en'));
    final operationLabels = [
      l10n.serverControlOperationRestartPocketCoder,
      l10n.serverControlOperationUpdatePocketCoder,
      l10n.serverControlOperationRestartNixOs,
      l10n.serverControlOperationUpdateNixOs,
      l10n.serverControlOperationSaveBackup,
    ];
    expect(operationLabels.length, ServerControlOperation.values.length,
        reason:
            'a new ServerControlOperation needs its label added here too');
    for (final label in operationLabels) {
      // TerminalButton uppercases its label before rendering.
      expect(find.text(label.toUpperCase()), findsOneWidget);
    }
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
    await cubit.close();
  });

  testWidgets('shows the SSH public key with copy when present, nothing '
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
            child: const ServerControlView(instanceId: 'instance-1'),
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

    await tester.tap(find.text('SAVE BACKUP'));
    await tester.pumpAndSettle();
    expect(find.text('CONFIRM SERVER CONTROL'), findsOneWidget);
    expect(service.calls, isEmpty);
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(service.calls, isEmpty);

    await tester.tap(find.text('SAVE BACKUP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CONFIRM'));
    await tester.pump();
    expect(service.calls, [ServerControlOperation.saveBackup]);
    await cubit.close();
  });

  testWidgets('disables controls while busy', (tester) async {
    final service = _FakeService();
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
    expect(
        tester
            .widget<OutlinedButton>(find.byType(OutlinedButton).first)
            .onPressed,
        isNull);
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

    await cubit.run(
      operation: ServerControlOperation.updateNixOs,
      instanceId: 'instance-1',
    );
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
}
