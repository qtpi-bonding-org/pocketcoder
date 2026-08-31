import 'dart:async';

import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/application/chat/chat_list_cubit.dart';
import 'package:pocketcoder_flutter/application/harness_auth/harness_auth_cubit.dart';
import 'package:pocketcoder_flutter/application/harness_auth/harness_auth_state.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/harness_auth_models.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/vim_toast.dart';
import 'package:pocketcoder_flutter/presentation/core/in_app_browser_launcher.dart';
import 'package:pocketcoder_flutter/presentation/harness_auth/widgets/harness_auth_view.dart';

class HarnessAuthAdapter
    extends CubitAdapter<HarnessAuthCubit, HarnessAuthState> {
  const HarnessAuthAdapter({
    super.key,
    this.onboarding = false,
    required this.launcher,
  });

  final bool onboarding;
  final InAppBrowserLauncher launcher;

  static HarnessAuthState _selectState(HarnessAuthState state) => state;

  @override
  Widget buildAdapter(
    BuildContext context,
    CubitAdapterState<HarnessAuthCubit, HarnessAuthState> adapter,
  ) {
    final state = adapter.cubitField(_selectState);
    final cubit = context.read<HarnessAuthCubit>();
    // Rechecked on every emission inside the listener below (not here in
    // buildAdapter, which only runs once per mount) so a challenge that
    // arrives after the initial build still starts its poll timer.
    final pollTimers = adapter.keep<Map<String, Timer>>(
      'harnessPollTimers',
      () => <String, Timer>{},
      dispose: (timers) {
        for (final timer in timers.values) {
          timer.cancel();
        }
      },
    );
    final pollIntervals = adapter.keep<Map<String, int>>(
      'harnessPollIntervals',
      () => <String, int>{},
      dispose: (intervals) => intervals.clear(),
    );
    void syncPollTimers(HarnessAuthState value) {
      final awaiting = <String, int>{};
      for (final status in value.statuses.values) {
        final seconds = status.challenge?.pollIntervalSeconds;
        if (status.isConnecting && seconds != null && seconds > 0) {
          awaiting[status.harness] = seconds;
        }
      }
      for (final id in pollTimers.keys.toList()) {
        if (!awaiting.containsKey(id) ||
            pollIntervals[id] != awaiting[id]) {
          pollTimers.remove(id)?.cancel();
          pollIntervals.remove(id);
        }
      }
      for (final entry in awaiting.entries) {
        if (!pollTimers.containsKey(entry.key)) {
          pollIntervals[entry.key] = entry.value;
          pollTimers[entry.key] = Timer.periodic(
            Duration(seconds: entry.value),
            (_) => cubit.poll(entry.key),
          );
        }
      }
    }
    syncPollTimers(state.value);
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
        syncPollTimers(value);
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
          harnessProviders: value.harnessProviders,
          statuses: value.statuses,
          error: value.error,
          isLoading: value.isLoading,
          isHarnessBusy: value.isHarnessBusy,
          onStartAccount: (h, provider) async {
            final visibility = await _chooseVisibility(context);
            if (visibility != null) {
              cubit.startWithAccount(
                  harnessId: h.id, provider: provider, visibility: visibility);
            }
          },
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
          onOpenAuthorizationPage: (h, uri) =>
              _openAuthorizationPage(context, uri),
        ),
      ),
    );
  }

  Future<void> _openAuthorizationPage(BuildContext context, Uri uri) async {
    final opened = await launcher.open(uri);
    if (!opened && context.mounted) {
      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      if (overlay != null) {
        VimToast.showOn(overlay, context.l10n.credentialConnectionOpenFailed,
            type: VimToastType.warning);
      }
    }
  }

  bool _hasConnected(HarnessAuthState state) => state.harnesses
      .where((h) =>
          !onboarding ||
          ['claude-code', 'codex'].contains(h.cliId.trim().toLowerCase()))
      .any((h) =>
          state.statuses.values
              .any((status) => status.harness == h.id && status.isConnected) ==
          true);

  Future<void> _openFirstChat(
    BuildContext context,
    HarnessAuthState state,
    ValueNotifier<bool> openedFirstChat,
  ) async {
    final connected = state.harnesses
        .where((h) =>
            !onboarding ||
            ['claude-code', 'codex'].contains(h.cliId.trim().toLowerCase()))
        .firstWhere((h) =>
            state.statuses.values.any(
                (status) => status.harness == h.id && status.isConnected) ==
            true);
    final router = GoRouter.of(context);
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
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
      if (context.mounted && overlay != null) {
        VimToast.showOn(
          overlay,
          l10n.onboardingOpenChatFailed,
          type: VimToastType.warning,
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
}
