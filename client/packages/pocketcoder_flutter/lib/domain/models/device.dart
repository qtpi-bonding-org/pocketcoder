import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'device.freezed.dart';
part 'device.g.dart';

@freezed
abstract class Device with _$Device {
  const factory Device({
    required String id,
    required String user,
    required String name,
    required String pushToken,
    @JsonKey(unknownEnumValue: DevicePushService.unknown) required DevicePushService pushService,
    bool? isActive,
    DateTime? created,
    DateTime? updated,
    @JsonKey(unknownEnumValue: DevicePlatform.unknown) DevicePlatform? platform,
    String? pushToStartToken,
  }) = _Device;

  factory Device.fromRecord(RecordModel record) =>
      Device.fromJson(record.toJson());

  factory Device.fromJson(Map<String, dynamic> json) =>
      _$DeviceFromJson(json);
}

enum DevicePushService {
  @JsonValue('fcm')
  fcm,
  @JsonValue('unifiedpush')
  unifiedpush,
  @JsonValue('__unknown__')
  unknown,
}

enum DevicePlatform {
  @JsonValue('ios')
  ios,
  @JsonValue('android')
  android,
  @JsonValue('__unknown__')
  unknown,
}
