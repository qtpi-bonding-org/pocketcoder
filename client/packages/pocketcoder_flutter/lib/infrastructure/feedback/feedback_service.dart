import 'package:cubit_ui_flow/cubit_ui_flow.dart' as cubit_ui_flow;
import 'package:injectable/injectable.dart';
import 'package:flutter/material.dart';
import '../../app_router.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/vim_toast.dart';

@LazySingleton(as: cubit_ui_flow.IFeedbackService)
class AppFeedbackService implements cubit_ui_flow.IFeedbackService {
  @override
  void show(cubit_ui_flow.FeedbackMessage message) {
    final state = AppRouter.messengerKey.currentState;
    if (state == null) return;
    final overlay = Overlay.maybeOf(
      state.context,
      rootOverlay: true,
    );
    if (overlay == null) return;
    VimToast.showOn(
      overlay,
      message.message,
      type: switch (message.type) {
        cubit_ui_flow.MessageType.success => VimToastType.success,
        cubit_ui_flow.MessageType.warning => VimToastType.warning,
        cubit_ui_flow.MessageType.error => VimToastType.warning,
        _ => VimToastType.info,
      },
    );
  }
}
