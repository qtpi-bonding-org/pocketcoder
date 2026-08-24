// Regression test for a real crash: HarnessAuthorizationAdapter (reached
// during onboarding, before the user has ever visited the chat-list
// screen) reads ChatListCubit via context.read() to auto-create/open the
// first chat once a harness connects. ChatListCubit used to be provided
// ONLY by ChatListScreenAdapter's own scoped BlocProvider -- so reaching
// this screen without first visiting the chat list threw
// ProviderNotFoundException building this exact widget. ChatListCubit is
// now provided app-wide (see App's root MultiBlocProvider in app.dart),
// so this widget must build fine with it available from an ordinary
// ancestor provider, independent of the chat-list screen ever existing.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/application/chat/chat_list_cubit.dart';
import 'package:pocketcoder_flutter/application/harness_auth/harness_auth_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/chat/i_chat_list_repository.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/i_harness_auth_repository.dart';
import 'package:pocketcoder_flutter/domain/provider/i_provider_repository.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/adapters/harness_authorization_adapter.dart';

class MockChatListRepository extends Mock implements IChatListRepository {}

class MockProviderRepository extends Mock implements IProviderRepository {}

class MockHarnessAuthRepository extends Mock
    implements IHarnessAuthRepository {}

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
          child: HarnessAuthorizationAdapter(
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
}
