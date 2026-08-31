import 'package:built_collection/built_collection.dart';
import 'package:built_value/json_object.dart';
import 'package:injectable/injectable.dart';
import 'package:pocketbase_drift/pocketbase_drift.dart';
import 'package:pocketcoder_flutter/domain/release/i_server_release_status_service.dart';
import 'package:pocketcoder_flutter/domain/release/server_release_status.dart';
import 'package:pocketcoder_flutter/infrastructure/core/pocketcoder_api_client.dart';

@LazySingleton(as: IServerReleaseStatusService)
class ServerReleaseStatusService implements IServerReleaseStatusService {
  ServerReleaseStatusService(this._pocketBase, this._api);

  final PocketBase _pocketBase;
  final PocketCoderApiClient _api;

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
    final generatedResponse = await _api.release.getReleaseStatus();
    final status = generatedResponse.data;
    if (status == null) {
      throw StateError('Empty release status response from server.');
    }
    final current = status.current;
    return ServerReleaseStatusSnapshot.fromStatus({
      'current': {
        'releaseDigest': current.releaseDigest,
        'sourceCommit': current.sourceCommit,
        'serverVersion': current.serverVersion,
        'dataVersion': current.dataVersion,
        'deploymentContractVersion': current.deploymentContractVersion,
        'compatibility': _decodeNullableJsonMap(current.compatibility),
        'selectedHarnesses': current.selectedHarnesses?.toList(),
      },
      'metadataStatus': _decodeNullableJsonMap(status.metadataStatus),
    });
  }

  static Map<String, dynamic> _decodeNullableJsonMap(
    BuiltMap<String, JsonObject?>? value,
  ) {
    if (value == null) return const {};
    return {
      for (final entry in value.entries) entry.key: entry.value?.value,
    };
  }
}
