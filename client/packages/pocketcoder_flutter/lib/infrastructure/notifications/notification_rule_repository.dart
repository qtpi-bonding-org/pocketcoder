import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/notifications/i_notification_rule_repository.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/core/try_operation.dart';
import 'notification_rule_daos.dart';

@LazySingleton(as: INotificationRuleRepository)
class NotificationRuleRepository implements INotificationRuleRepository {
  final NotificationRuleDao _dao;
  final PocketBase _pb;

  NotificationRuleRepository(this._dao, this._pb);

  @override
  Stream<Map<String, bool>> watchRules() {
    final userId = _pb.authStore.record?.id;
    if (userId == null) return Stream.value(const {});
    return _dao
        .watch(filter: 'user = "$userId"')
        .map((rows) => rows.isEmpty ? const {} : _asBoolMap(rows.first.rules));
  }

  @override
  Future<void> setTypeEnabled(String type, bool enabled) async {
    return tryMethod(
      () async {
        final userId = _pb.authStore.record?.id;
        if (userId == null) return;

        final existing = await _dao.getFullList(filter: 'user = "$userId"');
        final current = existing.isEmpty
            ? <String, bool>{}
            : _asBoolMap(existing.first.rules);
        final merged = {...current, type: enabled};

        if (existing.isEmpty) {
          await _dao.save(null, {'user': userId, 'rules': merged});
        } else {
          await _dao.save(existing.first.id, {'rules': merged});
        }
      },
      RepositoryException.new,
      'setTypeEnabled',
    );
  }

  Map<String, bool> _asBoolMap(dynamic raw) {
    if (raw is! Map) return const {};
    return raw.map((key, value) => MapEntry(key.toString(), value == true));
  }
}
