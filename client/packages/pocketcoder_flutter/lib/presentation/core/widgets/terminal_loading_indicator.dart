import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

class TerminalLoadingIndicator extends StatefulWidget {
  final String? label;

  const TerminalLoadingIndicator({
    super.key,
    this.label,
  });

  @override
  State<TerminalLoadingIndicator> createState() =>
      _TerminalLoadingIndicatorState();
}

class _TerminalLoadingIndicatorState extends State<TerminalLoadingIndicator> {
  int _frameIndex = 0;
  Timer? _timer;
  final List<String> _frames = ['|', '/', '-', '\\'];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted) {
        setState(() {
          _frameIndex = (_frameIndex + 1) % _frames.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _frames[_frameIndex],
          style: TextStyle(
            fontFamily: AppFonts.bodyFamily,
            color: colors.primary,
            fontSize: AppSizes.fontLarge,
            fontWeight: AppFonts.heavy,
            package: 'pocketcoder_flutter',
          ),
        ),
        if (widget.label != null) ...[
          VSpace.x1,
          Text(
            '[ ${widget.label!.toUpperCase()} ]',
            style: TextStyle(
              fontFamily: AppFonts.bodyFamily,
              color: colors.onSurface.withValues(alpha: 0.7),
              fontSize: AppSizes.fontTiny,
              package: 'pocketcoder_flutter',
            ),
          ),
        ],
      ],
    );
  }
}
