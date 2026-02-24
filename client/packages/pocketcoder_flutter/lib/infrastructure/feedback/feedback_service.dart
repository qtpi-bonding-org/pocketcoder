import 'package:cubit_ui_flow/cubit_ui_flow.dart' as cubit_ui_flow;
import 'package:injectable/injectable.dart';
import 'package:flutter/material.dart';
import '../../app_router.dart';
import '../../presentation/core/widgets/vim_toast.dart';

@LazySingleton(as: cubit_ui_flow.IFeedbackService)
class AppFeedbackService implements cubit_ui_flow.IFeedbackService {
  @override
  void show(cubit_ui_flow.FeedbackMessage message) {
    final state = AppRouter.messengerKey.currentState;
    if (state == null) return;

    state.clearSnackBars();
    state.showSnackBar(
      SnackBar(
        content: VimToast(message: message.message),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
