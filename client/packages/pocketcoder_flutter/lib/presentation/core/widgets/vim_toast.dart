import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

enum VimToastType { info, success, warning }

class VimToast extends StatelessWidget {
  final String message;
  final Color? color;
  final VimToastType type;

  static OverlayEntry? _overlayEntry;

  const VimToast({
    super.key,
    required this.message,
    this.color,
    this.type = VimToastType.info,
  });

  static void show(
    BuildContext context,
    String message, {
    Color? color,
    VimToastType type = VimToastType.info,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    showOn(overlay, message, color: color, type: type);
  }

  static void showOn(
    OverlayState overlay,
    String message, {
    Color? color,
    VimToastType type = VimToastType.info,
  }) {
    _overlayEntry?.remove();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.viewPaddingOf(context).top + AppSizes.space,
        left: AppSizes.space,
        right: AppSizes.space,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _remove(entry),
              onVerticalDragEnd: (_) => _remove(entry),
              child: VimToast(message: message, color: color, type: type),
            ),
          ),
        ),
      ),
    );
    _overlayEntry = entry;
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3), () => _remove(entry));
  }

  static void _remove(OverlayEntry entry) {
    if (_overlayEntry != entry) return;
    entry.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final accentColor = color ??
        switch (type) {
          VimToastType.info => colors.onSurface,
          VimToastType.success => colors.primary,
          VimToastType.warning => context.terminalColors.warning,
        };

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
