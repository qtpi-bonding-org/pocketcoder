import 'device.dart';

abstract class IDeviceRepository {
  /// Register or update a device for push notifications.
  Future<void> registerDevice({
    required String name,
    required String pushToken,
    required String pushService,
  });

  /// Deactivate or remove a device registration.
  Future<void> unregisterDevice(String pushToken);

  /// Fetch all active devices for the current user.
  Future<List<Device>> getDevices();
}
