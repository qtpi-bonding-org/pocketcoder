import 'package:pocketcoder_flutter/domain/models/live_activitie.dart';

abstract class ILiveActivityRepository {
  /// Starts (or resumes) a live activity for [chatId] on [deviceId].
  ///
  /// The `live_activities` collection enforces one active row per
  /// (device, chat) pair via a unique index — calling this again for a
  /// device/chat pair that already has an active row is not an error: the
  /// existing active row is returned instead of a duplicate being created.
  Future<LiveActivitie> startActivity({
    required String chatId,
    required String deviceId,
    required String platform,
    String? activityPushToken,
  });

  /// Ends an activity the current user owns. No-op-safe from the caller's
  /// perspective on an already-ended row (server returns 409, surfaced as
  /// [LiveActivityException]).
  Future<void> endActivity(String id);

  /// The current active activity for [chatId] on [deviceId], if any.
  Future<LiveActivitie?> getActiveActivity({
    required String chatId,
    required String deviceId,
  });

  /// All active activities owned by the signed-in user.
  ///
  /// This is used to reconstruct the deterministic ActivityKit-id-to-row-id
  /// correlation after an app relaunch.
  Future<List<LiveActivitie>> getActiveActivities();
}
