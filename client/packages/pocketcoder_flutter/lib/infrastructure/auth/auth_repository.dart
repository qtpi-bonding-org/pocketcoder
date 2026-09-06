import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:pocketbase_drift/pocketbase_drift.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import "package:pocketcoder_flutter/domain/models/collections.dart";
import 'package:pocketcoder_flutter/infrastructure/core/auth_store.dart';
import 'package:pocketcoder_flutter/infrastructure/core/pocketcoder_api_client.dart';
import 'package:pocketcoder_flutter/infrastructure/core/auth_aware_http_client.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/core/try_operation.dart';
import 'package:pocketcoder_flutter/infrastructure/core/logger.dart';

@LazySingleton(as: IAuthRepository)
class AuthRepository implements IAuthRepository {
  static const _supportedServerApiVersion = 1;
  static const _supportedAppContractVersion = 1;
  static const _supportedDeploymentContractVersion = 1;

  final PocketBase _pocketBase;
  final AuthStoreConfig _authStoreConfig;
  final FlutterSecureStorage _storage;
  final PocketCoderApiClient _api;
  final AuthHttpState _authHttpState;

  AuthRepository(
    this._pocketBase,
    this._authStoreConfig,
    this._storage,
    this._api,
    this._authHttpState,
  );

  @override
  Stream<bool> get connectionStatus {
    if (_pocketBase is $PocketBase) {
      return (_pocketBase).connectivity.statusStream;
    }
    return Stream.value(true);
  }

  @override
  Stream<void> get authChanges => _pocketBase.authStore.onChange.map((_) {});

  @override
  Future<bool> login(String email, String password) async {
    return tryMethod(
      () async {
        await _pocketBase
            .collection(Collections.users)
            .authWithPassword(email, password);
        await _refireConnectivityCheck();
        // Authentication success is intentionally independent of provider
        // effects: AuthSessionEffects runs best-effort after login returns and
        // retries on a later qualifying session transition.
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
        final generatedResponse = await _api.release.getReleaseCompatibility();
        final compatibilityField = generatedResponse.data?.compatibility;
        if (compatibilityField == null) {
          throw const FormatException(
              'Invalid release compatibility response.');
        }
        final compatibility = {
          for (final entry in compatibilityField.entries)
            entry.key: entry.value?.value,
        };
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
    _pocketBase.authStore.clear();
    await _authStoreConfig.clear();
  }

  @override
  Future<void> clearSession() async {
    _pocketBase.authStore.clear();
    await _authStoreConfig.clear();
    await _storage.delete(key: 'pb_server_url');
    // Without this, every record pocketbase_drift ever synced (chats
    // included) stays sitting in its local offline cache -- readable
    // straight from disk with no auth and no network at all -- so a
    // "cleared" session could still render an old deployment's chat list.
    if (_pocketBase is $PocketBase) {
      await _pocketBase.db.clearAllData();
    }
  }

  @override
  Future<AuthRefreshResult> refreshToken() async {
    AppLogger.debug('AuthRepository.refreshToken start', {
      'baseUrl': _pocketBase.baseURL,
    });
    try {
      // Deliberate exception: this is the auth refresh operation itself and
      // necessarily runs before DAO session guards can apply.
      await _pocketBase.collection(Collections.users).authRefresh(
        headers: {AuthAwareHttpClient.skipRefreshHeader: '1'},
      );
      AppLogger.debug('AuthRepository.refreshToken succeeded');
      return AuthRefreshResult.refreshed;
    } on ClientException catch (error, stackTrace) {
      AppLogger.warning('AuthRepository.refreshToken ClientException', {
        'statusCode': error.statusCode,
        'error': error.toString(),
        'originalError': error.originalError?.toString(),
        'originalErrorType': error.originalError?.runtimeType.toString(),
        'stackTrace': stackTrace.toString(),
      });
      if (error.statusCode == 401 || error.statusCode == 403) {
        // PocketBase does not clear the store for a failed auth-refresh.
        // Explicitly clear both the in-memory and persisted credentials only
        // when the server has definitively rejected this session.
        _pocketBase.authStore.clear();
        await _authStoreConfig.clear();
        AppLogger.warning(
            'AuthRepository.refreshToken -> invalidSession (401/403)');
        return AuthRefreshResult.invalidSession;
      }

      // A timeout, DNS failure, or 5xx response says nothing about whether
      // the user's locally persisted identity is still valid.
      AppLogger.warning(
          'AuthRepository.refreshToken -> temporarilyUnavailable (ClientException, '
          'statusCode=${error.statusCode})');
      return AuthRefreshResult.temporarilyUnavailable;
    } catch (error, stackTrace) {
      // Unknown client/decoding failures are still not proof that the session
      // is invalid. Preserve the credential and let the app recover later.
      AppLogger.warning('AuthRepository.refreshToken unknown error', {
        'errorType': error.runtimeType.toString(),
        'error': error.toString(),
        'stackTrace': stackTrace.toString(),
      });
      return AuthRefreshResult.temporarilyUnavailable;
    }
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
  String? get currentBaseUrl => _pocketBase.baseURL;

  @override
  Future<void> updateBaseUrl(String url) async {
    // In-memory only, deliberately not persisted here -- a candidate URL
    // needs to be active for verifyServerCompatibility()/login() to target
    // it, but persisting an unverified URL let one typo on the login
    // screen permanently overwrite the last-known-good saved URL. Callers
    // persist explicitly via persistBaseUrl() once the candidate is
    // actually confirmed good.
    _pocketBase.baseURL = url;
    _authHttpState.updateDeploymentOrigin(url);
  }

  @override
  Future<void> persistBaseUrl(String url) =>
      _storage.write(key: 'pb_server_url', value: url);

  @override
  Future<String?> getSavedBaseUrl() => _storage.read(key: 'pb_server_url');
}
