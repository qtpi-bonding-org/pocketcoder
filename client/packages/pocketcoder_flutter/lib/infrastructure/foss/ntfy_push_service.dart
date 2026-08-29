import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:pocketcoder_flutter/domain/notifications/push_service.dart';
import 'package:pocketcoder_flutter/domain/notifications/i_device_repository.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart' as cubit_ui_flow;
import 'package:get_it/get_it.dart';
import 'package:unifiedpush/unifiedpush.dart';
import 'package:device_info_plus/device_info_plus.dart';

class NtfyPushService implements PushService {
  final _controller = StreamController<PushNotificationPayload>.broadcast();
  static const String instance = "pocketcoder_relay";
  String? _endpoint;

  @override
  Future<void> initialize() async {
    await UnifiedPush.initialize(
      onNewEndpoint: _onNewEndpoint,
      onRegistrationFailed: _onRegistrationFailed,
      onUnregistered: _onUnregistered,
      onMessage: _onMessage,
      onTempUnavailable: _onTempUnavailable,
    );

    final success = await UnifiedPush.tryUseCurrentOrDefaultDistributor();
    if (success) {
      await UnifiedPush.register(instance: instance);
    } else {
      // ignore: avoid_print
      print(
          "No UnifiedPush distributor found. Please install a distributor like ntfy.");
    }
  }

  void _onNewEndpoint(PushEndpoint endpoint, String instanceId) {
    if (instanceId != instance) return;
    _endpoint = endpoint.url;
    _registerDevice(endpoint.url);
  }

  Future<void> _registerDevice(String token) async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      String deviceName = "PocketCoder Device";

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceName = "${androidInfo.manufacturer} ${androidInfo.model}";
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceName = iosInfo.name;
      }

      final repo = GetIt.I<IDeviceRepository>();
      await repo.registerDevice(
        name: deviceName,
        pushToken: token,
        pushService: "unifiedpush",
      );
    } catch (e) {
      // ignore: avoid_print
      print("🔔 [Notifications] Registration failed: $e");
    }
  }

  void _onRegistrationFailed(FailedReason reason, String instanceId) {}

  void _onUnregistered(String instanceId) {}

  void _onTempUnavailable(String instanceId) {}

  void _onMessage(PushMessage message, String instanceId) {
    if (instanceId != instance) return;

    try {
      final payloadStr = utf8.decode(message.content);
      final data = json.decode(payloadStr) as Map<String, dynamic>;

      _controller.add(PushNotificationPayload(
        title: data['title'] ?? 'Permission Request',
        body: data['message'] ?? 'Action required',
        data: Map<String, dynamic>.from(data),
        wasTapped: false,
      ));
    } catch (e) {
      // ignore: avoid_print
      print("Error parsing UnifiedPush message: $e");
    }
  }

  @override
  Future<String?> getToken() async => null;

  @override
  Stream<PushNotificationPayload> get notificationStream => _controller.stream;

  @override
  Future<PushNotificationPayload?> getInitialNotification() async => null;

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<void> syncAuthenticatedDevice() async {
    final endpoint = _endpoint;
    if (endpoint != null && endpoint.isNotEmpty) {
      await _registerDevice(endpoint);
      return;
    }
    await UnifiedPush.register(instance: instance);
  }

  @override
  Future<void> unregisterAuthenticatedDevice() async {
    final endpoint = _endpoint;
    if (endpoint == null || endpoint.isEmpty) return;
    try {
      await GetIt.I<IDeviceRepository>().unregisterDevice(endpoint);
    } catch (error) {
      // Best effort: logout must remain available if the deployment is down.
      // ignore: avoid_print
      print('[PocketCoder] UnifiedPush device cleanup deferred: $error');
    }
  }

  @override
  Future<void> configure() async {
    final success = await UnifiedPush.tryUseCurrentOrDefaultDistributor();
    if (success) {
      await UnifiedPush.register(instance: instance);
    } else {
      final distributors = await UnifiedPush.getDistributors();
      if (distributors.isNotEmpty) {
        final distributor = distributors.first;
        await UnifiedPush.saveDistributor(distributor);
        await UnifiedPush.register(instance: instance);

        try {
          final feedback = GetIt.I<cubit_ui_flow.IFeedbackService>();
          feedback.show(cubit_ui_flow.FeedbackMessage(
            message: "Configured to use $distributor",
            type: cubit_ui_flow.MessageType.success,
          ));
        } catch (_) {}
      }
    }
  }
}
