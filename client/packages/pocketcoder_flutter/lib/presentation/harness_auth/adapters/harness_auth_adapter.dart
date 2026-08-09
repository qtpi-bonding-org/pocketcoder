import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/application/chat/chat_list_cubit.dart';
import 'package:pocketcoder_flutter/application/harness_auth/harness_auth_cubit.dart';
import 'package:pocketcoder_flutter/application/harness_auth/harness_auth_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/vim_toast.dart';
import 'package:pocketcoder_flutter/presentation/harness_auth/widgets/harness_auth_view.dart';

class HarnessAuthAdapter
    extends CubitAdapter<HarnessAuthCubit, HarnessAuthState> {
  const HarnessAuthAdapter({super.key, this.onboarding = false});

  final bool onboarding;

  static HarnessAuthState _selectState(HarnessAuthState state) => state;

  @override
  Widget buildAdapter(
    BuildContext context,
    CubitAdapterState<HarnessAuthCubit, HarnessAuthState> adapter,
  ) {
    final state = adapter.cubitField(_selectState);
    final cubit = context.read<HarnessAuthCubit>();
    return UiFlowListener<HarnessAuthCubit, HarnessAuthState>(
      listener: (context, value) {
        if (onboarding && _hasConnected(value)) {
          _openFirstChat(context, value);
        }
      },
      child: ValueListenableBuilder<HarnessAuthState>(
        valueListenable: state,
        builder: (context, value, _) => HarnessAuthScreenView(
          onboarding: onboarding,
          harnesses: value.harnesses,
          providerKeys: value.providerKeys,
          statuses: value.statuses,
          error: value.error,
          isLoading: value.isLoading,
          isHarnessBusy: value.isHarnessBusy,
          onStartAccount: (h) {
            final provider = h.cliId.trim();
            if (provider.isEmpty) {
              _showError(context,
                  'This harness does not expose a provider identifier.');
            } else {
              cubit.startWithAccount(harnessId: h.id, provider: provider);
            }
          },
          onStartApiKey: (h) => _startApiKey(context, cubit, h),
          onStartNone: (h) => cubit.startWithNone(h.id),
          onPoll: (h) => cubit.poll(h.id),
          onSubmit: (h, code) => cubit.submitCode(harnessId: h.id, code: code),
          onCancel: (h) => cubit.cancel(h.id),
          onDisconnect: (h) => cubit.disconnect(h.id),
          onRefresh: (h) => cubit.refreshHarness(h.id),
        ),
      ),
    );
  }

  bool _hasConnected(HarnessAuthState state) => state.harnesses
      .where((h) =>
          !onboarding ||
          ['claude-code', 'codex'].contains(h.cliId.trim().toLowerCase()))
      .any((h) => state.statuses[h.id]?.isConnected == true);

  Future<void> _openFirstChat(
      BuildContext context, HarnessAuthState state) async {
    final connected = state.harnesses
        .where((h) =>
            !onboarding ||
            ['claude-code', 'codex'].contains(h.cliId.trim().toLowerCase()))
        .firstWhere((h) => state.statuses[h.id]?.isConnected == true);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      final chats = context.read<ChatListCubit>();
      await chats.createAndOpen(harness: connected.id);
      final chatId = chats.state.lastCreatedChatId;
      if (!context.mounted || chatId == null || chatId.isEmpty) return;
      router.go('${AppRoutes.chat}/$chatId');
    } catch (error) {
      if (context.mounted) {
        VimToast.showOn(
            messenger, l10n.onboardingOpenChatFailed(error.toString()));
      }
    }
  }

  Future<void> _startApiKey(
    BuildContext context,
    HarnessAuthCubit cubit,
    Harnesse harness,
  ) async {
    final matching =
        cubit.providerKeysForHarness(harness.cliId.trim().toLowerCase());
    if (matching.isEmpty) {
      _showError(context, 'No provider key found for ${harness.cliId}.');
      return;
    }
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => TerminalDialog(
        title: 'Choose provider key',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final key in matching)
              ListTile(
                title: Text(key.id),
                subtitle: Text(key.provider.toUpperCase()),
                onTap: () => Navigator.of(dialogContext).pop(key.id),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (selected != null && context.mounted) {
      cubit.startWithApiKey(harnessId: harness.id, providerKey: selected);
    }
  }

  void _showError(BuildContext context, String message) {
    VimToast.show(context, message, color: context.colorScheme.error);
  }
}
