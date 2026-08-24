// Regression test for a real crash: AgentLoginAdapter (reached
// during onboarding, before the user has ever visited the chat-list
// screen) reads ChatListCubit via context.read() to auto-create/open the
// first chat once a harness connects. ChatListCubit used to be provided
// ONLY by ChatListScreenAdapter's own scoped BlocProvider -- so reaching
// this screen without first visiting the chat list threw
// ProviderNotFoundException building this exact widget. ChatListCubit is
// now provided app-wide (see App's root MultiBlocProvider in app.dart),
// so this widget must build fine with it available from an ordinary
// ancestor provider, independent of the chat-list screen ever existing.
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
import 'package:pocketcoder_flutter/domain/provider/i_provider_repository.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/adapters/agent_login_adapter.dart';

class MockChatListRepository extends Mock implements IChatListRepository {}

class MockProviderRepository extends Mock implements IProviderRepository {}

class MockHarnessAuthRepository extends Mock
    implements IHarnessAuthRepository {}

HarnessAuthStatus _status(String status) => HarnessAuthStatus(
      harness: 'harness-1',
      accountId: 'acct-1',
      accountName: 'acct',
      visibility: harnessAccountVisibilityPersonal,
      credentialMode: 'account',
      status: status,
    );

void main() {
  testWidgets(
      'builds without ProviderNotFoundException when ChatListCubit is '
      "provided by an ordinary ancestor -- NOT nested under the chat-list "
      "screen's own provider, matching how onboarding actually reaches "
      'this widget before the chat list has ever been visited',
      (tester) async {
    final providerRepo = MockProviderRepository();
    when(() => providerRepo.watchHarnesses())
        .thenAnswer((_) => Stream.value(const []));
    when(() => providerRepo.watchProviderKeys())
        .thenAnswer((_) => Stream.value(const []));

    final harnessAuthCubit = HarnessAuthCubit(
      providerRepository: providerRepo,
      authRepository: MockHarnessAuthRepository(),
    );

    final chatRepo = MockChatListRepository();
    when(() => chatRepo.watchChats()).thenAnswer((_) => const Stream.empty());
    final chatListCubit = ChatListCubit(chatRepo);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<HarnessAuthCubit>.value(value: harnessAuthCubit),
            BlocProvider<ChatListCubit>.value(value: chatListCubit),
          ],
          child: AgentLoginAdapter(
            harnessId: 'harness-1',
            provider: 'anthropic',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);

    await harnessAuthCubit.close();
    await chatListCubit.close();
  });

  testWidgets(
      'a harness reaching connected opens the first chat even though the '
      "cubit's top-level status/error never change across the "
      'transition -- UiFlowListener used to gate its listener callback on '
      'status/error only, so this side effect (which depends on the '
      'per-harness statuses map, not the top-level status) silently never '
      'ran once the harness list had already loaded once',
      (tester) async {
    final harness = Harnesse(
      id: 'harness-1',
      name: 'Harness One',
      cliId: 'harness-1',
      acpTransport: HarnesseAcpTransport.stdio,
    );

    final providerRepo = MockProviderRepository();
    when(() => providerRepo.watchHarnesses())
        .thenAnswer((_) => Stream.value([harness]));
    when(() => providerRepo.watchProviderKeys())
        .thenAnswer((_) => const Stream.empty());

    final authRepo = MockHarnessAuthRepository();
    // The initial post-load refresh (HarnessAuthCubit._refreshStatuses)
    // reports "disconnected" -- this is the emission that already
    // establishes status:success/error:null as the baseline, matching
    // production: submitCode()'s later "connected" emission changes only
    // the statuses map, not status/error.
    when(() => authRepo.status(
          harnessId: 'harness-1',
          accountId: any(named: 'accountId'),
          attemptId: any(named: 'attemptId'),
        )).thenAnswer((_) async => _status('disconnected'));
    when(() => authRepo.submit(
          harnessId: 'harness-1',
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

    // Load the harness list and let the initial "disconnected" refresh
    // settle BEFORE the widget ever mounts -- matching production, where
    // HarnessAuthCubit is provided app-wide and has typically already
    // loaded by the time onboarding reaches this screen. This is what
    // establishes status:success/error:null as the baseline BlocListener
    // captures at its own initState, exactly as it would live.
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
            child: AgentLoginAdapter(
              harnessId: 'harness-1',
              provider: 'anthropic',
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

    // The user submits their auth code; the harness transitions to
    // "connected". The cubit's top-level status/error do not change (they
    // were already success/null) -- only the statuses map does.
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
