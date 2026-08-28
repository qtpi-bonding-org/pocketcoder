import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/core/try_operation.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/domain/live_activities/i_live_activity_repository.dart';
import 'package:pocketcoder_flutter/domain/models/live_activitie.dart';
import 'package:pocketcoder_flutter/infrastructure/core/pocketcoder_api_client.dart';
import 'live_activity_dao.dart';

@LazySingleton(as: ILiveActivityRepository)
class LiveActivityRepository implements ILiveActivityRepository {
  final LiveActivityDao _dao;
  final PocketCoderApiClient _api;
  final PocketBase _pb;

  LiveActivityRepository(this._dao, this._api, this._pb);

  /// Apple hard-errors ActivityKit's `Activity.request()` with
  /// `tooManyRequests` past 8 concurrent Live Activities per app; this cap
  /// stays under that so the client never needs to handle that error.
  static const maxConcurrentActivities = 5;

  @override
  Future<LiveActivitie> startActivity({
    required String chatId,
    required String deviceId,
    required String platform,
    String? activityPushToken,
  }) async {
    return tryMethod(
      () async {
        final userId = _pb.authStore.record?.id;
        if (userId == null) {
          throw LiveActivityException('User not authenticated');
        }

        final active = await _dao.getFullList(
          filter: 'user = "$userId" && status = "active"',
        );
        if (active.length >= maxConcurrentActivities) {
          throw LiveActivityException(
            'Live activity limit reached ($maxConcurrentActivities)',
          );
        }

        try {
          return await _dao.save(null, {
            'user': userId,
            'device': deviceId,
            'chat': chatId,
            'platform': platform,
            'status': 'active',
            'activity_push_token': activityPushToken,
            'content_state_version': 1,
          });
        } on ClientException catch (e) {
          // The collection enforces one active row per (device, chat) pair
          // via a unique partial index (status = 'active'); a 400 here can
          // mean that constraint tripped rather than a genuine validation
          // failure. Treat it as idempotent: hand back the row that's
          // already active instead of surfacing an error to the caller.
          if (e.statusCode != 400) rethrow;
          final existing = await getActiveActivity(
            chatId: chatId,
            deviceId: deviceId,
          );
          if (existing == null) rethrow;
          return existing;
        }
      },
      LiveActivityException.new,
      'startActivity',
    );
  }

  @override
  Future<void> endActivity(String id) async {
    return tryMethod(
      () async {
        await _api.liveActivities.endLiveActivity(id: id);
      },
      LiveActivityException.new,
      'endActivity',
    );
  }

  @override
  Future<LiveActivitie?> getActiveActivity({
    required String chatId,
    required String deviceId,
  }) async {
    return tryMethod(
      () async {
        final result = await _dao.getFullList(
          filter:
              'chat = "$chatId" && device = "$deviceId" && status = "active"',
        );
        return result.isEmpty ? null : result.first;
      },
      LiveActivityException.new,
      'getActiveActivity',
    );
  }
}
