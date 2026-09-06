import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

class TerminalSpinner extends StatefulWidget {
  const TerminalSpinner({super.key});

  // Braille frames are not in Noto Sans Mono's cmap (0/10 covered) and fall
  // back to a system font with a different advance width, breaking the
  // character grid and rendering as unrelated tofu glyphs. The block set is
  // fully covered (8/8) -- see test/design_system/font_glyph_coverage_test.dart.
  static const frames = ['▁', '▂', '▃', '▄', '▅', '▆', '▇', '█'];

  @override
  State<TerminalSpinner> createState() => _TerminalSpinnerState();
}

class _TerminalSpinnerState extends State<TerminalSpinner> {
  Timer? _timer;
  int _frameIndex = 0;
  static const _frames = TerminalSpinner.frames;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTimer();
  }

  void _syncTimer() {
    _timer?.cancel();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) return;
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() => _frameIndex = (_frameIndex + 1) % _frames.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      TerminalText(_frames[_frameIndex], role: TextRole.body);
}
