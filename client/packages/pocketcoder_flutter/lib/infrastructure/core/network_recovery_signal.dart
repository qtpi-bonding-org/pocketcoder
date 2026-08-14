import 'dart:async';

import 'package:injectable/injectable.dart';

/// Wake-up hint for operations waiting to retry after a network loss.
/// Consumers still make a real request and handle failure normally.
@lazySingleton
class NetworkRecoverySignal {
  final _controller = StreamController<void>.broadcast();

  Stream<void> get onRecovered => _controller.stream;

  void notifyRecovered() {
    if (!_controller.isClosed) _controller.add(null);
  }
}
