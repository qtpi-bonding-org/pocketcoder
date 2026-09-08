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
        top: MediaQuery.viewPaddingOf(context).top,
        left: 0,
        right: 0,
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
          VimToastType.info => colors.primary,
          VimToastType.success => colors.primary,
          VimToastType.warning => context.terminalColors.warning,
        };

    // Full-bleed solid fill, not translucent -- must never blend into
    // scrolling terminal content underneath it.
    return Container(
      width: double.infinity,
      color: accentColor,
      padding: EdgeInsets.symmetric(
        vertical: AppSizes.space * 0.75,
        horizontal: AppSizes.space,
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: colors.onPrimary,
          fontFamily: AppFonts.family,
          package: 'pocketcoder_flutter',
          fontWeight: AppFonts.heavy,
        ),
      ),
    );
  }
}
