// Regression test for the same UiFlowListener listenWhen gap fixed in
// agent_login_adapter_test.dart: HarnessAuthAdapter's connected
// check depends on the per-harness `statuses` map, not the cubit's
// top-level status/error, which stay success/null across a connect
// transition once the harness list has already loaded once. Also covers
// the guard added alongside the fix -- unlike the sibling onboarding
// adapter, this one previously had no one-shot guard at all, so simply
// making the listener fire on every emission (without a guard) would have
// created a new chat on every subsequent "still connected" emission.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/application/chat/chat_list_cubit.dart';
import 'package:pocketcoder_flutter/application/harness_auth/harness_auth_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/chat/i_chat_list_repository.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/harness_auth_models.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/i_harness_auth_repository.dart';
import 'package:pocketcoder_flutter/domain/models/chat.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/harness_provider.dart';
import 'package:pocketcoder_flutter/domain/provider/i_provider_repository.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/harness_auth/adapters/harness_auth_adapter.dart';
import 'package:pocketcoder_flutter/presentation/core/in_app_browser_launcher.dart';

class MockChatListRepository extends Mock implements IChatListRepository {
  @override
  Future<void> recordMessagePreview(String chatId,
      {required String text,
      required ChatTurn turn,
      required bool isFirst}) async {}
}

class MockProviderRepository extends Mock implements IProviderRepository {}

class MockHarnessAuthRepository extends Mock
    implements IHarnessAuthRepository {}

const _providerId = 'provider-1';

HarnessAuthStatus _status(String status) => HarnessAuthStatus(
      harness: 'harness-1',
      provider: _providerId,
      accountId: 'acct-1',
      accountName: 'acct',
      visibility: harnessAccountVisibilityPersonal,
      credentialMode: 'account',
      status: status,
    );

void main() {
  testWidgets(
      'opens the first chat exactly once when a harness reaches connected, '
      'even though status/error never change across the transition, and '
      'does not re-open on a later still-connected emission', (tester) async {
    final harness = Harnesse(
      id: 'harness-1',
      name: 'Claude Code',
      cliId: 'claude-code',
      acpTransport: HarnesseAcpTransport.stdio,
    );

    final providerRepo = MockProviderRepository();
    when(() => providerRepo.watchHarnesses())
        .thenAnswer((_) => Stream.value([harness]));
    when(() => providerRepo.watchHarnessProviders())
        .thenAnswer((_) => Stream.value([
              const HarnessProvider(
                id: 'edge-1',
                harness: 'harness-1',
                provider: _providerId,
                supportsOauth: true,
              ),
            ]));

    final authRepo = MockHarnessAuthRepository();
    when(() => authRepo.status(
          harnessId: 'harness-1',
          provider: any(named: 'provider'),
          accountId: any(named: 'accountId'),
          attemptId: any(named: 'attemptId'),
        )).thenAnswer((_) async => _status('disconnected'));
    when(() => authRepo.submit(
          harnessId: 'harness-1',
          provider: any(named: 'provider'),
          code: any(named: 'code'),
          accountId: any(named: 'accountId'),
          attemptId: any(named: 'attemptId'),
        )).thenAnswer((_) async => _status('connected'));

    final harnessAuthCubit = HarnessAuthCubit(
      providerRepository: providerRepo,
      authRepository: authRepo,
    );

    final chatRepo = MockChatListRepository();
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
    final chatListCubit = ChatListCubit(chatRepo);

    // Establish status:success/error:null as the baseline BEFORE the
    // widget mounts -- matching production, where HarnessAuthCubit is
    // provided app-wide and has typically already loaded.
    harnessAuthCubit.watchData();
    for (var i = 0; i < 5; i++) {
      await Future<void>.value();
    }

    final router = GoRouter(
      initialLocation: '/harness-auth',
      routes: [
        GoRoute(
          path: '/harness-auth',
          builder: (context, state) => MultiBlocProvider(
            providers: [
              BlocProvider<HarnessAuthCubit>.value(value: harnessAuthCubit),
              BlocProvider<ChatListCubit>.value(value: chatListCubit),
            ],
            child: HarnessAuthAdapter(
              onboarding: true,
              launcher: UrlLauncherInAppBrowserLauncher(),
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

    verifyNever(() => chatRepo.createChat(
          title: any(named: 'title'),
          harness: any(named: 'harness'),
          harnessModelOverride: any(named: 'harnessModelOverride'),
          ollamaModelOverride: any(named: 'ollamaModelOverride'),
          workspaceOverride: any(named: 'workspaceOverride'),
        ));

    unawaited(
        harnessAuthCubit.submitCode(harnessId: 'harness-1', code: '123456'));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    // A later emission that still reports the harness as connected (e.g.
    // a duplicate poll tick) must not re-open a second chat.
    unawaited(
        harnessAuthCubit.submitCode(harnessId: 'harness-1', code: '123456'));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    verify(() => chatRepo.createChat(
          title: any(named: 'title'),
          harness: 'harness-1',
          harnessModelOverride: any(named: 'harnessModelOverride'),
          ollamaModelOverride: any(named: 'ollamaModelOverride'),
          workspaceOverride: any(named: 'workspaceOverride'),
        )).called(1);

    await harnessAuthCubit.close();
    await chatListCubit.close();
  });
}
