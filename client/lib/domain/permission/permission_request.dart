import 'package:freezed_annotation/freezed_annotation.dart';

part 'permission_request.freezed.dart';
part 'permission_request.g.dart';

@freezed
class PermissionRequest with _$PermissionRequest {
  const factory PermissionRequest({
    required String id,
    @JsonKey(name: 'ai_engine_permission_id') String? aiEnginePermissionId,
    @JsonKey(name: 'session_id') String? sessionId,
    @JsonKey(name: 'chat') String? chatId,
    required String permission,
    PermissionStatus? status,
    List<String>? patterns,
    Map<String, dynamic>? metadata,
    String? message,
    @JsonKey(name: 'message_id') String? messageId,
    @JsonKey(name: 'call_id') String? callId,
    String? challenge,
    String? source,
    @JsonKey(name: 'approved_by') String? approvedBy,
    @JsonKey(name: 'approved_at') DateTime? approvedAt,
    DateTime? created,
    DateTime? updated,
  }) = _PermissionRequest;

  factory PermissionRequest.fromJson(Map<String, dynamic> json) =>
      _$PermissionRequestFromJson(json);
}

enum PermissionStatus {
  @JsonValue('draft')
  draft,
  @JsonValue('authorized')
  authorized,
  @JsonValue('denied')
  denied,
  @JsonValue('')
  unknown,
}
