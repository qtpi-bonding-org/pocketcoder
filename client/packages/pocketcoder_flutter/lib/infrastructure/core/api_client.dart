import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/permission/permission_api_models.dart';
import "package:flutter_aeroform/infrastructure/core/api_endpoints.dart";

@lazySingleton
class PocketCoderApi {
  final PocketBase _pb;

  PocketCoderApi(this._pb);

  /// Evaluates if a permission request should be granted.
  Future<PermissionResponse> evaluatePermission({
    required String permission,
    required List<String> patterns,
    required String chatId,
    required String sessionId,
    required String opencodeId,
    Map<String, dynamic>? metadata,
    String? message,
    String? messageId,
    String? callId,
  }) async {
    final response = await _pb.send(
      ApiEndpoints.permission,
      method: 'POST',
      body: {
        'permission': permission,
        'patterns': patterns,
        'chat_id': chatId,
        'session_id': sessionId,
        'opencode_id': opencodeId,
        if (metadata != null) 'metadata': metadata,
        if (message != null) 'message': message,
        if (messageId != null) 'message_id': messageId,
        if (callId != null) 'call_id': callId,
      },
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

  /// Fetches the raw content of an artifact.
  Future<String> fetchArtifact(String path) async {
    if (!ApiEndpoints.isSafeArtifactPath(path)) {
      throw ArgumentError('Invalid or unsafe artifact path: $path');
    }
    final response = await _pb.send(
      ApiEndpoints.artifact(path),
      method: 'GET',
    );
    return response.toString();
  }

  /// Returns the full URL for a workspace artifact.
  String getArtifactUrl(String path) {
    if (!ApiEndpoints.isSafeArtifactPath(path)) {
      throw ArgumentError('Invalid or unsafe artifact path: $path');
    }
    return '${_pb.baseURL}${ApiEndpoints.artifact(path)}';
  }
}
