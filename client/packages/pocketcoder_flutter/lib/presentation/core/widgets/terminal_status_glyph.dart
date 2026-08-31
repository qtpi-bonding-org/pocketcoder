import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

enum TerminalStatus { running, success, failure, attention }

/// A small terminal-native status marker: spinner while active, then a
/// stable result glyph. Callers own lifecycle state; this only animates the
/// running glyph.
class TerminalStatusGlyph extends StatefulWidget {
  const TerminalStatusGlyph({
    super.key,
    required this.status,
    this.fontSize,
  });

  final TerminalStatus status;
  final double? fontSize;

  @override
  State<TerminalStatusGlyph> createState() => _TerminalStatusGlyphState();
}

class _TerminalStatusGlyphState extends State<TerminalStatusGlyph> {
  static const _frames = ['|', '/', '-', '\\'];
  Timer? _timer;
  int _frameIndex = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(covariant TerminalStatusGlyph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _syncTimer();
    }
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
    if (widget.status != TerminalStatus.running || reduceMotion) return;
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

  String get _glyph => switch (widget.status) {
        TerminalStatus.running => _frames[_frameIndex],
        TerminalStatus.success => '✓',
        TerminalStatus.failure => '×',
        TerminalStatus.attention => '!',
      };

  Color _color(BuildContext context) => switch (widget.status) {
        TerminalStatus.running => context.colorScheme.secondary,
        TerminalStatus.success => context.colorScheme.secondary,
        TerminalStatus.failure => context.terminalColors.warning,
        TerminalStatus.attention => context.terminalColors.warning,
      };

  @override
  Widget build(BuildContext context) {
    return Text(
      _glyph,
      style: TextStyle(
        color: _color(context),
        fontFamily: AppFonts.bodyFamily,
        fontSize: widget.fontSize ?? AppSizes.fontStandard,
        fontWeight: AppFonts.heavy,
        package: 'pocketcoder_flutter',
      ),
    );
  }
}
