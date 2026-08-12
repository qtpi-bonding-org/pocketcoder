import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'permission.freezed.dart';
part 'permission.g.dart';

@freezed
sealed class Permission with _$Permission {
  const factory Permission({
    required String id,
    required String aiEnginePermissionId,
    required String sessionId,
    required String permission,
    dynamic patterns,
    dynamic metadata,
    @JsonKey(unknownEnumValue: PermissionStatus.unknown) required PermissionStatus status,
    String? message,
    String? source,
    String? messageId,
    String? callId,
    String? challenge,
    String? chat,
    String? approvedBy,
    DateTime? approvedAt,
    DateTime? created,
    DateTime? updated,
    String? acpRequestId,
    String? acpSessionId,
    String? toolName,
    dynamic toolInput,
    String? description,
    dynamic permissionOptions,
    @JsonKey(unknownEnumValue: PermissionAcpStatus.unknown) PermissionAcpStatus? acpStatus,
    String? selectedOptionId,
    String? acpMessageId,
    String? toolCallId,
  }) = _Permission;

  factory Permission.fromRecord(RecordModel record) =>
      Permission.fromJson(record.toJson());

  factory Permission.fromJson(Map<String, dynamic> json) =>
      _$PermissionFromJson(json);
}

enum PermissionStatus {
  @JsonValue('draft')
  draft,
  @JsonValue('authorized')
  authorized,
  @JsonValue('denied')
  denied,
  @JsonValue('__unknown__')
  unknown,
}

enum PermissionAcpStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('allow_once')
  // ignore: constant_identifier_names
  allow_once,
  @JsonValue('allow_always')
  // ignore: constant_identifier_names
  allow_always,
  @JsonValue('deny')
  deny,
  @JsonValue('__unknown__')
  unknown,
}
