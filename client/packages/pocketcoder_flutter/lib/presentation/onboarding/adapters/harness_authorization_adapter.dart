import 'dart:async';

import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/application/chat/chat_list_cubit.dart';
import 'package:pocketcoder_flutter/application/chat/chat_list_state.dart';
import 'package:pocketcoder_flutter/application/harness_auth/harness_auth_cubit.dart';
import 'package:pocketcoder_flutter/application/harness_auth/harness_auth_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/vim_toast.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/widgets/harness_authorization_view.dart';
import 'package:pocketcoder_flutter/support/onboarding_logger.dart';
import 'package:url_launcher/url_launcher.dart';

class HarnessAuthorizationAdapter
    extends CubitAdapter<HarnessAuthCubit, HarnessAuthState> {
  const HarnessAuthorizationAdapter({
    super.key,
    required this.harnessId,
    required this.provider,
  });

  final String harnessId;
  final String provider;

  static HarnessAuthState _selectState(HarnessAuthState state) => state;

  @override
  Widget buildAdapter(
    BuildContext context,
    CubitAdapterState<HarnessAuthCubit, HarnessAuthState> adapter,
  ) {
    final state = adapter.cubitField(_selectState);
    final cubit = context.read<HarnessAuthCubit>();
    final chats = context.read<ChatListCubit>();
    var openedChat = false;
    Timer? pollTimer;

    Future<void> openFirstChat(BuildContext listenerContext) async {
      if (openedChat) return;
      openedChat = true;
      OnboardingLogger.event('harness connected; creating first chat', {
        'harness': harnessId,
      });
      try {
        await chats.createAndOpen(harness: harnessId);
        final chatId = chats.state.lastCreatedChatId;
        if (!listenerContext.mounted || chatId == null || chatId.isEmpty) {
          return;
        }
        OnboardingLogger.event('first chat created; entering chat', {
          'harness': harnessId,
        });
        listenerContext.go('${AppRoutes.chat}/$chatId');
      } catch (error) {
        openedChat = false;
        OnboardingLogger.event('first chat creation failed', {
          'harness': harnessId,
          'error': error.toString(),
        });
        if (listenerContext.mounted) {
          VimToast.show(
            listenerContext,
            listenerContext.l10n.onboardingOpenChatFailed(error.toString()),
            color: listenerContext.colorScheme.error,
          );
        }
      }
    }

    return UiFlowListener<HarnessAuthCubit, HarnessAuthState>(
      listener: (listenerContext, nextState) {
        final status = nextState.statuses[harnessId];
        if (status?.isConnected == true) {
          OnboardingLogger.event('harness authorization connected', {
            'harness': harnessId,
            'provider': provider,
          });
          unawaited(openFirstChat(listenerContext));
        } else if (status?.isConnecting == true) {
          pollTimer ??= Timer(const Duration(seconds: 1), () {
            pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
              if (!cubit.state.isBusy) unawaited(cubit.poll(harnessId));
            });
            if (!cubit.state.isBusy) unawaited(cubit.poll(harnessId));
          });
        }
      },
      child: ValueListenableBuilder<HarnessAuthState>(
        valueListenable: state,
        builder: (context, value, _) => StreamBuilder<ChatListState>(
          initialData: chats.state,
          stream: chats.stream,
          builder: (context, _) => HarnessAuthorizationView(
            harnessId: harnessId,
            provider: provider,
            isLoading: value.isLoading,
            harnessExists: value.harnesses.any((h) => h.id == harnessId),
            status: value.statuses[harnessId],
            isBusy: value.isHarnessBusy(harnessId),
            onPoll: () => cubit.poll(harnessId),
            onSubmit: (code) => cubit.submitCode(
              harnessId: harnessId,
              code: code,
            ),
            onStartLogin: () => cubit.startWithAccount(
              harnessId: harnessId,
              provider: provider,
            ),
            onOpenChallenge: (challenge) {
              final target = challenge.target;
              if (target == null || target.isEmpty) return;
              OnboardingLogger.event('authorization challenge opened', {
                'type': challenge.type,
              });
              launchUrl(
                Uri.tryParse(target) ?? Uri(),
                mode: LaunchMode.externalApplication,
              );
            },
          ),
        ),
      ),
    );
  }
}
