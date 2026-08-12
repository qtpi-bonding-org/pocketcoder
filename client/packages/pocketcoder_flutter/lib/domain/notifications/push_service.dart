import 'package:equatable/equatable.dart';

abstract class PushService {
  /// Initialize provider listeners without prompting the user.
  Future<void> initialize();

  /// Request user authorization for permission relays.
  Future<bool> requestPermissions();

  /// Registers the current device against the authenticated PocketBase user
  /// when notification permission and a provider token are available.
  Future<void> syncAuthenticatedDevice();

  /// Deactivates the current device on the authenticated deployment.
  ///
  /// Call before clearing PocketBase authentication so the repository can
  /// still identify the device owner.
  Future<void> unregisterAuthenticatedDevice();

  /// Stream of incoming permission relay signals.
  Stream<PushNotificationPayload> get notificationStream;

  /// The notification that launched the app from a fully terminated
  /// state (not just backgrounded), if any. `notificationStream` only
  /// ever carries taps that happen while the process is already
  /// running, so a cold start via notification tap needs this instead.
  /// Returns null if the app wasn't launched by a notification tap.
  Future<PushNotificationPayload?> getInitialNotification();

  /// Get the push token for the device.
  Future<String?> getToken();

  /// Open configuration settings for the service.
  Future<void> configure();
}

class PushNotificationPayload extends Equatable {
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final bool wasTapped;

  const PushNotificationPayload({
    required this.title,
    required this.body,
    required this.data,
    this.wasTapped = false,
  });

  @override
  List<Object?> get props => [title, body, data, wasTapped];
}
