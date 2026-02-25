import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'whitelist_target.freezed.dart';
part 'whitelist_target.g.dart';

@freezed
class WhitelistTarget with _$WhitelistTarget {
  const factory WhitelistTarget({
    required String id,
    required String name,
    required String pattern,
    bool? active,
  }) = _WhitelistTarget;

  factory WhitelistTarget.fromRecord(RecordModel record) =>
      WhitelistTarget.fromJson(record.toJson());

  factory WhitelistTarget.fromJson(Map<String, dynamic> json) =>
      _$WhitelistTargetFromJson(json);
}
