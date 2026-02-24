import 'dart:async';
import 'package:pocketcoder_flutter/domain/notifications/push_service.dart';
import 'package:pocketcoder_flutter/domain/billing/billing_service.dart';

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

  @override
  Future<void> initialize() async {
    // Implement ntfy registration / deep link listener
    // ignore: avoid_print
    print("NtfyPushService initialized");
  }

  @override
  Future<String?> getToken() async {
    // In ntfy, this might be the topic the user subscribed to
    return "ntfy_topic_placeholder";
  }

  @override
  Stream<PushNotificationPayload> get notificationStream => _controller.stream;

  @override
  Future<bool> requestPermissions() async {
    // Usually handled by the OS, but for ntfy we might check if deep links are enabled
    return true;
  }
}
