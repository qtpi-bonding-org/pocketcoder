import 'package:flutter/material.dart';
import '../../../design_system/theme/app_theme.dart';

class ScanlineWidget extends StatelessWidget {
  final Widget child;

  const ScanlineWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.0),
                  Colors.white.withValues(alpha: 0.02),
                  Colors.white.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
        IgnorePointer(
          child: _ScanlineOverlay(),
        ),
      ],
    );
  }
}

class _ScanlineOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final terminalColors = context.terminalColors;
    return CustomPaint(
      painter: _ScanlinePainter(
        color: terminalColors.scanline,
        opacity: terminalColors.scanlineOpacity,
      ),
      child: Container(),
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  final Color color;
  final double opacity;

  _ScanlinePainter({required this.color, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..strokeWidth = 1.0;

    for (double i = 0; i < size.height; i += 3) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScanlinePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.opacity != opacity;
  }
}
