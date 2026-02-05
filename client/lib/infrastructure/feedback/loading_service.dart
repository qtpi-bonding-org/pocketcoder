import 'package:cubit_ui_flow/cubit_ui_flow.dart' as cubit_ui_flow;
import 'package:injectable/injectable.dart';
import 'package:flutter/foundation.dart';

@LazySingleton(as: cubit_ui_flow.ILoadingService)
class AppLoadingService implements cubit_ui_flow.ILoadingService {
  @override
  void show() {
    debugPrint('Loading: show');
  }

  @override
  void hide() {
    debugPrint('Loading: hide');
  }
}
