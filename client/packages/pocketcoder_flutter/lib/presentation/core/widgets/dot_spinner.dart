import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

/// The braille spinner, drawn rather than typed.
///
/// Noto Sans Mono carries no braille codepoint (0 of U+2800..U+28FF), so the
/// glyphs fall back to a system face with a different advance and land as
/// tofu off the character grid. Painting the 2x4 dot cell keeps the shape and
/// stays on the grid at exactly one character wide.
class DotSpinner extends StatefulWidget {
  const DotSpinner({super.key, this.role = TextRole.value});

  final TextRole role;

  /// Perimeter order of the braille cell's eight dots, clockwise from the
  /// top-left. Each frame drops the dot at one position, and the gap travels.
  static const ring = <(int, int)>[
    (0, 0), (1, 0), (1, 1), (1, 2), (1, 3), (0, 3), (0, 2), (0, 1),
  ];

  @override
  State<DotSpinner> createState() => _DotSpinnerState();
}

class _DotSpinnerState extends State<DotSpinner> {
  Timer? _timer;
  int _frame = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer?.cancel();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return;
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() => _frame = (_frame + 1) % DotSpinner.ring.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: AppSizes.ch,
        height: AppSizes.line,
        child: CustomPaint(
          painter: _DotCellPainter(color: widget.role.color, gap: _frame),
        ),
      );
}

class _DotCellPainter extends CustomPainter {
  const _DotCellPainter({required this.color, required this.gap});

  final Color color;
  final int gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final cellW = size.width / 2;
    final cellH = size.height / 4;
    final radius = (cellW < cellH ? cellW : cellH) * 0.42;
    for (var i = 0; i < DotSpinner.ring.length; i++) {
      if (i == gap) continue;
      final (col, row) = DotSpinner.ring[i];
      canvas.drawCircle(
        Offset((col + 0.5) * cellW, (row + 0.5) * cellH),
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DotCellPainter old) =>
      old.gap != gap || old.color != color;
}
