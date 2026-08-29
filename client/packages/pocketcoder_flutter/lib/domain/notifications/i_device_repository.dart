import 'package:pocketcoder_flutter/domain/models/device.dart';

abstract class IDeviceRepository {
  /// Register or update a device for push notifications.
  Future<void> registerDevice({
    required String name,
    required String pushToken,
    required String pushService,
  });

  /// Deactivate or remove a device registration.
  Future<void> unregisterDevice(String pushToken);

  /// Store the iOS Live Activities push-to-start token for this device.
  Future<void> setPushToStartToken(String pushToken, String pushToStartToken);

  /// Fetch all active devices for the current user.
  Future<List<Device>> getDevices();
}
