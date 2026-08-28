// Integration tests for AgentAuthAdapter's oauth path now that it renders
// CredentialConnectionView via an injected InAppBrowserLauncher instead of
// the retired ExternalAuthDialog + url_launcher(LaunchMode.externalApplication).
// Covers exactly what the plan called for: browser-destination open-page
// wiring, app-destination code submission, and browser-open failure
// messaging -- at the real adapter/dialog integration point, not just the
// already-covered CredentialConnectionView widget in isolation.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/application/chat/chat_list_cubit.dart';
import 'package:pocketcoder_flutter/application/harness_auth/harness_auth_cubit.dart';
import 'package:pocketcoder_flutter/application/provider/provider_cubit.dart';
import 'package:pocketcoder_flutter/application/release_status/release_status_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/chat/i_chat_list_repository.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/harness_auth_models.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/i_harness_auth_repository.dart';
import 'package:pocketcoder_flutter/domain/models/chat.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/harness_provider.dart';
import 'package:pocketcoder_flutter/domain/provider/i_provider_repository.dart';
import 'package:pocketcoder_flutter/domain/release/server_release_status.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/core/in_app_browser_launcher.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/release_status_banner.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/adapters/agent_auth_adapter.dart';

class MockProviderRepository extends Mock implements IProviderRepository {}

class MockHarnessAuthRepository extends Mock
    implements IHarnessAuthRepository {}

class MockChatListRepository extends Mock implements IChatListRepository {}

class _RecordingLauncher implements InAppBrowserLauncher {
  _RecordingLauncher({this.result = true});
  final bool result;
  final opened = <Uri>[];
  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return result;
  }
}

const _codexId = 'codex-1';
const _providerId = 'provider-openai';
final _verificationUri = Uri.parse('https://auth.openai.com/codex/device');

Harnesse _codex() => const Harnesse(
      id: _codexId,
      name: 'Codex',
      cliId: 'codex',
      acpTransport: HarnesseAcpTransport.stdio,
    );

HarnessAuthStatus _awaitingChallenge({int pollIntervalSeconds = 4}) =>
    HarnessAuthStatus(
      harness: _codexId,
      provider: _providerId,
      accountId: '',
      accountName: '',
      visibility: harnessAccountVisibilityPersonal,
      credentialMode: 'account',
      status: 'awaiting_input',
      challenge: HarnessAuthChallenge.fromJson({
        'type': 'device-code',
        'text': 'legacy prose',
        'kind': 'device_code',
        'verificationUri': _verificationUri.toString(),
        'userCode': 'ABCD-1234',
        'codeDestination': 'browser',
        'pollIntervalSeconds': pollIntervalSeconds,
      }),
    );

HarnessAuthStatus _connected() => const HarnessAuthStatus(
      harness: _codexId,
      provider: _providerId,
      accountId: 'acct-1',
      accountName: 'acct',
      visibility: harnessAccountVisibilityPersonal,
      credentialMode: 'account',
      status: 'connected',
    );

Future<void> _pumpScreen(
  WidgetTester tester, {
  required MockProviderRepository providerRepo,
  required MockHarnessAuthRepository authRepo,
  required MockChatListRepository chatRepo,
  required InAppBrowserLauncher launcher,
}) async {
  // Cubits are provided above MaterialApp.router (matching production, where
  // these are app-global providers), not inside the route's own builder --
  // showDialog uses the root Navigator by default, so a dialog's context
  // must be a descendant of these providers, or reading ChatListCubit from
  // within the dialog (as _openChat does on reaching "connected") throws
  // ProviderNotFoundError.
  final router = GoRouter(
    initialLocation: '/harness-auth',
    routes: [
      GoRoute(
        path: '/harness-auth',
        builder: (context, state) => ReleaseStatusScope(
          state: ReleaseStatusState(
            snapshot: const ServerReleaseStatusSnapshot(
              status: ServerReleaseStatus.current,
              currentVersion: '1',
              currentDataVersion: 1,
              currentReleaseDigest: 'digest',
              checkedAt: null,
              selectedHarnesses: ['codex'],
            ),
          ),
          onDismiss: () {},
          child: AgentAuthAdapter(launcher: launcher),
        ),
      ),
      GoRoute(
        path: '${AppRoutes.chat}/:chatId',
        builder: (context, state) =>
            Text('chat-screen:${state.pathParameters['chatId']}'),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ProviderCubit(providerRepo)..watchAll()),
        BlocProvider(
          create: (_) => HarnessAuthCubit(
            providerRepository: providerRepo,
            authRepository: authRepo,
          )..watchData(),
        ),
        BlocProvider(create: (_) => ChatListCubit(chatRepo)),
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

void main() {
  late MockProviderRepository providerRepo;
  late MockHarnessAuthRepository authRepo;
  late MockChatListRepository chatRepo;

  setUp(() {
    providerRepo = MockProviderRepository();
    authRepo = MockHarnessAuthRepository();
    chatRepo = MockChatListRepository();

    when(() => providerRepo.watchHarnesses())
        .thenAnswer((_) => Stream.value([_codex()]));
    when(() => providerRepo.watchModels())
        .thenAnswer((_) => const Stream.empty());
    when(() => providerRepo.watchHarnessModels())
        .thenAnswer((_) => const Stream.empty());
    when(() => providerRepo.watchHarnessProviders())
        .thenAnswer((_) => Stream.value([
              const HarnessProvider(
                id: 'edge-1',
                harness: _codexId,
                provider: _providerId,
                supportsOauth: true,
              ),
            ]));
    when(() => providerRepo.watchProviderCatalog())
        .thenAnswer((_) => const Stream.empty());
    when(() => providerRepo.watchProviderAPIKeys())
        .thenAnswer((_) => const Stream.empty());
    when(() => chatRepo.watchChats()).thenAnswer((_) => const Stream.empty());
    when(() => chatRepo.createChat(
          title: any(named: 'title'),
          harness: any(named: 'harness'),
          harnessModelOverride: any(named: 'harnessModelOverride'),
          ollamaModelOverride: any(named: 'ollamaModelOverride'),
          workspaceOverride: any(named: 'workspaceOverride'),
        )).thenAnswer((_) async => const Chat(
          id: 'chat-1',
          title: 'New Chat',
          user: 'admin',
        ));
    // Every test taps CANCEL to close its dialog cleanly; an unstubbed
    // cancel() leaves the per-harness status unchanged (isConnecting still
    // true), which causes the poll timer to be recreated on the very next
    // rebuild instead of staying cancelled.
    when(() => authRepo.cancel(
          harnessId: any(named: 'harnessId'),
          provider: any(named: 'provider'),
          accountId: any(named: 'accountId'),
          attemptId: any(named: 'attemptId'),
        )).thenAnswer((_) async => const HarnessAuthStatus(
          harness: _codexId,
          provider: _providerId,
          accountId: '',
          accountName: '',
          visibility: harnessAccountVisibilityPersonal,
          credentialMode: 'account',
          status: 'disconnected',
        ));
  });

  testWidgets(
      'tapping a Codex harness opens the authorization page through the '
      'injected launcher with the structured verification URI, with no '
      'app-side code field', (tester) async {
    when(() => authRepo.start(
          harnessId: _codexId,
          provider: _providerId,
          mode: 'oauth',
          visibility: harnessAccountVisibilityPersonal,
        )).thenAnswer((_) async => _awaitingChallenge());

    final launcher = _RecordingLauncher();
    await _pumpScreen(tester,
        providerRepo: providerRepo,
        authRepo: authRepo,
        chatRepo: chatRepo,
        launcher: launcher);

    await tester.tap(find.text('Codex'));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(find.text('[OPEN AUTHORIZATION PAGE]'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('[OPEN AUTHORIZATION PAGE]'));
    await tester.pump();
    expect(launcher.opened, [_verificationUri]);

    await tester.tap(find.text('CANCEL'));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
  });

  testWidgets(
      'the poll timer fires on the challenge-provided interval and keeps '
      'polling as long as the dialog stays open, reacting to each new '
      'emission rather than a one-time snapshot', (tester) async {
    when(() => authRepo.start(
          harnessId: _codexId,
          provider: _providerId,
          mode: 'oauth',
          visibility: harnessAccountVisibilityPersonal,
        )).thenAnswer((_) async => _awaitingChallenge(pollIntervalSeconds: 2));
    var pollCount = 0;
    when(() => authRepo.poll(
          harnessId: _codexId,
          provider: _providerId,
          accountId: any(named: 'accountId'),
          attemptId: any(named: 'attemptId'),
        )).thenAnswer((_) async {
      pollCount++;
      return _awaitingChallenge(pollIntervalSeconds: 2);
    });
    when(() => authRepo.cancel(
          harnessId: _codexId,
          provider: _providerId,
          accountId: any(named: 'accountId'),
          attemptId: any(named: 'attemptId'),
        )).thenAnswer((_) async => const HarnessAuthStatus(
          harness: _codexId,
          provider: _providerId,
          accountId: '',
          accountName: '',
          visibility: harnessAccountVisibilityPersonal,
          credentialMode: 'account',
          status: 'disconnected',
        ));

    await tester.runAsync(() async {});
    await _pumpScreen(tester,
        providerRepo: providerRepo,
        authRepo: authRepo,
        chatRepo: chatRepo,
        launcher: _RecordingLauncher());

    await tester.tap(find.text('Codex'));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(pollCount, 0);
    await tester.pump(const Duration(seconds: 2, milliseconds: 100));
    await tester.pump();
    expect(pollCount, greaterThanOrEqualTo(1));

    final firstCount = pollCount;
    await tester.pump(const Duration(seconds: 2, milliseconds: 100));
    await tester.pump();
    expect(pollCount, greaterThan(firstCount));

    // Close the dialog so the timer is cancelled and no pending Timer trips
    // flutter_test's teardown invariant check.
    await tester.tap(find.text('CANCEL'));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
  });

  testWidgets(
      'cancelling stops the poll timer immediately -- no further poll calls '
      'even once enough virtual time elapses for another tick', (tester) async {
    when(() => authRepo.start(
          harnessId: _codexId,
          provider: _providerId,
          mode: 'oauth',
          visibility: harnessAccountVisibilityPersonal,
        )).thenAnswer((_) async => _awaitingChallenge(pollIntervalSeconds: 2));
    var pollCount = 0;
    when(() => authRepo.poll(
          harnessId: _codexId,
          provider: _providerId,
          accountId: any(named: 'accountId'),
          attemptId: any(named: 'attemptId'),
        )).thenAnswer((_) async {
      pollCount++;
      return _awaitingChallenge(pollIntervalSeconds: 2);
    });
    when(() => authRepo.cancel(
          harnessId: _codexId,
          provider: _providerId,
          accountId: any(named: 'accountId'),
          attemptId: any(named: 'attemptId'),
        )).thenAnswer((_) async => const HarnessAuthStatus(
          harness: _codexId,
          provider: _providerId,
          accountId: '',
          accountName: '',
          visibility: harnessAccountVisibilityPersonal,
          credentialMode: 'account',
          status: 'disconnected',
        ));

    await _pumpScreen(tester,
        providerRepo: providerRepo,
        authRepo: authRepo,
        chatRepo: chatRepo,
        launcher: _RecordingLauncher());

    await tester.tap(find.text('Codex'));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    await tester.pump(const Duration(seconds: 2, milliseconds: 100));
    await tester.pump();
    expect(pollCount, greaterThanOrEqualTo(1));

    await tester.tap(find.text('CANCEL'));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    final countAtCancel = pollCount;

    // Enough virtual time for several more ticks, if the timer were still
    // alive.
    await tester.pump(const Duration(seconds: 10));
    await tester.pump();
    expect(pollCount, countAtCancel);
  });

  testWidgets(
      'submitting a code for an app-destination challenge calls the '
      'repository submit with the trimmed code', (tester) async {
    final appChallenge = HarnessAuthStatus(
      harness: _codexId,
      provider: _providerId,
      accountId: '',
      accountName: '',
      visibility: harnessAccountVisibilityPersonal,
      credentialMode: 'account',
      status: 'awaiting_input',
      challenge: HarnessAuthChallenge.fromJson({
        'type': 'browser-code',
        'text': 'legacy prose',
        'kind': 'browser_code',
        'verificationUri': _verificationUri.toString(),
        'codeDestination': 'app',
        'pollIntervalSeconds': 4,
      }),
    );
    when(() => authRepo.start(
          harnessId: _codexId,
          provider: _providerId,
          mode: 'oauth',
          visibility: harnessAccountVisibilityPersonal,
        )).thenAnswer((_) async => appChallenge);
    when(() => authRepo.submit(
          harnessId: _codexId,
          provider: _providerId,
          code: any(named: 'code'),
          accountId: any(named: 'accountId'),
          attemptId: any(named: 'attemptId'),
        )).thenAnswer((_) async => _connected());

    await _pumpScreen(tester,
        providerRepo: providerRepo,
        authRepo: authRepo,
        chatRepo: chatRepo,
        launcher: _RecordingLauncher());

    await tester.tap(find.text('Codex'));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), '  one-time-code  ');
    await tester.tap(find.text('[SUBMIT]'));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    verify(() => authRepo.submit(
          harnessId: _codexId,
          provider: _providerId,
          code: 'one-time-code',
          accountId: any(named: 'accountId'),
          attemptId: any(named: 'attemptId'),
        )).called(1);
  });

  testWidgets(
      'a browser-open failure shows a generic message and leaves cancel '
      'available rather than dead-ending the flow', (tester) async {
    when(() => authRepo.start(
          harnessId: _codexId,
          provider: _providerId,
          mode: 'oauth',
          visibility: harnessAccountVisibilityPersonal,
        )).thenAnswer((_) async => _awaitingChallenge());

    await _pumpScreen(tester,
        providerRepo: providerRepo,
        authRepo: authRepo,
        chatRepo: chatRepo,
        launcher: _RecordingLauncher(result: false));

    await tester.tap(find.text('Codex'));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    await tester.tap(find.text('[OPEN AUTHORIZATION PAGE]'));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('CANCEL'), findsOneWidget);

    await tester.tap(find.text('CANCEL'));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
  });
}
