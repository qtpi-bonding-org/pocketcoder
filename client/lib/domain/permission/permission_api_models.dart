import 'package:freezed_annotation/freezed_annotation.dart';

part 'permission_api_models.freezed.dart';
part 'permission_api_models.g.dart';

@freezed
class PermissionRequestPayload with _$PermissionRequestPayload {
  const factory PermissionRequestPayload({
    required String permission,
    List<String>? patterns,
    @JsonKey(name: 'chat_id') String? chatId,
    @JsonKey(name: 'session_id') String? sessionId,
    @JsonKey(name: 'opencode_id') String? opencodeId,
    Map<String, dynamic>? metadata,
    String? message,
    @JsonKey(name: 'message_id') String? messageId,
    @JsonKey(name: 'call_id') String? callId,
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
