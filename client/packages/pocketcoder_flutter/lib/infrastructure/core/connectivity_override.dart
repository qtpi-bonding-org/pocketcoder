import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';

/// An override for the [ConnectivityPlatform] that always reports online status.
///
/// This is specifically used to workaround an issue in Chrome Incognito where
/// `connectivity_plus` incorrectly reports that no network interfaces are available,
/// causing plugins like `pocketbase_drift` to falsely believe the device is offline
/// and fail before even attempting a network request.
class WebConnectivityOverride extends ConnectivityPlatform {
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async =>
      [ConnectivityResult.wifi];

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      Stream.value([ConnectivityResult.wifi]);
}
