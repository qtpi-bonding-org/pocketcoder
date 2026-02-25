import 'package:equatable/equatable.dart';

class Device extends Equatable {
  final String id;
  final String userId;
  final String name;
  final String pushToken;
  final String pushService;
  final bool isActive;

  const Device({
    required this.id,
    required this.userId,
    required this.name,
    required this.pushToken,
    required this.pushService,
    required this.isActive,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as String,
      userId: json['user'] as String,
      name: json['name'] as String,
      pushToken: json['push_token'] as String,
      pushService: json['push_service'] as String,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  @override
  List<Object?> get props =>
      [id, userId, name, pushToken, pushService, isActive];
}

abstract class IDeviceRepository {
  /// Register or update a device for push notifications.
  Future<void> registerDevice({
    required String name,
    required String pushToken,
    required String pushService,
  });

  /// Deactivate or remove a device registration.
  Future<void> unregisterDevice(String pushToken);
}
