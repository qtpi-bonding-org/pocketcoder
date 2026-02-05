import 'package:cubit_ui_flow/cubit_ui_flow.dart' as cubit_ui_flow;
import 'package:injectable/injectable.dart';
import 'package:flutter/foundation.dart';

@LazySingleton(as: cubit_ui_flow.IFeedbackService)
class AppFeedbackService implements cubit_ui_flow.IFeedbackService {
  @override
  void show(cubit_ui_flow.FeedbackMessage message) {
    debugPrint('Feedback [${message.type}]: ${message.message}');
  }
}
