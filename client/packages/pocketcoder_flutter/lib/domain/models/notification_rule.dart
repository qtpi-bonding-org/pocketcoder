import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'notification_rule.freezed.dart';
part 'notification_rule.g.dart';

@freezed
class NotificationRule with _$NotificationRule {
  const factory NotificationRule({
    required String id,
    required String user,
    dynamic rules,
  }) = _NotificationRule;

  factory NotificationRule.fromRecord(RecordModel record) =>
      NotificationRule.fromJson(record.toJson());

  factory NotificationRule.fromJson(Map<String, dynamic> json) =>
      _$NotificationRuleFromJson(json);
}
