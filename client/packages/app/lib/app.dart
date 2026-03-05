import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/domain/notifications/push_service.dart';
import 'package:pocketcoder_flutter/domain/notifications/i_device_repository.dart';
import 'package:pocketcoder_flutter/domain/billing/billing_service.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_deploy_option_service.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_transition.dart';
import 'package:injectable/injectable.dart' show GetItHelper;
import 'package:flutter_aeroform/flutter_aeroform.module.dart';
import 'package:flutter_aeroform/domain/models/app_config.dart';
import 'package:flutter_aeroform/domain/auth/i_oauth_service.dart';
import 'package:flutter_aeroform/domain/cloud_provider/i_cloud_provider_api_client.dart';
import 'package:flutter_aeroform/domain/deployment/i_deployment_service.dart';
import 'package:flutter_aeroform/domain/storage/i_secure_storage.dart';
import 'package:flutter_aeroform/domain/validation/i_validation_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:app/application/auth/auth_cubit.dart';
import 'package:app/application/auth/auth_message_mapper.dart';
import 'package:app/application/config/config_cubit.dart';
import 'package:app/application/deployment/deployment_cubit.dart';
import 'package:app/application/deployment/deployment_message_mapper.dart';
import 'package:app/presentation/auth/auth_screen.dart' as deploy_auth;
import 'package:app/presentation/deployment/config_screen.dart' as deploy_config;
import 'package:app/presentation/deployment/progress_screen.dart' as deploy_progress;
import 'package:app/presentation/deployment/details_screen.dart' as deploy_details;

export 'package:pocketcoder_flutter/domain/notifications/push_service.dart';
export 'package:pocketcoder_flutter/domain/billing/billing_service.dart';
export 'package:pocketcoder_flutter/domain/deployment/i_deploy_option_service.dart';

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
  Future<bool> hasDeployAccess() async {
    try {
      if (!await Purchases.isConfigured) return false;
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.active.containsKey('deploy');
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

/// Proprietary deploy option service — adds Linode + Elestio to the picker.
class ProDeployOptionService implements IDeployOptionService {
  @override
  List<DeployOption> getAvailableProviders() => const [
        DeployOption(
          id: 'linode',
          name: 'Linode (Akamai)',
          description: 'One-tap deploy via OAuth. 24h access included.',
          routePath: '/auth',
          requiresPurchase: true,
        ),
        DeployOption(
          id: 'elestio',
          name: 'Elestio',
          description: 'Managed hosting. Deploy with one click.',
          url: 'https://elest.io/open-source/pocketcoder',
        ),
        DeployOption(
          id: 'hetzner',
          name: 'Hetzner Cloud',
          description: 'Self-host on your own VPS. Affordable, EU-based.',
          url: 'https://hetzner.cloud/?ref=yourReferralCode',
        ),
      ];
}

/// Pre-registers AppConfig and linodeClientId before bootstrap().
///
/// Call this from the proprietary main.dart BEFORE bootstrap().
void preRegisterAeroformConfig() {
  final getIt = GetIt.instance;

  getIt.registerSingleton<AppConfig>(
    AppConfig(
      linodeClientId: AppConfig.kLinodeClientId,
      linodeRedirectUri: AppConfig.kLinodeRedirectUri,
      imageRelayUrl: AppConfig.kImageRelayUrl,
      nixosImageLabel: AppConfig.kNixosImageLabel,
      maxPollingAttempts: AppConfig.kMaxPollingAttempts,
      initialPollingIntervalSeconds: AppConfig.kInitialPollingIntervalSeconds,
    ),
  );

  getIt.registerSingleton<String>(
    AppConfig.kLinodeClientId,
    instanceName: 'linodeClientId',
  );
}

/// Initializes flutter_aeroform DI and deploy cubits in GetIt.
///
/// Call this from the proprietary main.dart AFTER bootstrap()
/// (so that FlutterSecureStorage and http.Client are available).
void initializeAeroformDI() {
  final getIt = GetIt.instance;

  // Initialize aeroform module (registers IOAuthService, IDeploymentService, etc.)
  final aeroformModule = FlutterAeroformPackageModule();
  final gh = GetItHelper(getIt);
  aeroformModule.init(gh);

  // Register deploy cubits as factories
  getIt.registerFactory<AuthCubit>(
    () => AuthCubit(
      getIt<IOAuthService>(),
      getIt<ISecureStorage>(),
    ),
  );
  getIt.registerFactory<AuthMessageMapper>(() => AuthMessageMapper());

  getIt.registerFactory<ConfigCubit>(
    () => ConfigCubit(
      getIt<IValidationService>(),
      getIt<ICloudProviderAPIClient>(),
      getIt<ISecureStorage>(),
    ),
  );

  getIt.registerFactory<DeploymentCubit>(
    () => DeploymentCubit(getIt<IDeploymentService>()),
  );
  getIt.registerFactory<DeploymentMessageMapper>(
    () => DeploymentMessageMapper(),
  );
}

/// Linode deployment routes to inject via [AppRouter.setAdditionalRoutes].
List<RouteBase> get linodeRoutes => [
      GoRoute(
        path: AppRoutes.auth,
        name: RouteNames.auth,
        pageBuilder: (context, state) => TerminalTransition.buildPage(
          context: context,
          state: state,
          child: const deploy_auth.AuthScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.config,
        name: RouteNames.config,
        pageBuilder: (context, state) => TerminalTransition.buildPage(
          context: context,
          state: state,
          child: const deploy_config.ConfigScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.deploymentProgress,
        name: RouteNames.deploymentProgress,
        pageBuilder: (context, state) => TerminalTransition.buildPage(
          context: context,
          state: state,
          child: const deploy_progress.ProgressScreen(),
        ),
      ),
      GoRoute(
        path: '${AppRoutes.deploymentDetails}?instanceId',
        name: RouteNames.deploymentDetails,
        pageBuilder: (context, state) {
          final instanceId = state.uri.queryParameters['instanceId'] ?? '';
          return TerminalTransition.buildPage(
            context: context,
            state: state,
            child: deploy_details.DetailsScreen(instanceId: instanceId),
          );
        },
      ),
    ];
