import 'package:freezed_annotation/freezed_annotation.dart';

part 'whitelist_action.freezed.dart';
part 'whitelist_action.g.dart';

@freezed
class WhitelistAction with _$WhitelistAction {
  const factory WhitelistAction({
    required String id,
    required String permission,
    required WhitelistActionKind kind,
    String? value,
    @Default(true) bool active,
    DateTime? created,
    DateTime? updated,
  }) = _WhitelistAction;

  factory WhitelistAction.fromJson(Map<String, dynamic> json) =>
      _$WhitelistActionFromJson(json);
}

enum WhitelistActionKind {
  @JsonValue('strict')
  strict,
  @JsonValue('pattern')
  pattern,
}
