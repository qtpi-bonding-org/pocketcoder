import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

class VimToast extends StatelessWidget {
  final String message;
  final Color? color;

  const VimToast({
    super.key,
    required this.message,
    this.color,
  });

  /// Shows [message] as a terminal toast on the nearest [ScaffoldMessenger].
  ///
  /// Always use this instead of `showSnackBar(SnackBar(...))` — a bare
  /// [SnackBar] renders Material's grey rounded surface in Roboto, which is
  /// jarringly off-theme against the phosphor CRT chrome.
  static void show(
    BuildContext context,
    String message, {
    Color? color,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    showOn(messenger, message, color: color);
  }

  /// Variant for callers that captured a messenger before an `await`, so they
  /// never touch a [BuildContext] across an async gap.
  static void showOn(
    ScaffoldMessengerState messenger,
    String message, {
    Color? color,
  }) {
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: VimToast(message: message, color: color),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final accentColor = color ?? colors.onSurface;

    // Calculate dashes based on message length (min 40)
    final int dashCount = (message.length + 4).clamp(40, 60);
    final String dashes = '-' * dashCount;

    return Container(
      padding: EdgeInsets.symmetric(vertical: AppSizes.space),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            dashes,
            style: TextStyle(
              color: accentColor.withValues(alpha: 0.5),
              fontFamily: AppFonts.bodyFamily,
              package: 'pocketcoder_flutter',
              fontSize: AppSizes.fontTiny,
              height: 0.5,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: AppSizes.space * 0.5),
            child: Text(
              ' $message ',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: accentColor,
                fontFamily: AppFonts.bodyFamily,
                package: 'pocketcoder_flutter',
                fontSize: AppSizes.fontTiny,
                fontWeight: AppFonts.heavy,
              ),
            ),
          ),
          Text(
            dashes,
            style: TextStyle(
              color: accentColor.withValues(alpha: 0.5),
              fontFamily: AppFonts.bodyFamily,
              package: 'pocketcoder_flutter',
              fontSize: AppSizes.fontTiny,
              height: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
