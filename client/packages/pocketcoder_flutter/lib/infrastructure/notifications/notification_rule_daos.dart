import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/models/notification_rule.dart';
import 'package:pocketcoder_flutter/infrastructure/core/base_dao.dart';
import "package:pocketcoder_flutter/domain/models/collections.dart";

@lazySingleton
class NotificationRuleDao extends BaseDao<NotificationRule> {
  NotificationRuleDao(PocketBase pb)
      : super(pb, Collections.notificationRules, NotificationRule.fromJson);
}
