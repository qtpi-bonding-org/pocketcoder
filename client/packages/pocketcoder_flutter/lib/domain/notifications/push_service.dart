import 'package:equatable/equatable.dart';

abstract class PushService {
  /// Initialize the push service.
  Future<void> initialize();

  /// Request user authorization for permission relays.
  Future<bool> requestPermissions();

  /// Stream of incoming permission relay signals.
  Stream<PushNotificationPayload> get notificationStream;

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
