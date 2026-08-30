import 'package:flutter/widgets.dart';

abstract interface class IServerControlSetupGate {
  Future<Widget?> resolveSetupScreen({required VoidCallback onSetupComplete});
}
