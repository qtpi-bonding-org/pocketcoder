import 'dart:async';
import 'push_service.dart';

class MockPushService implements PushService {
  final _controller = StreamController<PushNotificationPayload>.broadcast();

  @override
  Future<void> initialize() async {
    // ignore: avoid_print
    print("MockPushService initialized");
  }

  @override
  Future<String?> getToken() async => "mock_token";

  @override
  Stream<PushNotificationPayload> get notificationStream => _controller.stream;

  @override
  Future<bool> requestPermissions() async => true;
}
