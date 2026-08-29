import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/application/chat/chat_list_cubit.dart';
import 'package:pocketcoder_flutter/application/chat/chat_list_state.dart';
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/ollama_model.dart';
import 'package:pocketcoder_flutter/domain/models/model.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/i_harness_auth_repository.dart';
import 'package:pocketcoder_flutter/domain/models/credential_selection.dart';
import 'package:pocketcoder_flutter/domain/models/harness_oauth_account.dart';
import 'package:pocketcoder_flutter/domain/models/harness_provider.dart';
import 'package:pocketcoder_flutter/domain/models/provider_api_key.dart';
import 'package:pocketcoder_flutter/domain/provider/i_provider_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/ollama/ollama_api.dart';
import 'package:pocketcoder_flutter/presentation/chat/new_chat_dialog.dart';
import 'package:pocketcoder_flutter/presentation/chat/widgets/chat_list_view.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';

class ChatListAdapter extends CubitAdapter<ChatListCubit, ChatListState> {
  const ChatListAdapter({
    super.key,
    required this.providerRepository,
    required this.loadOllamaModels,
    this.harnessAuthRepository,
  });

  final IProviderRepository providerRepository;
  final Future<List<OllamaModel>> Function() loadOllamaModels;
  final IHarnessAuthRepository? harnessAuthRepository;

  static ChatListState _selectState(ChatListState state) => state;
  static String? _selectCreatedChat(ChatListState state) =>
      state.lastCreatedChatId;

  @override
  Widget buildAdapter(
    BuildContext context,
    CubitAdapterState<ChatListCubit, ChatListState> adapter,
  ) {
    // Runs exactly once per time this screen is reached (adapter.keep()
    // memoizes by key for this adapter's lifetime -- see progress_adapter
    // .dart for the same pattern) -- ChatListCubit is now a single,
    // app-lifetime instance provided at the app root (see App's
    // MultiBlocProvider) rather than freshly created by this screen's own
    // BlocProvider, specifically so onboarding's AgentAuthAdapter
    // can also read it (createAndOpen() for the first-connected-harness's
    // first chat) without needing its own separate instance. Deliberately
    // NOT chained onto the cubit's own creation any more: that now happens
    // at app boot, before login/onboarding ever completes, and
    // checkEmptyAndMaybeAutoCreate() must run against an authenticated
    // session to mean anything.
    adapter.keep<bool>('chatListCubitStarted', () {
      adapter.cubit
        ..watchChats()
        ..checkEmptyAndMaybeAutoCreate();
      return true;
    });
    final state = adapter.cubitField(_selectState);
    final createdChat = adapter.cubitField(_selectCreatedChat);
    adapter.listenTo(#createdChat, createdChat, () {
      final id = createdChat.value;
      if (id != null && id.isNotEmpty && context.mounted) {
        context.push('${AppRoutes.chat}/$id');
      }
    });
    final cubit = context.read<ChatListCubit>();
    return UiFlowListener<ChatListCubit, ChatListState>(
      child: ValueListenableBuilder<ChatListState>(
        valueListenable: state,
        builder: (context, value, _) => ChatListView(
          state: value,
          onNewChat: () async {
            final selection = await _openNewChatDialog(
              context,
              providerRepository: providerRepository,
              harnessAuthRepository: harnessAuthRepository,
              loadOllamaModels: loadOllamaModels,
            );
            if (selection == null) return;
            await cubit.createAndOpen(
              title: selection.title,
              harness: selection.harness,
              harnessModelOverride: selection.harnessModelOverride,
              ollamaModelOverride: selection.ollamaModelOverride,
              workspaceOverride: selection.workspaceOverride,
            );
          },
          onOpen: (id) => context.push('${AppRoutes.chat}/$id'),
          onArchive: cubit.archive,
          onDelete: cubit.delete,
        ),
      ),
    );
  }

  Future<NewChatSelection?> _openNewChatDialog(
    BuildContext context, {
    required IProviderRepository providerRepository,
    required IHarnessAuthRepository? harnessAuthRepository,
    required Future<List<OllamaModel>> Function() loadOllamaModels,
  }) async {
    final futures = await Future.wait<Object>([
      providerRepository.watchHarnesses().first,
      providerRepository.watchModels().first,
      providerRepository.watchHarnessModels().first,
      providerRepository.watchProviderAPIKeys().first,
      providerRepository.watchHarnessProviders().first,
      if (harnessAuthRepository != null)
        harnessAuthRepository.watchCredentialSelections().first,
      if (harnessAuthRepository != null)
        harnessAuthRepository.watchHarnessOAuthAccounts().first,
      loadOllamaModels(),
    ]);
    final harnesses = futures[0] as List<Harnesse>;
    final models = futures[1] as List<Model>;
    final harnessModels = futures[2] as List<HarnessModel>;
    final providerAPIKeys = futures[3] as List<ProviderApiKey>;
    final harnessProviders = futures[4] as List<HarnessProvider>;
    var index = 5;
    final credentialSelections = harnessAuthRepository == null
        ? const <CredentialSelection>[]
        : futures[index++] as List<CredentialSelection>;
    final harnessOAuthAccounts = harnessAuthRepository == null
        ? const <HarnessOauthAccount>[]
        : futures[index++] as List<HarnessOauthAccount>;
    final ollamaModels = futures[index] as List<OllamaModel>;

    if (!context.mounted) {
      return null;
    }

    return showDialog<NewChatSelection>(
      context: context,
      builder: (_) => NewChatDialog(
        harnesses: harnesses,
        models: models,
        harnessModels: harnessModels,
        harnessProviders: harnessProviders,
        providerAPIKeys: providerAPIKeys,
        credentialSelections: credentialSelections,
        harnessOAuthAccounts: harnessOAuthAccounts,
        ollamaModels: ollamaModels,
      ),
    );
  }
}

class ChatListScreenAdapter extends StatelessWidget {
  const ChatListScreenAdapter({super.key});

  @override
  Widget build(BuildContext context) {
    return ChatListAdapter(
      providerRepository: getIt<IProviderRepository>(),
      harnessAuthRepository: getIt<IHarnessAuthRepository>(),
      loadOllamaModels: getIt<OllamaApi>().listModels,
    );
  }
}
