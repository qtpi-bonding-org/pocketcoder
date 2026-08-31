import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/models/collections.dart';
import 'package:pocketcoder_flutter/domain/models/live_activitie.dart';
import 'package:pocketcoder_flutter/infrastructure/core/base_dao.dart';

@lazySingleton
class LiveActivityDao extends BaseDao<LiveActivitie> {
  LiveActivityDao(PocketBase pb)
      : super(pb, Collections.liveActivities, LiveActivitie.fromJson);
}
