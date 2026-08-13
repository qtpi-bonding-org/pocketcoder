import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:pocketbase_drift/pocketbase_drift.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder_flutter/domain/billing/billing_service.dart';
import 'package:pocketcoder_flutter/domain/notifications/push_service.dart';
import "package:pocketcoder_flutter/domain/models/collections.dart";
import 'package:pocketcoder_flutter/infrastructure/core/auth_store.dart';
import 'package:pocketcoder_flutter/infrastructure/core/pocketcoder_api_client.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/core/try_operation.dart';

@LazySingleton(as: IAuthRepository)
class AuthRepository implements IAuthRepository {
  static const _supportedServerApiVersion = 1;
  static const _supportedAppContractVersion = 1;
  static const _supportedDeploymentContractVersion = 1;

  final PocketBase _pocketBase;
  final AuthStoreConfig _authStoreConfig;
  final FlutterSecureStorage _storage;
  final BillingService _billingService;
  final PushService _pushService;
  final PocketCoderApiClient _api;

  AuthRepository(
    this._pocketBase,
    this._authStoreConfig,
    this._storage,
    this._billingService,
    this._pushService,
    this._api,
  );

  @override
  Stream<bool> get connectionStatus {
    if (_pocketBase is $PocketBase) {
      return (_pocketBase).connectivity.statusStream;
    }
    return Stream.value(true);
  }

  @override
  Future<bool> login(String email, String password) async {
    return tryMethod(
      () async {
        await _pocketBase
            .collection(Collections.users)
            .authWithPassword(email, password);
        await _refireConnectivityCheck();
        final userId = _pocketBase.authStore.record?.id;
        if (userId != null) {
          await _billingService.identify(userId);
          await _pushService.syncAuthenticatedDevice();
        }
        return true;
      },
      AuthException.new,
      'login',
    );
  }

  @override
  Future<void> verifyServerCompatibility() async {
    await tryMethod(
      () async {
        final generatedResponse =
            await _api.release.getReleaseCompatibility();
        final response = PocketCoderApiClient.decodeJson(generatedResponse.data);
        final compatibility = response['compatibility'];
        if (compatibility is! Map<String, dynamic>) {
          throw const FormatException(
              'Invalid release compatibility response.');
        }
        final app = compatibility['app'];
        final server = compatibility['server'];
        final deployment = compatibility['deployment'];
        final serverApiVersion =
            server is Map<String, dynamic> ? server['apiVersion'] : null;
        final appContractVersion =
            app is Map<String, dynamic> ? app['contractVersion'] : null;
        final deploymentContractVersion = deployment is Map<String, dynamic>
            ? deployment['contractVersion']
            : null;
        if (serverApiVersion != _supportedServerApiVersion ||
            appContractVersion != _supportedAppContractVersion ||
            deploymentContractVersion != _supportedDeploymentContractVersion) {
          throw const FormatException(
            'This PocketCoder server is not compatible with this app version.',
          );
        }
      },
      AuthException.new,
      'verifyServerCompatibility',
    );
  }

  /// Re-checks connectivity after a proven-successful network call.
  ///
  /// Works around a `pocketbase_drift` `ConnectivityService` gap: its
  /// `RequestPolicy.networkOnly` guard latches on the OS-level
  /// `connectivity_plus` stream and never self-heals from a real request
  /// succeeding, so a stale/spurious "offline" event at cold start can wedge
  /// subsequent reads even once we're demonstrably online.
  Future<void> _refireConnectivityCheck() async {
    if (_pocketBase is $PocketBase) {
      await _pocketBase.connectivity.checkConnectivity();
    }
  }

  @override
  Future<void> logout() async {
    await _pushService.unregisterAuthenticatedDevice();
    _pocketBase.authStore.clear();
    await _authStoreConfig.clear();
    await _billingService.reset();
  }

  @override
  Future<bool> refreshToken() async {
    return tryMethod(
      () async {
        await _pocketBase.collection(Collections.users).authRefresh();
        return true;
      },
      AuthException.new,
      'refreshToken',
    );
  }

  @override
  bool get isAuthenticated => _pocketBase.authStore.isValid;

  @override
  String? get currentUserId => _pocketBase.authStore.record?.id;

  @override
  String? get currentUserEmail =>
      _pocketBase.authStore.record?.getStringValue('email');

  @override
  String? get currentUserRole =>
      _pocketBase.authStore.record?.getStringValue('role');

  @override
  Future<void> updateBaseUrl(String url) async {
    _pocketBase.baseURL = url;
    await _storage.write(key: 'pb_server_url', value: url);
  }

  @override
  Future<String?> getSavedBaseUrl() => _storage.read(key: 'pb_server_url');
}
