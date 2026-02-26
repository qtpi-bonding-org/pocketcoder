import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'whitelist_action.freezed.dart';
part 'whitelist_action.g.dart';

@freezed
class WhitelistAction with _$WhitelistAction {
  const factory WhitelistAction({
    required String id,
    required String permission,
    @JsonKey(unknownEnumValue: WhitelistActionKind.unknown) WhitelistActionKind? kind,
    String? value,
    bool? active,
  }) = _WhitelistAction;

  factory WhitelistAction.fromRecord(RecordModel record) =>
      WhitelistAction.fromJson(record.toJson());

  factory WhitelistAction.fromJson(Map<String, dynamic> json) =>
      _$WhitelistActionFromJson(json);
}

enum WhitelistActionKind {
  @JsonValue('strict')
  strict,
  @JsonValue('pattern')
  pattern,
  @JsonValue('__unknown__')
  unknown,
}
