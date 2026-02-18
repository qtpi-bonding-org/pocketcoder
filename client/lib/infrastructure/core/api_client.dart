import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../domain/permission/permission_api_models.dart';
import 'api_endpoints.dart';

@lazySingleton
class PocketCoderApi {
  final PocketBase _pb;

  PocketCoderApi(this._pb);

  /// Evaluates a permission request against the Sovereign Authority.
  Future<PermissionResponse> evaluatePermission(
    PermissionRequestPayload payload,
  ) async {
    final response = await _pb.send(
      ApiEndpoints.permission,
      method: 'POST',
      body: payload.toJson(),
    );
    return PermissionResponse.fromJson(response as Map<String, dynamic>);
  }

  /// Returns active SSH keys as a list of strings.
  Future<List<String>> getSshKeys() async {
    final response = await _pb.send(
      ApiEndpoints.sshKeys,
      method: 'GET',
    );
    if (response is String) {
      return response.trim().split('\n').where((s) => s.isNotEmpty).toList();
    }
    return [];
  }

  /// Returns the full URL for a workspace artifact.
  String getArtifactUrl(String path) {
    if (!ApiEndpoints.isSafeArtifactPath(path)) {
      throw ArgumentError('Invalid or unsafe artifact path: $path');
    }
    return '${_pb.baseUrl}${ApiEndpoints.artifact(path)}';
  }
}
