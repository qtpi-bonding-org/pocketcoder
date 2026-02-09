import 'package:freezed_annotation/freezed_annotation.dart';

part 'permission_request.freezed.dart';
part 'permission_request.g.dart';

@freezed
class PermissionRequest with _$PermissionRequest {
  const factory PermissionRequest({
    required String id,
    // ignore: invalid_annotation_target
    @JsonKey(name: 'session_id') required String sessionId,
    // ignore: invalid_annotation_target
    @JsonKey(name: 'opencode_id') required String opencodeId,
    required String permission,
    required String status,
    @Default([]) List<String> patterns,
    @Default({}) Map<String, dynamic> metadata,
    String? message,
    // ignore: invalid_annotation_target
    @JsonKey(name: 'message_id') String? messageId,
    // ignore: invalid_annotation_target
    @JsonKey(name: 'call_id') String? callId,
    // ignore: invalid_annotation_target
    @JsonKey(name: 'created') String? created,
  }) = _PermissionRequest;

  factory PermissionRequest.fromJson(Map<String, dynamic> json) =>
      _$PermissionRequestFromJson(json);
}
