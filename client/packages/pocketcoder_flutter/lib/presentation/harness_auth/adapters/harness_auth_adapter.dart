import 'dart:async';

import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/application/chat/chat_list_cubit.dart';
import 'package:pocketcoder_flutter/application/harness_auth/harness_auth_cubit.dart';
import 'package:pocketcoder_flutter/application/harness_auth/harness_auth_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/harness_auth_models.dart';
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
    // Whether a harness is connected lives in the per-harness `statuses`
    // map, not the cubit's top-level status/error -- those routinely stay
    // success/null across a connect/poll transition, so this must fire on
    // every emission (see UiFlowListener's listenWhen doc). `openedFirstChat`
    // is the one-shot guard that then keeps a persisted-connected state
    // from re-triggering chat creation on every later emission.
    final openedFirstChat = adapter.keep<ValueNotifier<bool>>(
      'openedFirstChat',
      () => ValueNotifier(false),
      dispose: (notifier) => notifier.dispose(),
    );
    return UiFlowListener<HarnessAuthCubit, HarnessAuthState>(
      listenWhen: (_, __) => true,
      listener: (context, value) {
        if (onboarding && !openedFirstChat.value && _hasConnected(value)) {
          openedFirstChat.value = true;
          unawaited(_openFirstChat(context, value, openedFirstChat));
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
          onStartAccount: (h) async {
            final provider = h.cliId.trim();
            if (provider.isEmpty) {
              _showError(context,
                  'This harness does not expose a provider identifier.');
            } else {
              final visibility = await _chooseVisibility(context);
              if (visibility != null) {
                cubit.startWithAccount(
                  harnessId: h.id,
                  provider: provider,
                  visibility: visibility,
                );
              }
            }
          },
          onStartApiKey: (h) => _startApiKey(context, cubit, h),
          onStartNone: (h) async {
            final visibility = await _chooseVisibility(context);
            if (visibility != null) {
              cubit.startWithNone(h.id, visibility: visibility);
            }
          },
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
    BuildContext context,
    HarnessAuthState state,
    ValueNotifier<bool> openedFirstChat,
  ) async {
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
    } catch (_) {
      // Retryable on the next connected emission, not permanently locked
      // out by one failed attempt.
      openedFirstChat.value = false;
      if (context.mounted) {
        VimToast.showOn(messenger, l10n.onboardingOpenChatFailed);
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
      _showError(
          context, context.l10n.harnessAuthProviderKeyMissing(harness.cliId));
      return;
    }
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => TerminalDialog(
        title: context.l10n.harnessAuthChooseProviderKey,
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
            child: Text(context.l10n.actionCancel),
          ),
        ],
      ),
    );
    if (selected != null && context.mounted) {
      final visibility = await _chooseVisibility(context);
      if (visibility != null) {
        cubit.startWithApiKey(
          harnessId: harness.id,
          providerKey: selected,
          visibility: visibility,
        );
      }
    }
  }

  Future<String?> _chooseVisibility(BuildContext context) => showDialog<String>(
        context: context,
        builder: (dialogContext) => TerminalDialog(
          title: context.l10n.harnessAuthVisibilityTitle,
          content: Text(context.l10n.harnessAuthVisibilityBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext)
                  .pop(harnessAccountVisibilityPersonal),
              child: Text(context.l10n.harnessAuthPersonal),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext)
                  .pop(harnessAccountVisibilityDeployment),
              child: Text(context.l10n.harnessAuthShared),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.l10n.actionCancel),
            ),
          ],
        ),
      );

  void _showError(BuildContext context, String message) {
    VimToast.show(context, message, color: context.terminalColors.warning);
  }
}
