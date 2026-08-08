import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/domain/notifications/push_service.dart';
import 'package:pocketcoder_flutter/domain/notifications/i_device_repository.dart';
import 'package:pocketcoder_flutter/domain/billing/billing_service.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_deploy_option_service.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/presentation/deployment/deploy_credentials.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_transition.dart';
import 'package:injectable/injectable.dart' show GetItHelper;
import 'package:flutter_aeroform/flutter_aeroform.module.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_aeroform/domain/models/app_config.dart';
import 'package:flutter_aeroform/domain/auth/i_oauth_service.dart';
import 'package:flutter_aeroform/domain/cloud_provider/i_cloud_provider_api_client.dart';
import 'package:flutter_aeroform/domain/deployment/i_provisioning_service.dart';
import 'package:flutter_aeroform/domain/storage/i_secure_storage.dart';
import 'package:flutter_aeroform/domain/validation/i_validation_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:pocketbase/pocketbase.dart';

import 'package:pocketcoder_pro/application/auth/auth_cubit.dart';
import 'package:pocketcoder_pro/application/auth/auth_message_mapper.dart';
import 'package:pocketcoder_pro/application/config/config_cubit.dart';
import 'package:pocketcoder_pro/application/deployment/deployment_cubit.dart';
import 'package:pocketcoder_pro/infrastructure/deployment/deployment_readiness_service.dart';
import 'package:pocketcoder_pro/application/deployment/deployment_message_mapper.dart';
import 'package:pocketcoder_pro/application/server_update/server_update_cubit.dart';
import 'package:pocketcoder_pro/application/server_update/server_update_message_mapper.dart';
import 'package:pocketcoder_pro/domain/server_update/i_server_update_service.dart';
import 'package:pocketcoder_pro/infrastructure/server_update/current_instance_store.dart';
import 'package:pocketcoder_pro/infrastructure/server_update/ssh_server_update_service.dart';
import 'package:pocketcoder_pro/presentation/auth/auth_screen.dart'
    as deploy_auth;
import 'package:pocketcoder_pro/presentation/deployment/config_screen.dart'
    as deploy_config;
import 'package:pocketcoder_pro/presentation/deployment/progress_screen.dart'
    as deploy_progress;
import 'package:pocketcoder_pro/presentation/deployment/details_screen.dart'
    as deploy_details;
import 'package:pocketcoder_pro/presentation/server_update/update_server_screen.dart'
    as update_server;

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

    // 2. Request Permissions. Push is optional infrastructure and must never
    // prevent the rest of the app from booting (for example, before iOS has
    // delivered the APNs token to Firebase).
    late final NotificationSettings settings;
    try {
      settings = await _fcm!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (error) {
      print('[PocketCoder] FCM permission setup failed: $error');
      return;
    }

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

      // 3. Register Token with Backend. On Apple platforms the APNs token is
      // not guaranteed to exist immediately after permission is granted, and
      // Firebase rejects getToken() until it does. Do this asynchronously so
      // app startup is never blocked by push registration.
      unawaited(_registerMessagingToken());

      // 4. Handle Token Refresh
      _fcm!.onTokenRefresh.listen(
        _registerDevice,
        onError: (Object error, StackTrace stack) {
          print('[PocketCoder] FCM token refresh failed: $error');
        },
      );
    }
  }

  Future<void> _registerMessagingToken() async {
    try {
      if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
        String? apnsToken;
        for (var attempt = 0; attempt < 5; attempt++) {
          apnsToken = await _fcm!.getAPNSToken();
          if (apnsToken != null && apnsToken.isNotEmpty) break;
          if (attempt < 4) {
            await Future<void>.delayed(const Duration(seconds: 1));
          }
        }
        if (apnsToken == null || apnsToken.isEmpty) {
          print('[PocketCoder] APNs token is not available yet; '
              'deferring FCM registration.');
          return;
        }
      }

      final token = await _fcm!.getToken();
      if (token != null && token.isNotEmpty) {
        await _registerDevice(token);
      }
    } catch (error) {
      // A missing APNs token, missing simulator capability, or a transient
      // Firebase failure should not become an unhandled bootstrap exception.
      print('[PocketCoder] FCM token registration deferred: $error');
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
      } else if (Platform.isIOS) {
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
      if (_fcm == null) return null;
      if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
        final apnsToken = await _fcm!.getAPNSToken();
        if (apnsToken == null || apnsToken.isEmpty) return null;
      }
      return await _fcm!.getToken();
    } catch (e) {
      print('[PocketCoder] FCM token lookup failed: $e');
      return null;
    }
  }

  @override
  Stream<PushNotificationPayload> get notificationStream => _controller.stream;

  @override
  Future<PushNotificationPayload?> getInitialNotification() async {
    try {
      final message = await _fcm?.getInitialMessage();
      if (message == null) return null;
      return PushNotificationPayload(
        title: message.notification?.title ?? 'PocketCoder',
        body: message.notification?.body ?? '',
        data: message.data,
        wasTapped: true,
      );
    } catch (e) {
      return null;
    }
  }

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

// Pass --dart-define=USE_TEST_STORE=true to activate RevenueCat's Test
// Store for a given build. Defaults to false, so an ordinary build --
// including one where .env still happens to have REVENUE_CAT_TEST_KEY
// sitting in it -- always uses the real per-platform keys unless this
// is explicitly passed. Forgetting to clean up .env can never silently
// ship the Test Store in a build meant to be real; only deliberately
// adding this flag to a specific build invocation can.
const kUseTestStore = bool.fromEnvironment('USE_TEST_STORE');

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
      //
      // REVENUE_CAT_TEST_KEY (optional) is only ever read when this
      // build was explicitly invoked with --dart-define=USE_TEST_STORE=
      // true (see kUseTestStore above) -- RevenueCat's Test Store
      // simulates the full purchase flow (success/fail/cancel) with no
      // App Store Connect API key, real IAP products, or sandbox tester
      // needed, exactly what we want before handing RevenueCat the .p8.
      // Every other build, including one where .env still happens to
      // have REVENUE_CAT_TEST_KEY sitting in it, uses the real keys.
      String? apiKey;
      if (kUseTestStore) {
        apiKey = dotenv.env['REVENUE_CAT_TEST_KEY'];
      }

      if (apiKey == null || apiKey.isEmpty) {
        if (Platform.isIOS) {
          apiKey = dotenv.env['REVENUE_CAT_APPLE_KEY'];
        } else if (Platform.isAndroid) {
          apiKey = dotenv.env['REVENUE_CAT_GOOGLE_KEY'];
        }
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
  Future<void> identify(String userId) async {
    try {
      if (kIsWeb) return;
      if (!await Purchases.isConfigured) return;
      // Aliases this device's (possibly anonymous) purchases to the
      // PocketBase user id -- push-relay's RevenueCat check queries by
      // that same id, so without this call it can never find them.
      await Purchases.logIn(userId);
    } catch (e) {
      print('[PocketCoder] RevenueCat logIn failed: $e');
    }
  }

  @override
  Future<void> reset() async {
    try {
      if (kIsWeb) return;
      if (!await Purchases.isConfigured) return;
      await Purchases.logOut();
    } catch (e) {
      print('[PocketCoder] RevenueCat logOut failed: $e');
    }
  }

  @override
  Future<bool> isPro() async {
    try {
      if (!await Purchases.isConfigured) return false;
      final customerInfo = await Purchases.getCustomerInfo();
      // 'PocketCoder Pro' is the entitlement identifier actually
      // configured in the RevenueCat dashboard (matches push-relay's
      // PREMIUM_LOOKUP_KEY server-side) -- 'premium' was a different,
      // never-created identifier this would never match.
      return customerInfo.entitlements.active.containsKey('PocketCoder Pro');
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

        final purchaseResult = await Purchases.purchase(
          PurchaseParams.storeProduct(products.first),
        );
        // Different identifiers grant different entitlements
        // ('PocketCoder Pro' for subscriptions, 'deploy' for the
        // one-off deploy pass) --
        // any newly active entitlement means this specific purchase
        // succeeded, so check for that rather than hardcoding one name.
        return purchaseResult.customerInfo.entitlements.active.isNotEmpty;
      }

      final purchaseResult = await Purchases.purchase(
        PurchaseParams.package(package),
      );
      return purchaseResult.customerInfo.entitlements.active.isNotEmpty;
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
    // NOTE: linodeClientId stays required here because AppConfig
    // (flutter_aeroform's own model) still declares it as a required
    // field -- that's out of scope for this migration (see the
    // Linode OAuth relay migration plan, Task 6). Nothing reads
    // AppConfig.linodeClientId anymore now that LinodeOAuthService talks
    // to the oauth-relay Worker instead of Linode directly.
    AppConfig(
      linodeClientId: AppConfig.kLinodeClientId,
      linodeRedirectUri: AppConfig.kLinodeRedirectUri,
      imageRelayUrl: AppConfig.kImageRelayUrl,
      nixosImageLabel: AppConfig.kNixosImageLabel,
      maxPollingAttempts: AppConfig.kMaxPollingAttempts,
      initialPollingIntervalSeconds: AppConfig.kInitialPollingIntervalSeconds,
    ),
  );

  // The @Named('linodeClientId') GetIt registration is deleted: it has no
  // remaining consumers now that LinodeOAuthService and LinodeAPIClient
  // both dropped their clientId constructor params in favor of routing
  // through the oauth-relay Worker (this plan's Tasks 5/6).
}

/// Initializes flutter_aeroform DI and deploy cubits in GetIt.
///
/// Call this from the proprietary main.dart AFTER bootstrap()
/// (so that FlutterSecureStorage and http.Client are available).
void initializeAeroformDI() {
  final getIt = GetIt.instance;

  // Initialize aeroform module (registers IOAuthService, IProvisioningService, etc.)
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

  getIt.registerLazySingleton<CurrentInstanceStore>(
    () => CurrentInstanceStore(),
  );

  getIt.registerLazySingleton<DeploymentCubit>(
    () => DeploymentCubit(
      getIt<IProvisioningService>(),
      getIt<CurrentInstanceStore>(),
      DeploymentReadinessService(client: getIt<http.Client>()),
      getIt<ISecureStorage>(),
    ),
  );
  getIt.registerFactory<DeploymentMessageMapper>(
    () => DeploymentMessageMapper(),
  );

  // Server update: SSH in as root and run the update sequence. Independent
  // of pocketcoder_flutter's SshTerminalCubit -- own service, own cubit,
  // own credentials (the root key Aeroform generated at deploy time, not
  // the terminal's separate sandboxed worker key).
  getIt.registerLazySingleton<IServerUpdateService>(
    () => SshServerUpdateService(
      getIt<ISecureStorage>(),
      getIt<PocketBase>(),
    ),
  );
  getIt.registerFactory<ServerUpdateCubit>(
    () => ServerUpdateCubit(getIt<IServerUpdateService>()),
  );
  getIt.registerFactory<ServerUpdateMessageMapper>(
    () => ServerUpdateMessageMapper(),
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
          child: BlocProvider(
            create: (_) => getIt<AuthCubit>(),
            child: deploy_auth.AuthScreen(
              credentials: state.extra is DeployCredentials
                  ? state.extra as DeployCredentials
                  : null,
            ),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.config,
        name: RouteNames.config,
        pageBuilder: (context, state) => TerminalTransition.buildPage(
          context: context,
          state: state,
          child: deploy_config.ConfigScreen(
            credentials: state.extra is DeployCredentials
                ? state.extra as DeployCredentials
                : null,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.deploymentProgress,
        name: RouteNames.deploymentProgress,
        pageBuilder: (context, state) => TerminalTransition.buildPage(
          context: context,
          state: state,
          child: BlocProvider.value(
            value: getIt<DeploymentCubit>(),
            child: const deploy_progress.ProgressScreen(),
          ),
        ),
      ),
      GoRoute(
        // Query parameters are supplied through state.uri.queryParameters;
        // they must not be embedded in the route path or go_router encodes
        // the '?' as part of the URL path.
        path: AppRoutes.deploymentDetails,
        name: RouteNames.deploymentDetails,
        pageBuilder: (context, state) {
          final instanceId = state.uri.queryParameters['instanceId'] ?? '';
          return TerminalTransition.buildPage(
            context: context,
            state: state,
            child: BlocProvider.value(
              value: getIt<DeploymentCubit>(),
              child: deploy_details.DetailsScreen(instanceId: instanceId),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.updateServer,
        name: RouteNames.updateServer,
        pageBuilder: (context, state) {
          // Query param absent (e.g. reached from Settings, not right
          // after a deploy) -- the screen resolves it from
          // CurrentInstanceStore itself.
          final instanceId = state.uri.queryParameters['instanceId'];
          return TerminalTransition.buildPage(
            context: context,
            state: state,
            child: update_server.UpdateServerScreen(instanceId: instanceId),
          );
        },
      ),
    ];
