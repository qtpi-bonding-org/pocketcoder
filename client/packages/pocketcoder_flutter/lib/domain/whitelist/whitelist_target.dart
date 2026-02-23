import 'package:freezed_annotation/freezed_annotation.dart';

part 'whitelist_target.freezed.dart';
part 'whitelist_target.g.dart';

@freezed
class WhitelistTarget with _$WhitelistTarget {
  const factory WhitelistTarget({
    required String id,
    required String name,
    required String pattern,
    @Default(true) bool active,
    DateTime? created,
    DateTime? updated,
  }) = _WhitelistTarget;

  factory WhitelistTarget.fromJson(Map<String, dynamic> json) =>
      _$WhitelistTargetFromJson(json);
}
