import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'live_activitie.freezed.dart';
part 'live_activitie.g.dart';

@freezed
abstract class LiveActivitie with _$LiveActivitie {
  const factory LiveActivitie({
    required String id,
    required String device,
    required String chat,
    required String user,
    @JsonKey(unknownEnumValue: LiveActivitiePlatform.unknown)
    required LiveActivitiePlatform platform,
    @JsonKey(unknownEnumValue: LiveActivitieStatus.unknown)
    required LiveActivitieStatus status,
    String? activityPushToken,
    required double contentStateVersion,
    DateTime? created,
    DateTime? updated,
    DateTime? expiresAt,
    DateTime? lastPushAt,
    DateTime? endedAt,
    String? lastError,
  }) = _LiveActivitie;

  factory LiveActivitie.fromRecord(RecordModel record) =>
      LiveActivitie.fromJson(record.toJson());

  factory LiveActivitie.fromJson(Map<String, dynamic> json) =>
      _$LiveActivitieFromJson(json);
}

enum LiveActivitiePlatform {
  @JsonValue('ios')
  ios,
  @JsonValue('android')
  android,
  @JsonValue('__unknown__')
  unknown,
}

enum LiveActivitieStatus {
  @JsonValue('active')
  active,
  @JsonValue('ended')
  ended,
  @JsonValue('expired')
  expired,
  @JsonValue('failed')
  failed,
  @JsonValue('__unknown__')
  unknown,
}
