import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TerminalTransition {
  static CustomTransitionPage<void> buildPage<T>({
    required BuildContext context,
    required GoRouterState state,
    required Widget child,
  }) {
    final colors = Theme.of(context).colorScheme;

    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 700),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(parent: animation, curve: Curves.linear);

        return Stack(
          children: [
            Container(color: colors.surface),
            AnimatedBuilder(
              animation: curve,
              builder: (context, child) {
                return Stack(
                  children: [
                    ClipRect(
                      clipper: _ScanlineClipper(curve.value),
                      child: child,
                    ),
                    if (curve.value < 1.0)
                      Positioned(
                        top: MediaQuery.of(context).size.height * curve.value,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            color: colors.primary,
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
    return Rect.fromLTWH(0, 0, size.width, size.height * progress);
  }

  @override
  bool shouldReclip(_ScanlineClipper oldClipper) =>
      oldClipper.progress != progress;
}
