import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/chat/chat_list_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/chat/i_chat_list_repository.dart';
import 'package:pocketcoder_flutter/domain/models/chat.dart';
import 'package:pocketcoder_flutter/domain/provider/i_provider_repository.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/chat/adapters/chat_list_adapter.dart';
import 'package:pocketcoder_flutter/presentation/chat/new_chat_dialog.dart';

class MockChatListRepository extends Mock implements IChatListRepository {
  @override
  Future<void> recordMessagePreview(String chatId,
      {required String text,
      required ChatTurn turn,
      required bool isFirst}) async {}
}

class MockProviderRepository extends Mock implements IProviderRepository {}

Widget _wrap(ChatListCubit cubit, IProviderRepository providerRepository) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<ChatListCubit>.value(
      value: cubit,
      child: ChatListAdapter(
        providerRepository: providerRepository,
        loadOllamaModels: () async => const [],
      ),
    ),
  );
}

void main() {
  late MockChatListRepository repo;
  late MockProviderRepository providerRepo;

  setUp(() {
    repo = MockChatListRepository();
    when(() => repo.watchChats()).thenAnswer((_) => const Stream.empty());
    // ChatListAdapter.buildAdapter now triggers
    // checkEmptyAndMaybeAutoCreate() itself (via adapter.keep()) rather
    // than relying on the screen's old BlocProvider(create: ...) cascade
    // -- ChatListCubit is provided app-wide now, not freshly created per
    // screen-visit. Stub it as "already has chats" so these tests, which
    // emit their own fixture state directly onto the cubit, don't race an
    // unstubbed hasAnyChats() call auto-creating an unwanted chat.
    when(() => repo.hasAnyChats()).thenAnswer((_) async => true);

    providerRepo = MockProviderRepository();
    getIt.registerSingleton<IProviderRepository>(providerRepo);
    when(() => providerRepo.watchHarnesses())
        .thenAnswer((_) => Stream.value(const []));
    when(() => providerRepo.watchModels())
        .thenAnswer((_) => Stream.value(const []));
    when(() => providerRepo.fetchHarnessModels())
        .thenAnswer((_) async => const []);
    when(() => providerRepo.watchProviderAPIKeys())
        .thenAnswer((_) => Stream.value(const []));
    when(() => providerRepo.watchHarnessProviders())
        .thenAnswer((_) => Stream.value(const []));
  });

  tearDown(() {
    getIt.unregister<IProviderRepository>();
  });

  testWidgets('renders title/preview/relative-time for a populated list',
      (tester) async {
    final cubit = ChatListCubit(repo);
    cubit.emit(cubit.state.copyWith(
      status: UiFlowStatus.success,
      chats: const [
        Chat(
            id: 'chat-1',
            title: 'Hello World',
            user: 'u',
            firstMessage: 'Hello World',
            preview: 'hi there'),
      ],
    ));

    await tester.pumpWidget(_wrap(cubit, providerRepo));
    await tester.pumpAndSettle();

    expect(find.text('Hello World'), findsOneWidget);
    expect(find.text('hi there'), findsOneWidget);
  });

  testWidgets('long-press opens an archive/delete menu that calls the cubit',
      (tester) async {
    when(() => repo.archiveChat('chat-1')).thenAnswer((_) async {});
    final cubit = ChatListCubit(repo);
    cubit.emit(cubit.state.copyWith(
      status: UiFlowStatus.success,
      chats: const [
        Chat(
            id: 'chat-1',
            title: 'Hello World',
            user: 'u',
            firstMessage: 'Hello World'),
      ],
    ));

    await tester.pumpWidget(_wrap(cubit, providerRepo));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Hello World'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('<archive>'));
    await tester.pumpAndSettle();

    verify(() => repo.archiveChat('chat-1')).called(1);
  });

  testWidgets(
      'tapping + NEW CHAT opens NewChatDialog instead of creating immediately',
      (tester) async {
    final cubit = ChatListCubit(repo);
    cubit.emit(
        cubit.state.copyWith(status: UiFlowStatus.success, chats: const []));

    await tester.pumpWidget(_wrap(cubit, providerRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('<new>'));
    await tester.pumpAndSettle();

    expect(find.byType(NewChatDialog), findsOneWidget);
    verifyNever(() => repo.createChat(
          title: any(named: 'title'),
          harness: any(named: 'harness'),
          harnessModelOverride: any(named: 'harnessModelOverride'),
          workspaceOverride: any(named: 'workspaceOverride'),
        ));
  });
}
