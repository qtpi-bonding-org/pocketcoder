import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import '../../../domain/notifications/push_service.dart';
import '../../../app_router.dart';

class NotificationWrapper extends StatefulWidget {
  final Widget child;

  const NotificationWrapper({super.key, required this.child});

  @override
  State<NotificationWrapper> createState() => _NotificationWrapperState();
}

class _NotificationWrapperState extends State<NotificationWrapper> {
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = GetIt.I<PushService>().notificationStream.listen((payload) {
      if (payload.wasTapped) {
        // Only navigate if the user explicitly tapped the notification
        AppRouter.router.goNamed(RouteNames.home);
      } else {
        // If the app is in foreground, show a subtle terminal toast
        _showInAppNotification(payload);
      }
    });
  }

  void _showInAppNotification(PushNotificationPayload payload) {
    try {
      final feedback = GetIt.I<IFeedbackService>();
      feedback.show(FeedbackMessage(
        message: "SIGNAL RECEIVED: ${payload.title}",
        type: MessageType.info,
      ));
    } catch (_) {
      // Feedback service might not be ready yet during bootstrap
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
