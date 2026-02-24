import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';

/// Reusable listener wrapper that handles global UI concerns for async operations.
class UiFlowListener<B extends StateStreamable<S>, S extends IUiFlowState>
    extends StatelessWidget {
  final Widget child;
  final B? bloc;
  final IStateMessageMapper<S>? mapper;
  final void Function(BuildContext context, S state)? listener;
  final bool showSuccessToasts;
  final String? successMessage;
  final bool autoDismissLoading;

  const UiFlowListener({
    super.key,
    required this.child,
    this.bloc,
    this.mapper,
    this.listener,
    this.showSuccessToasts = false,
    this.successMessage,
    this.autoDismissLoading = true,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<B, S>(
      bloc: bloc,
      listenWhen: (previous, current) {
        return previous.status != current.status ||
            previous.error != current.error;
      },
      listener: (context, state) {
        _handleLoadingState(state);

        if (mapper != null) {
          _handleMappedState(state);
        } else {
          _handleErrorState(state);
          _handleSuccessState(state);
        }

        listener?.call(context, state);
      },
      child: child,
    );
  }

  void _handleLoadingState(S state) {
    if (!autoDismissLoading) return;
    try {
      final loadingService = GetIt.instance<ILoadingService>();
      if (state.isLoading) {
        loadingService.show();
      } else {
        loadingService.hide();
      }
    } catch (_) {
      // Service might not be registered
    }
  }

  void _handleMappedState(S state) {
    var messageKey = mapper!.map(state);

    if (messageKey == null && state.hasError && state.error != null) {
      try {
        final exceptionMapper = GetIt.instance<IExceptionKeyMapper>();
        messageKey = exceptionMapper.map(state.error!);
      } catch (_) {}

      messageKey ??= MessageKey.error(
        state.error.toString(),
      );
    }

    if (messageKey == null) return;

    String message;
    try {
      final localization = GetIt.instance<ILocalizationService>();
      message = localization.translate(messageKey.key, args: messageKey.args);
    } catch (_) {
      message = messageKey.key;
    }

    final feedbackService = GetIt.instance<IFeedbackService>();
    feedbackService.show(FeedbackMessage(
      message: message,
      type: messageKey.type,
    ));
  }

  void _handleErrorState(S state) {
    if (state.error == null) return;

    String message = state.error.toString();
    try {
      final exceptionMapper = GetIt.instance<IExceptionKeyMapper>();
      final messageKey = exceptionMapper.map(state.error!);
      if (messageKey != null) {
        try {
          final localization = GetIt.instance<ILocalizationService>();
          message =
              localization.translate(messageKey.key, args: messageKey.args);
        } catch (_) {
          message = messageKey.key;
        }
      }
    } catch (_) {}

    final feedbackService = GetIt.instance<IFeedbackService>();
    feedbackService.show(FeedbackMessage(
      message: message,
      type: MessageType.error,
    ));
  }

  void _handleSuccessState(S state) {
    if (!showSuccessToasts || !state.isSuccess) return;

    final feedbackService = GetIt.instance<IFeedbackService>();
    feedbackService.show(FeedbackMessage(
      message: successMessage ?? 'Operation completed successfully',
      type: MessageType.success,
    ));
  }
}
