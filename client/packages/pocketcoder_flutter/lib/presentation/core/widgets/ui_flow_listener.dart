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
  final bool Function(S previous, S current)? listenWhen;
  final bool showSuccessToasts;
  final String? successMessage;
  final bool autoDismissLoading;

  const UiFlowListener({
    super.key,
    required this.child,
    this.bloc,
    this.mapper,
    this.listener,
    this.listenWhen,
    this.showSuccessToasts = false,
    this.successMessage,
    this.autoDismissLoading = true,
  });

  static bool _defaultListenWhen(IUiFlowState previous, IUiFlowState current) {
    return previous.status != current.status || previous.error != current.error;
  }

  @override
  Widget build(BuildContext context) {
    Widget content = child;

    // The custom `listener` callback often depends on fields other than
    // status/error (a connection-status map, a per-item field, ...) that
    // can change while status/error stay put -- gating it on the same
    // status/error-only condition as the built-in toast/loading handling
    // below silently drops those side effects. A second, independent
    // BlocListener subscribes to the same bloc so the custom callback gets
    // its own previous-state tracking and its own (optionally
    // caller-supplied) listenWhen, entirely decoupled from when the
    // built-in handlers fire.
    final resolvedListener = listener;
    if (resolvedListener != null) {
      content = BlocListener<B, S>(
        bloc: bloc,
        listenWhen: listenWhen ?? _defaultListenWhen,
        listener: (context, state) => resolvedListener(context, state),
        child: content,
      );
    }

    return BlocListener<B, S>(
      bloc: bloc,
      listenWhen: _defaultListenWhen,
      listener: (context, state) {
        _handleLoadingState(state);

        if (mapper != null) {
          _handleMappedState(state);
        } else {
          _handleErrorState(state);
          _handleSuccessState(state);
        }
      },
      child: content,
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
    } catch (_) {}
  }

  void _handleMappedState(S state) {
    final mapper = this.mapper;
    if (mapper == null) return;
    var messageKey = mapper.map(state);

    if (messageKey == null && state.hasError && state.error != null) {
      try {
        final exceptionMapper = GetIt.instance<IExceptionKeyMapper>();
        messageKey = exceptionMapper.map(state.error ?? 'Unknown error');
      } catch (_) {}

      // Never fall back to the raw error's toString() -- for an exception
      // with no mapper entry this renders Dart's default
      // Object.toString() ("Instance of 'X'") or a DomainException's raw
      // internal detail straight to the user. A generic, localized
      // message is always safer than exposing unmapped technical text.
      messageKey ??= MessageKey.genericError;
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

    // Never fall back to the raw error's toString() -- for an exception
    // with no mapper entry this renders Dart's default Object.toString()
    // ("Instance of 'X'") or a DomainException's raw internal detail
    // straight to the user.
    var messageKey = MessageKey.genericError;
    try {
      final exceptionMapper = GetIt.instance<IExceptionKeyMapper>();
      messageKey =
          exceptionMapper.map(state.error ?? 'Unknown error') ?? messageKey;
    } catch (_) {}

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
