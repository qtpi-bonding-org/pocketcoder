import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'tool_permission.freezed.dart';
part 'tool_permission.g.dart';

@freezed
class ToolPermission with _$ToolPermission {
  const factory ToolPermission({
    required String id,
    String? agent,
    required String tool,
    required String pattern,
    @JsonKey(unknownEnumValue: ToolPermissionAction.unknown) required ToolPermissionAction action,
    bool? active,
  }) = _ToolPermission;

  factory ToolPermission.fromRecord(RecordModel record) =>
      ToolPermission.fromJson(record.toJson());

  factory ToolPermission.fromJson(Map<String, dynamic> json) =>
      _$ToolPermissionFromJson(json);
}

enum ToolPermissionAction {
  @JsonValue('allow')
  allow,
  @JsonValue('ask')
  ask,
  @JsonValue('deny')
  deny,
  @JsonValue('__unknown__')
  unknown,
}
