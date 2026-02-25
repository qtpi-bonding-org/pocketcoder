import 'package:freezed_annotation/freezed_annotation.dart';

part 'device.freezed.dart';
part 'device.g.dart';

@freezed
class Device with _$Device {
  const factory Device({
    required String id,
    required String user,
    required String name,
    required String pushToken,
    required String pushService,
    @Default(true) bool isActive,
    DateTime? created,
    DateTime? updated,
  }) = _Device;

  factory Device.fromJson(Map<String, dynamic> json) => _$DeviceFromJson(json);
}
