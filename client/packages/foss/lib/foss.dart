import 'dart:async';
import 'dart:convert';

import 'package:pocketcoder_flutter/domain/notifications/push_service.dart';
import 'package:pocketcoder_flutter/domain/notifications/device.dart';
import 'package:pocketcoder_flutter/domain/billing/billing_service.dart';
import 'package:get_it/get_it.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:unifiedpush/unifiedpush.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

/// A BillingService for the FOSS version which assumes all features are available.
class FossBillingService implements BillingService {
  @override
  Future<void> initialize() async {
    // No-op for FOSS
  }

  @override
  Future<bool> isPremium() async => true;

  @override
  Future<void> restorePurchases() async {}

  @override
  Future<bool> purchase(String identifier) async => true;

  @override
  Future<List<BillingPackage>> getAvailablePackages() async {
    return [
      const BillingPackage(
        identifier: 'foss_premium',
        title: 'FOSS Premium',
        description: 'Free as in speech and beer.',
        priceString: r'$0.00',
      ),
    ];
  }
}

class NtfyPushService implements PushService {
  final _controller = StreamController<PushNotificationPayload>.broadcast();
  static const String instance = "pocketcoder_relay";

  @override
  Future<void> initialize() async {
    // 1. Initialize logic
    await UnifiedPush.initialize(
      onNewEndpoint: _onNewEndpoint,
      onRegistrationFailed: _onRegistrationFailed,
      onUnregistered: _onUnregistered,
      onMessage: _onMessage,
      onTempUnavailable: _onTempUnavailable,
    );

    // 2. Try to register with current or default distributor
    final success = await UnifiedPush.tryUseCurrentOrDefaultDistributor();
    if (success) {
      await UnifiedPush.register(instance: instance);
    } else {
      // In a real app, we would show a distributor picker here.
      // For now, we'll just log it.
      // ignore: avoid_print
      print(
          "No UnifiedPush distributor found. Please install a distributor like ntfy.");
    }
  }

  void _onNewEndpoint(PushEndpoint endpoint, String instanceId) {
    if (instanceId != instance) return;
    // ignore: avoid_print
    print("New UnifiedPush Endpoint: ${endpoint.url}");
    // ignore: avoid_print
    print(
        "TIP: When sending ntfy notifications, set 'click' to 'pocketcoder://' to open the app.");
    // This endpoint should be sent to the backend relay so it knows where to POST.
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

  void _onRegistrationFailed(FailedReason reason, String instanceId) {
    // ignore: avoid_print
    print("UnifiedPush Registration Failed for $instanceId: ${reason.name}");
  }

  void _onUnregistered(String instanceId) {
    // ignore: avoid_print
    print("UnifiedPush Unregistered: $instanceId");
  }

  void _onTempUnavailable(String instanceId) {
    // ignore: avoid_print
    print("UnifiedPush Temporarily Unavailable: $instanceId");
  }

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
  Future<String?> getToken() async {
    // In UnifiedPush, the 'token' is actually the unique endpoint URL
    // But we might want to return it here if needed for backend registration
    return null;
  }

  @override
  Stream<PushNotificationPayload> get notificationStream => _controller.stream;

  @override
  Future<bool> requestPermissions() async {
    // UnifiedPush registration double-acts as permission request
    // We already call tryUseCurrentOrDefaultDistributor in initialize
    return true;
  }

  @override
  Future<void> configure() async {
    // 1. Check if we already have a distributor
    final success = await UnifiedPush.tryUseCurrentOrDefaultDistributor();
    if (success) {
      // Re-register to be sure
      await UnifiedPush.register(instance: instance);
    } else {
      // 2. Fetch available distributors
      final distributors = await UnifiedPush.getDistributors();
      if (distributors.isNotEmpty) {
        // For simplicity in this FOSS implementation, we pick the first one.
        // In a production app, we would show a dialog for selection.
        final distributor = distributors.first;
        await UnifiedPush.saveDistributor(distributor);
        await UnifiedPush.register(instance: instance);

        try {
          final feedback = GetIt.I<IFeedbackService>();
          feedback.show(FeedbackMessage(
            message: "Configured to use $distributor",
            type: MessageType.success,
          ));
        } catch (_) {}
      } else {
        try {
          final feedback = GetIt.I<IFeedbackService>();
          feedback.show(FeedbackMessage(
            message: "No UnifiedPush distributor found.",
            type: MessageType.error,
          ));
        } catch (_) {}
      }
    }
  }
}
