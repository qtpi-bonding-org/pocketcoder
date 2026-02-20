import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'permission_request.freezed.dart';
part 'permission_request.g.dart';

@freezed
class PermissionRequest with _$PermissionRequest {
  const factory PermissionRequest({
    required String id,
    String? aiEnginePermissionId,
    String? sessionId,
    @JsonKey(name: 'chat') String? chatId,
    required String permission,
    PermissionStatus? status,
    List<String>? patterns,
    Map<String, dynamic>? metadata,
    String? message,
    String? messageId,
    String? callId,
    String? challenge,
    String? source,
    String? approvedBy,
    DateTime? approvedAt,
    DateTime? created,
    DateTime? updated,
  }) = _PermissionRequest;

  factory PermissionRequest.fromRecord(RecordModel record) =>
      PermissionRequest.fromJson(record.toJson());

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
