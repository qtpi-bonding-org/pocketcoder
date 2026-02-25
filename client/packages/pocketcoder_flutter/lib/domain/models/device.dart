import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'device.freezed.dart';
part 'device.g.dart';

@freezed
class Device with _$Device {
  const factory Device({
    required String id,
    required String user,
    required String name,
    required String pushToken,
    required DevicePushService pushService,
    bool? isActive,
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
