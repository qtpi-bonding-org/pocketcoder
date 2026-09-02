// Regression tests for the multi-provider/non-oauth harness path (Goose,
// OpenCode): _oauthProviderFor returns null for these harnesses by design
// (no single oauth-capable harness_providers edge), and the onboarding
// picker previously just returned silently with zero UI feedback --
// tapping the harness looked like nothing happened. It should instead
// authenticate via a plain provider_api_keys credential (mode: none, which
// is synchronous server-side -- see harness_auth.go's StartHarnessAuth,
// there is no connecting/polling phase), prompting for an API key only when
// one doesn't already exist.
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
import 'package:pocketcoder_flutter/domain/models/provider.dart' as domain;
import 'package:pocketcoder_flutter/domain/models/provider_api_key.dart';
import 'package:pocketcoder_flutter/domain/provider/i_provider_repository.dart';
import 'package:pocketcoder_flutter/domain/release/server_release_status.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/release_status_banner.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/adapters/agent_auth_adapter.dart';
import 'package:pocketcoder_flutter/presentation/core/in_app_browser_launcher.dart';
import 'package:pocketcoder_flutter/presentation/provider/widgets/provider_widgets.dart';

class MockProviderRepository extends Mock implements IProviderRepository {}

class MockHarnessAuthRepository extends Mock
    implements IHarnessAuthRepository {}

class MockChatListRepository extends Mock implements IChatListRepository {
  @override
  Future<void> recordMessagePreview(String chatId,
      {required String text,
      required ChatTurn turn,
      required bool isFirst}) async {}
}

const _gooseId = 'goose-1';
const _providerId = 'provider-anthropic';

Harnesse _goose() => const Harnesse(
      id: _gooseId,
      name: 'Goose',
      cliId: 'goose',
      acpTransport: HarnesseAcpTransport.websocket,
      providerFanout: true,
    );

HarnessAuthStatus _noneStatus() => const HarnessAuthStatus(
      harness: _gooseId,
      provider: _providerId,
      accountId: '',
      accountName: '',
      visibility: harnessAccountVisibilityPersonal,
      credentialMode: 'none',
      status: 'disconnected',
    );

/// Builds the widget tree with real cubits wired to mocked repositories,
/// exactly the wiring AgentAuthScreen assembles in production, but without
/// going through getIt so the test controls every dependency directly.
Future<void> _pumpScreen(
  WidgetTester tester, {
  required MockProviderRepository providerRepo,
  required MockHarnessAuthRepository authRepo,
  required MockChatListRepository chatRepo,
}) async {
  final router = GoRouter(
    initialLocation: '/harness-auth',
    routes: [
      GoRoute(
        path: '/harness-auth',
        builder: (context, state) => MultiBlocProvider(
          providers: [
            BlocProvider(
                create: (_) => ProviderCubit(providerRepo)..watchAll()),
            BlocProvider(
              create: (_) => HarnessAuthCubit(
                providerRepository: providerRepo,
                authRepository: authRepo,
              )..watchData(),
            ),
            BlocProvider(create: (_) => ChatListCubit(chatRepo)),
          ],
          child: ReleaseStatusScope(
            state: ReleaseStatusState(
              snapshot: const ServerReleaseStatusSnapshot(
                status: ServerReleaseStatus.current,
                currentVersion: '1',
                currentDataVersion: 1,
                currentReleaseDigest: 'digest',
                checkedAt: null,
                selectedHarnesses: ['goose'],
              ),
            ),
            onDismiss: () {},
            child: AgentAuthAdapter(launcher: _AlwaysOpenLauncher()),
          ),
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
    MaterialApp.router(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
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

  setUpAll(() {
    registerFallbackValue(const ProviderApiKey(
      id: '',
      owner: '',
      provider: '',
      apiKey: '',
    ));
  });

  setUp(() {
    providerRepo = MockProviderRepository();
    authRepo = MockHarnessAuthRepository();
    chatRepo = MockChatListRepository();

    when(() => providerRepo.watchHarnesses())
        .thenAnswer((_) => Stream.value([_goose()]));
    when(() => providerRepo.watchModels())
        .thenAnswer((_) => const Stream.empty());
    when(() => providerRepo.fetchHarnessModels())
        .thenAnswer((_) async => const []);
    when(() => providerRepo.watchHarnessProviders())
        .thenAnswer((_) => Stream.value([
              const HarnessProvider(
                id: 'edge-1',
                harness: _gooseId,
                provider: _providerId,
                supportsOauth: false,
              ),
            ]));
    when(() => providerRepo.watchProviderCatalog())
        .thenAnswer((_) => Stream.value([
              const domain.Provider(
                id: _providerId,
                providerId: 'anthropic',
                name: 'Anthropic',
              ),
            ]));

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
  });

  testWidgets(
      'a multi-provider harness with an existing API key skips the dialog '
      'entirely and goes straight to chat', (tester) async {
    when(() => providerRepo.watchProviderAPIKeys())
        .thenAnswer((_) => Stream.value([
              const ProviderApiKey(
                id: 'key-1',
                owner: 'u1',
                provider: _providerId,
                apiKey: 'sk-existing',
              ),
            ]));
    when(() => authRepo.start(
          harnessId: _gooseId,
          provider: _providerId,
          mode: 'none',
          visibility: harnessAccountVisibilityPersonal,
        )).thenAnswer((_) async => _noneStatus());

    await _pumpScreen(tester,
        providerRepo: providerRepo, authRepo: authRepo, chatRepo: chatRepo);

    expect(find.text('Goose'), findsOneWidget);
    await tester.tap(find.text('Goose'));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(find.byType(ProviderKeyEditorDialog), findsNothing);
    verify(() => authRepo.start(
          harnessId: _gooseId,
          provider: _providerId,
          mode: 'none',
          visibility: harnessAccountVisibilityPersonal,
        )).called(1);

    await tester.tap(find.text('NEXT'));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    verify(() => chatRepo.createChat(
          title: any(named: 'title'),
          harness: _gooseId,
          harnessModelOverride: any(named: 'harnessModelOverride'),
          ollamaModelOverride: any(named: 'ollamaModelOverride'),
          workspaceOverride: any(named: 'workspaceOverride'),
        )).called(1);
    expect(find.text('chat-screen:chat-1'), findsOneWidget);
  });

  testWidgets(
      'a multi-provider harness with no existing API key opens the key '
      'editor instead of silently doing nothing', (tester) async {
    when(() => providerRepo.watchProviderAPIKeys())
        .thenAnswer((_) => Stream.value(const []));

    await _pumpScreen(tester,
        providerRepo: providerRepo, authRepo: authRepo, chatRepo: chatRepo);

    expect(find.text('Goose'), findsOneWidget);
    await tester.tap(find.text('Goose'));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(find.byType(ProviderKeyEditorDialog), findsOneWidget);
    verifyNever(() => authRepo.start(
          harnessId: any(named: 'harnessId'),
          provider: any(named: 'provider'),
          mode: any(named: 'mode'),
          visibility: any(named: 'visibility'),
        ));
  });

  testWidgets(
      'saving a newly entered API key starts none-mode auth for the chosen '
      'provider and proceeds to chat', (tester) async {
    when(() => providerRepo.watchProviderAPIKeys())
        .thenAnswer((_) => Stream.value(const []));
    when(() => providerRepo.saveProviderAPIKey(any())).thenAnswer((_) async {});
    when(() => authRepo.start(
          harnessId: _gooseId,
          provider: _providerId,
          mode: 'none',
          visibility: harnessAccountVisibilityPersonal,
        )).thenAnswer((_) async => _noneStatus());

    await _pumpScreen(tester,
        providerRepo: providerRepo, authRepo: authRepo, chatRepo: chatRepo);

    await tester.tap(find.text('Goose'));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    expect(find.byType(ProviderKeyEditorDialog), findsOneWidget);

    // Only one provider is in the catalog for this harness -- pick it via
    // the target-picker's search dialog, matching how the existing
    // provider-management screen drives the same widget.
    await tester.tap(find.text('SELECT PROVIDER'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ANTHROPIC'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'sk-test-key');
    await tester.tap(find.text('SAVE'));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    final saved = verify(() => providerRepo.saveProviderAPIKey(captureAny()))
        .captured
        .single as ProviderApiKey;
    expect(saved.provider, _providerId);
    expect(saved.apiKey, 'sk-test-key');
    verify(() => authRepo.start(
          harnessId: _gooseId,
          provider: _providerId,
          mode: 'none',
          visibility: harnessAccountVisibilityPersonal,
        )).called(1);

    await tester.tap(find.text('NEXT'));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    verify(() => chatRepo.createChat(
          title: any(named: 'title'),
          harness: _gooseId,
          harnessModelOverride: any(named: 'harnessModelOverride'),
          ollamaModelOverride: any(named: 'ollamaModelOverride'),
          workspaceOverride: any(named: 'workspaceOverride'),
        )).called(1);
  });
}

class _AlwaysOpenLauncher implements InAppBrowserLauncher {
  @override
  Future<bool> open(Uri uri) async => true;
}
