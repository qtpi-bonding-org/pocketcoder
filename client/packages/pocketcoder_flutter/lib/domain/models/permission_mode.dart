import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'permission_mode.freezed.dart';
part 'permission_mode.g.dart';

@freezed
abstract class PermissionMode with _$PermissionMode {
  const factory PermissionMode({
    required String id,
    required String name,
    String? description,
    @JsonKey(unknownEnumValue: PermissionModeBaseSessionMode.unknown)
    required PermissionModeBaseSessionMode baseSessionMode,
    String? user,
    bool? isSystem,
    bool? isDefault,
  }) = _PermissionMode;

  factory PermissionMode.fromRecord(RecordModel record) =>
      PermissionMode.fromJson(record.toJson());

  factory PermissionMode.fromJson(Map<String, dynamic> json) =>
      _$PermissionModeFromJson(json);
}

enum PermissionModeBaseSessionMode {
  @JsonValue('auto')
  auto,
  @JsonValue('approve')
  approve,
  @JsonValue('smart_approve')
  smartApprove,
  @JsonValue('chat')
  chat,
  @JsonValue('__unknown__')
  unknown,
}
