import 'package:injectable/injectable.dart';
import 'package:pocketbase_drift/pocketbase_drift.dart';
import 'package:pocketcoder_flutter/domain/release/i_server_release_status_service.dart';
import 'package:pocketcoder_flutter/domain/release/server_release_status.dart';
import 'package:pocketcoder_flutter/infrastructure/core/api_endpoints.dart';

@LazySingleton(as: IServerReleaseStatusService)
class ServerReleaseStatusService implements IServerReleaseStatusService {
  ServerReleaseStatusService(this._pocketBase);

  final PocketBase _pocketBase;

  @override
  bool get isAuthenticated => _pocketBase.authStore.isValid;

  @override
  Stream<bool> get authenticationChanges =>
      _pocketBase.authStore.onChange.map((_) => isAuthenticated).distinct();

  @override
  Future<ServerReleaseStatusSnapshot> inspect() async {
    if (!isAuthenticated) {
      throw StateError('Sign in before checking server release status.');
    }
    final response = _pocketBase is $PocketBase
        ? await _pocketBase.send<Map<String, dynamic>>(
            ApiEndpoints.releaseStatus,
            requestPolicy: RequestPolicy.networkOnly,
          )
        : await _pocketBase.send<Map<String, dynamic>>(
            ApiEndpoints.releaseStatus,
          );
    return ServerReleaseStatusSnapshot.fromStatus(response);
  }
}
