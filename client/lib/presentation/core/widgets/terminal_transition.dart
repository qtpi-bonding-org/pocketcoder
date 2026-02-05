import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TerminalTransition {
  static CustomTransitionPage<void> buildPage<T>({
    required BuildContext context,
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration:
          const Duration(milliseconds: 700), // Slower, more deliberate
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Linear curve for mechanical "scan" feel
        final curve = CurvedAnimation(parent: animation, curve: Curves.linear);

        return Stack(
          children: [
            // 1. Instant Wipe: A solid background covers the previous page immediately.
            Container(color: const Color(0xFF0D0D0D)),

            // 2. The Content Reveal
            AnimatedBuilder(
              animation: curve,
              builder: (context, child) {
                return Stack(
                  children: [
                    // The Page Content (Clipped)
                    ClipRect(
                      clipper: _ScanlineClipper(curve.value),
                      child: child,
                    ),

                    // The Glowing Scanline Head
                    if (curve.value < 1.0)
                      Positioned(
                        top: MediaQuery.of(context).size.height * curve.value,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            color: const Color(0xFF39FF14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF39FF14)
                                    .withValues(alpha: 0.6),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
              child: child,
            ),
          ],
        );
      },
    );
  }
}

class _ScanlineClipper extends CustomClipper<Rect> {
  final double progress;

  _ScanlineClipper(this.progress);

  @override
  Rect getClip(Size size) {
    // Reveal from top (0) to bottom (height)
    return Rect.fromLTWH(0, 0, size.width, size.height * progress);
  }

  @override
  bool shouldReclip(_ScanlineClipper oldClipper) =>
      oldClipper.progress != progress;
}
