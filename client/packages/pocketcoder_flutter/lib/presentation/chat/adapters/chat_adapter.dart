import 'dart:async';

import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:pocketcoder_flutter/application/agent/chat_cubit.dart';
import 'package:pocketcoder_flutter/application/agent/chat_state.dart';
import 'package:pocketcoder_flutter/application/agent/elicitation_cubit.dart';
import 'package:pocketcoder_flutter/application/agent/elicitation_state.dart';
import 'package:pocketcoder_flutter/application/agent/permission_cubit.dart';
import 'package:pocketcoder_flutter/application/agent/permission_state.dart';
import 'package:pocketcoder_flutter/application/agent/session_controls_cubit.dart';
import 'package:pocketcoder_flutter/application/agent/session_controls_state.dart';
import 'package:pocketcoder_flutter/application/chat/chat_monitoring_cubit.dart';
import 'package:pocketcoder_flutter/application/chat/chat_monitoring_state.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/agent/elicitation_response.dart';
import 'package:pocketcoder_flutter/domain/edition/i_app_edition.dart';
import 'package:pocketcoder_flutter/domain/live_activities/i_foreground_live_activity_starter.dart';
import 'package:pocketcoder_flutter/infrastructure/core/logger.dart';
import 'package:pocketcoder_flutter/infrastructure/errors/diagnostic_capture.dart';
import 'package:pocketcoder_flutter/presentation/chat/widgets/chat_view.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/vim_toast.dart';
import 'package:pocketcoder_flutter/application/agent/provider_reauthentication_required.dart';

String? chatErrorToastMessage(Object? error) {
  if (error == null || error is ProviderReauthenticationRequired) return null;
  var key = MessageKey.genericError;
  try {
    key = GetIt.instance<IExceptionKeyMapper>().map(error) ?? key;
  } catch (_) {}
  try {
    return GetIt.instance<ILocalizationService>()
        .translate(key.key, args: key.args);
  } catch (_) {
    return key.key;
  }
}

class ChatAdapter extends CubitAdapter<ChatCubit, ChatState> {
  const ChatAdapter({super.key, this.chatId});
  final String? chatId;
  static ChatState _selectState(ChatState state) => state;

  @override
  Widget buildAdapter(
      BuildContext context, CubitAdapterState<ChatCubit, ChatState> adapter) {
    final state = adapter.cubitField(_selectState);
    final chatCubit = context.read<ChatCubit>();
    final controls = context.read<SessionControlsCubit>();
    final monitoring = context.read<ChatMonitoringCubit>();
    final showMonitorAction = GetIt.instance<IAppEdition>().isPro;
    final view = ValueListenableBuilder<ChatState>(
      valueListenable: state,
      builder: (context, value, _) => StreamBuilder<SessionControlsState>(
        stream: controls.stream,
        initialData: controls.state,
        builder: (context, snapshot) {
          final c = snapshot.data ?? controls.state;
          return StreamBuilder<ChatMonitoringState>(
            stream: monitoring.stream,
            initialData: monitoring.state,
            builder: (context, monitoringSnapshot) {
              final m = monitoringSnapshot.data ?? monitoring.state;
              return ChatView(
                chatId: chatId,
                conversation: value.conversation,
                title: value.conversation.sessionState.title ??
                    context.l10n.chatSessionTitle,
                isLoading: value.isLoading,
                awaitingHarnessStart: value.awaitingHarnessStart,
                isRunning: value.conversation.sessionState.isRunning,
                requiresProviderReauthentication:
                    value.error is ProviderReauthenticationRequired,
                config: c.config,
                showMonitorAction: showMonitorAction,
                monitored: m.monitored,
                onOpen: (id) {
                  chatCubit.open(id);
                  context.read<PermissionCubit>().open(id);
                  context.read<ElicitationCubit>().open(id);
                  controls.open(id);
                  monitoring.open(id);
                },
                onToggleMonitored: monitoring.toggle,
                onSendPrompt: chatCubit.sendPrompt,
                onCancel: chatCubit.cancel,
                onSetOption: controls.setOption,
                onSearchModels: controls.searchableModels,
                onPermissionOptionSelected: (requestId,
                    {optionId, cancelled = false}) {
                  final cubit = context.read<PermissionCubit>();
                  if (cancelled || optionId == null) {
                    cubit.deny(requestId: requestId);
                  } else {
                    cubit.authorize(optionId, requestId: requestId);
                  }
                },
                onElicitationRespond: (requestId, response) {
                  final action = response['action'] as String?;
                  final content = response['content'];
                  final result = switch (action) {
                    'accept' => ElicitationResponse.accept(content is Map
                        ? Map<String, dynamic>.from(content)
                        : const {}),
                    'decline' => const ElicitationResponse.decline(),
                    _ => const ElicitationResponse.cancel(),
                  };
                  context.read<ElicitationCubit>().submit(result);
                },
                animatedMessageIds: value.animatedMessageIds,
                onMessageAnimated: chatCubit.markMessageAnimated,
                onFiles: () => AppNavigation.toFiles(context),
                onRunStarted: (id) => _startForegroundActivity(id),
              );
            },
          );
        },
      ),
    );
    return UiFlowListener<ChatCubit, ChatState>(
      listener: (context, value) {
        final message = chatErrorToastMessage(value.error);
        if (message != null) {
          VimToast.show(context, message,
              color: context.terminalColors.warning);
        }
      },
      child: UiFlowListener<PermissionCubit, PermissionState>(
        child: UiFlowListener<ElicitationCubit, ElicitationState>(child: view),
      ),
    );
  }

  Future<void> _startForegroundActivity(String chatId) async {
    // This handler is deliberately optional: pocketcoder_flutter is also
    // used by the FOSS app, which has no proprietary ActivityKit service.
    if (!GetIt.instance.isRegistered<IForegroundLiveActivityStarter>()) {
      return;
    }
    try {
      await GetIt.instance<IForegroundLiveActivityStarter>()
          .startForChat(chatId);
    } catch (error, stackTrace) {
      unawaited(pocketCoderDiagnosticCapture.capture(
        error: error,
        stackTrace: stackTrace,
        source: 'ChatAdapter',
        operation: 'startForegroundLiveActivity',
      ));
      AppLogger.error(
          'Foreground Live Activity start failed', error, stackTrace);
    }
  }
}
