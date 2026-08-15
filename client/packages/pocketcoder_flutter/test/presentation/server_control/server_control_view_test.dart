import 'dart:async';

import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/application/server_control/server_control_cubit.dart';
import 'package:pocketcoder_flutter/application/server_control/server_control_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/release/server_release_status.dart';
import 'package:pocketcoder_flutter/domain/server_control/i_server_control_service.dart';
import 'package:pocketcoder_flutter/domain/server_control/server_control_result.dart';
import 'package:pocketcoder_flutter/presentation/server_control/server_control_view.dart';

const _digest =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

class _FakeService implements IServerControlService {
  final calls = <ServerControlOperation>[];
  final pending = <ServerControlOperation, Future<ServerControlResult>>{};
  ServerReleaseStatusSnapshot? release;

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

Widget _app(ServerControlCubit cubit) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: BlocProvider.value(
        value: cubit,
        child: const ServerControlView(instanceId: 'instance-1'),
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
    final cubit = ServerControlCubit(service);
    await tester.pumpWidget(_app(cubit));

    expect(find.text('RELEASE STATUS: CHECKING'), findsOneWidget);
    for (final operation in ServerControlOperation.values) {
      expect(
          find.text(operation.name
              .replaceAllMapped(
                RegExp(r'([A-Z])'),
                (match) => ' ${match.group(1)}',
              )
              .toUpperCase()),
          findsOneWidget);
    }
    await cubit.inspectRelease();
    await tester.pump();
    expect(find.textContaining('RELEASE STATUS: CURRENT'), findsOneWidget);
    expect(find.textContaining('CURRENT: 2.0.0'), findsOneWidget);
    await cubit.close();
  });

  testWidgets('requires confirmation before delegating an operation',
      (tester) async {
    final service = _FakeService();
    final cubit = ServerControlCubit(service);
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
    final cubit = ServerControlCubit(service);
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
    final cubit = ServerControlCubit(service);
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
    final cubit = ServerControlCubit(service);
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
}
