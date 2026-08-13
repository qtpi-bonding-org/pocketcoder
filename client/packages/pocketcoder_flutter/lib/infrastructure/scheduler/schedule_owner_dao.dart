import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/models/collections.dart';
import 'package:pocketcoder_flutter/domain/models/schedule_owner.dart';
import 'package:pocketcoder_flutter/infrastructure/core/base_dao.dart';

@lazySingleton
class ScheduleOwnerDao extends BaseDao<ScheduleOwner> {
  ScheduleOwnerDao(PocketBase pb)
      : super(pb, Collections.scheduleOwners, ScheduleOwner.fromJson);
}
