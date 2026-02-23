import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:pocketcoder_flutter/domain/notifications/push_service.dart';
import 'package:pocketcoder_flutter/domain/billing/billing_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

export 'package:pocketcoder_flutter/domain/notifications/push_service.dart';
export 'package:pocketcoder_flutter/domain/billing/billing_service.dart';

class FcmPushService implements PushService {
  final _controller = StreamController<PushNotificationPayload>.broadcast();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  @override
  Future<void> initialize() async {
    // Initial configuration
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Background message handler is usually set in main.dart or bootstrap

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.data.isNotEmpty || message.notification != null) {
          _controller.add(PushNotificationPayload(
            title: message.notification?.title ?? 'PocketCoder',
            body: message.notification?.body ?? '',
            data: message.data,
          ));
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        // Handle notification click UI logic through the stream
        _controller.add(PushNotificationPayload(
          title: message.notification?.title ?? 'PocketCoder',
          body: message.notification?.body ?? '',
          data: message.data,
        ));
      });
    }
  }

  @override
  Future<String?> getToken() async {
    try {
      return await _fcm.getToken();
    } catch (e) {
      return null;
    }
  }

  @override
  Stream<PushNotificationPayload> get notificationStream => _controller.stream;

  @override
  Future<bool> requestPermissions() async {
    final settings = await _fcm.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }
}

class RevenueCatBillingService implements BillingService {
  @override
  Future<void> initialize() async {
    // Note: configuration happens at the app level usually.
    // We can check if it's already configured.
  }

  @override
  Future<bool> isPremium() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      // In PocketCoder, 'premium' is the expected entitlement ID
      return customerInfo.entitlements.active.containsKey('premium');
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> restorePurchases() async {
    try {
      await Purchases.restorePurchases();
    } catch (e) {
      // Log error
    }
  }

  @override
  Future<bool> purchase(String identifier) async {
    try {
      // First try to find the product
      final products = await Purchases.getProducts([identifier]);
      if (products.isEmpty) return false;

      final customerInfo = await Purchases.purchaseStoreProduct(products.first);
      return customerInfo.entitlements.active.containsKey('premium');
    } catch (e) {
      return false;
    }
  }
}
