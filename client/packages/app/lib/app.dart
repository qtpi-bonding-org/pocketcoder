import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:get_it/get_it.dart';
import 'package:pocketcoder_flutter/domain/notifications/push_service.dart';
import 'package:pocketcoder_flutter/domain/notifications/i_device_repository.dart';
import 'package:pocketcoder_flutter/domain/billing/billing_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

export 'package:pocketcoder_flutter/domain/notifications/push_service.dart';
export 'package:pocketcoder_flutter/domain/billing/billing_service.dart';

class FcmPushService implements PushService {
  final _controller = StreamController<PushNotificationPayload>.broadcast();
  FirebaseMessaging? _fcm;

  @override
  Future<void> initialize() async {
    if (kIsWeb) {
      // Firebase Messaging on web requires specific setup (sw.js, options).
      // For now, we bypass it to allow the app to boot for UI testing.
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _fcm = FirebaseMessaging.instance;
    } catch (e) {
      // Log error but don't crash bootstrap
      print('[PocketCoder] Firebase init failed: $e');
      return;
    }

    // 2. Request Permissions
    NotificationSettings settings = await _fcm!.requestPermission(
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
            wasTapped: false,
          ));
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        // Handle notification click UI logic through the stream
        _controller.add(PushNotificationPayload(
          title: message.notification?.title ?? 'PocketCoder',
          body: message.notification?.body ?? '',
          data: message.data,
          wasTapped: true,
        ));
      });

      // 3. Register Token with Backend
      final token = await _fcm!.getToken();
      if (token != null) {
        await _registerDevice(token);
      }

      // 4. Handle Token Refresh
      _fcm!.onTokenRefresh.listen(_registerDevice);
    }
  }

  Future<void> _registerDevice(String token) async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      String deviceName = "PocketCoder Device";

      if (kIsWeb) {
        deviceName = "PocketCoder Web";
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceName = "${androidInfo.manufacturer} ${androidInfo.model}";
      } else if (Platform.isIOS || Platform.isMacOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceName = iosInfo.name;
      }

      final repo = GetIt.I<IDeviceRepository>();
      await repo.registerDevice(
        name: deviceName,
        pushToken: token,
        pushService: "fcm",
      );
    } catch (e) {
      // ignore: avoid_print
      print("🔔 [Notifications] FCM Registration failed: $e");
    }
  }

  @override
  Future<String?> getToken() async {
    try {
      return await _fcm?.getToken();
    } catch (e) {
      return null;
    }
  }

  @override
  Stream<PushNotificationPayload> get notificationStream => _controller.stream;

  @override
  Future<bool> requestPermissions() async {
    if (_fcm == null) return false;
    final settings = await _fcm!.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  @override
  Future<void> configure() async {
    // For FCM, configuration usually means system settings or just no-op
  }
}

class RevenueCatBillingService implements BillingService {
  @override
  Future<void> initialize() async {
    if (kIsWeb) {
      // RevenueCat Web Billing is separate from native.
      // For now, we skip to allow testing other platforms/mocking.
      return;
    }

    try {
      // 1. Enable Debug Logs in development
      await Purchases.setLogLevel(LogLevel.debug);

      // 2. Configure with API Key from .env
      // REVENUE_CAT_APPLE_KEY=...
      // REVENUE_CAT_GOOGLE_KEY=...
      String? apiKey;

      if (Platform.isIOS || Platform.isMacOS) {
        apiKey = dotenv.env['REVENUE_CAT_APPLE_KEY'];
      } else if (Platform.isAndroid) {
        apiKey = dotenv.env['REVENUE_CAT_GOOGLE_KEY'];
      }

      if (apiKey != null && apiKey.isNotEmpty) {
        final configuration = PurchasesConfiguration(apiKey);
        await Purchases.configure(configuration);
      }
    } catch (e) {
      print('[PocketCoder] RevenueCat configuration failed: $e');
    }
  }

  @override
  Future<bool> isPremium() async {
    try {
      if (!await Purchases.isConfigured) return false;
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
      if (!await Purchases.isConfigured) return;
      await Purchases.restorePurchases();
    } catch (e) {
      // Log error
    }
  }

  @override
  Future<bool> purchase(String identifier) async {
    try {
      if (!await Purchases.isConfigured) return false;

      // First try to find the product/package
      final offerings = await Purchases.getOfferings();
      final package = offerings.current?.getPackage(identifier);

      if (package == null) {
        // Fallback to direct product lookup if it's not in the default offering
        final products = await Purchases.getProducts([identifier]);
        if (products.isEmpty) return false;

        final customerInfo =
            await Purchases.purchaseStoreProduct(products.first);
        return customerInfo.entitlements.active.containsKey('premium');
      }

      final customerInfo = await Purchases.purchasePackage(package);
      return customerInfo.entitlements.active.containsKey('premium');
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<BillingPackage>> getAvailablePackages() async {
    try {
      if (!await Purchases.isConfigured) return [];

      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current == null) return [];

      return current.availablePackages.map((pkg) {
        return BillingPackage(
          identifier: pkg.identifier,
          title: pkg.storeProduct.title,
          description: pkg.storeProduct.description,
          priceString: pkg.storeProduct.priceString,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }
}
