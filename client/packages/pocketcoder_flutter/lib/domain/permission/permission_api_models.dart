import 'package:freezed_annotation/freezed_annotation.dart';

part 'permission_api_models.freezed.dart';
part 'permission_api_models.g.dart';

@freezed
class PermissionRequestPayload with _$PermissionRequestPayload {
  const factory PermissionRequestPayload({
    required String permission,
    List<String>? patterns,
    String? chat,
    String? sessionId,
    String? opencodeId,
    Map<String, dynamic>? metadata,
    String? message,
    String? messageId,
    String? callId,
  }) = _PermissionRequestPayload;

  factory PermissionRequestPayload.fromJson(Map<String, dynamic> json) =>
      _$PermissionRequestPayloadFromJson(json);
}

@freezed
class PermissionResponse with _$PermissionResponse {
  const factory PermissionResponse({
    required bool permitted,
    required String id,
    required String status,
  }) = _PermissionResponse;

  factory PermissionResponse.fromJson(Map<String, dynamic> json) =>
      _$PermissionResponseFromJson(json);
}
