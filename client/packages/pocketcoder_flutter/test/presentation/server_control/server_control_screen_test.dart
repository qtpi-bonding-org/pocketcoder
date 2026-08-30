import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/os_control/i_root_ssh_command_runner.dart';
import 'package:pocketcoder_flutter/domain/os_control/i_root_ssh_credentials_provider.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_command.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_command_result.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_credentials.dart';
import 'package:pocketcoder_flutter/domain/release/i_server_release_status_service.dart';
import 'package:pocketcoder_flutter/domain/release/server_release_status.dart';
import 'package:pocketcoder_flutter/domain/server_control/i_server_control_setup_gate.dart';
import 'package:pocketcoder_flutter/domain/server_control/i_server_control_service.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/infrastructure/server_control/ssh_server_control_service.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/server_control/server_control_screen.dart';

class _FakeRunner implements IRootSshCommandRunner {
  @override
  Future<RootSshCommandResult> run({
    required String instanceId,
    required String host,
    required RootSshCommand command,
    dynamic stdin,
    String? shellEnvPrefix,
  }) async =>
      const RootSshCommandResult(exitCode: 0, stdout: '', stderr: '');
}

class _FakeReleaseStatusService implements IServerReleaseStatusService {
  @override
  bool get isAuthenticated => true;

  @override
  Stream<bool> get authenticationChanges => const Stream.empty();

  @override
  Future<ServerReleaseStatusSnapshot> inspect() async =>
      ServerReleaseStatusSnapshot(
        status: ServerReleaseStatus.current,
        currentVersion: '1.0.0',
        currentDataVersion: 1,
        currentReleaseDigest: 'digest',
        checkedAt: DateTime(2026),
      );
}

class _FakeCredentialsProvider implements IRootSshCredentialsProvider {
  @override
  Future<RootSshCredentials?> readRootSshCredentials({
    required String instanceId,
  }) async => null;
}

class _BlockingGate implements IServerControlSetupGate {
  @override
  Future<Widget?> resolveSetupScreen({required VoidCallback onSetupComplete}) async =>
      const Text('SET UP YOUR SERVER FIRST');
}

class _ThrowingGate implements IServerControlSetupGate {
  @override
  Future<Widget?> resolveSetupScreen({required VoidCallback onSetupComplete}) async =>
      throw StateError('secure storage unavailable');
}

class _OneShotGate implements IServerControlSetupGate {
  _OneShotGate({required this.isDone});

  final bool Function() isDone;

  @override
  Future<Widget?> resolveSetupScreen({required VoidCallback onSetupComplete}) async {
    if (isDone()) return null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('SET UP YOUR SERVER FIRST'),
        TextButton(onPressed: onSetupComplete, child: const Text('FINISH SETUP')),
      ],
    );
  }
}

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: child,
    );

void main() {
  setUp(() {
    GetIt.instance.registerLazySingleton<IServerControlService>(
      () => SshServerControlService(
        rootSshCommandRunner: _FakeRunner(),
        pocketBase: PocketBase('https://example.test'),
        releaseStatusService: _FakeReleaseStatusService(),
        credentialsProvider: _FakeCredentialsProvider(),
      ),
    );
  });

  tearDown(GetIt.instance.reset);

  testWidgets(
      'renders the setup gate widget instead of the normal controls when '
      'IServerControlSetupGate is registered and returns one', (tester) async {
    GetIt.instance.registerLazySingleton<IServerControlSetupGate>(
      () => _BlockingGate(),
    );

    await tester.pumpWidget(_wrap(const ServerControlScreen(instanceId: '')));
    await tester.pumpAndSettle();

    expect(find.text('SET UP YOUR SERVER FIRST'), findsOneWidget);
    expect(find.text('RESTART POCKETCODER'), findsNothing);
  });

  testWidgets(
      'renders the normal controls directly when no setup gate is registered',
      (tester) async {
    await tester.pumpWidget(_wrap(const ServerControlScreen(instanceId: '')));
    await tester.pumpAndSettle();

    expect(find.text('SET UP YOUR SERVER FIRST'), findsNothing);
    expect(find.text('RESTART POCKETCODER'), findsOneWidget,
        reason: 'normal controls should render');
  });

  testWidgets(
      'a setup gate that throws while resolving does not silently fall '
      'through to the normal controls', (tester) async {
    GetIt.instance.registerLazySingleton<IServerControlSetupGate>(
      () => _ThrowingGate(),
    );

    await tester.pumpWidget(_wrap(const ServerControlScreen(instanceId: '')));
    await tester.pumpAndSettle();

    expect(find.text('RESTART POCKETCODER'), findsNothing,
        reason: 'gate resolution errors must remain blocked');
  });

  testWidgets(
      'calling onSetupComplete re-resolves the gate and transitions into '
      'the normal controls without leaving the screen', (tester) async {
    var setupDone = false;
    GetIt.instance.registerLazySingleton<IServerControlSetupGate>(
      () => _OneShotGate(isDone: () => setupDone),
    );

    await tester.pumpWidget(_wrap(const ServerControlScreen(instanceId: '')));
    await tester.pumpAndSettle();
    expect(find.text('SET UP YOUR SERVER FIRST'), findsOneWidget);

    setupDone = true;
    await tester.tap(find.text('FINISH SETUP'));
    await tester.pumpAndSettle();

    expect(find.text('SET UP YOUR SERVER FIRST'), findsNothing);
    expect(find.text('RESTART POCKETCODER'), findsOneWidget);
  });
}
