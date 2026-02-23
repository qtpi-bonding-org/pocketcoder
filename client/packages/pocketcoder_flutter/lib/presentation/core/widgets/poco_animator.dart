import 'dart:async';
import 'package:flutter/material.dart';
import '../../../design_system/theme/app_theme.dart';
import 'ascii_art.dart';

class PocoAnimator extends StatefulWidget {
  final double? fontSize;
  final Color? color;
  final List<(String, int)> sequence;

  const PocoAnimator({
    super.key,
    this.fontSize,
    this.color,
    this.sequence = const [
      (PocoExpression.awake, 2000),
      (PocoExpression.sleepy, 150), // Blink
      (PocoExpression.thinking, 3000),
      (PocoExpression.happy, 2000),
      (PocoExpression.awake, 2500),
      (PocoExpression.sleepy, 150), // Blink
    ],
  });

  @override
  State<PocoAnimator> createState() => _PocoAnimatorState();
}

class _PocoAnimatorState extends State<PocoAnimator> {
  late String _currentFace;
  Timer? _timer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.sequence.isNotEmpty) {
      _currentFace = widget.sequence[0].$1;
      _scheduleNextFrame();
    } else {
      _currentFace = PocoExpression.awake;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _scheduleNextFrame() {
    if (widget.sequence.isEmpty) return;

    final durationMs = widget.sequence[_currentIndex].$2;
    _timer = Timer(Duration(milliseconds: durationMs), _advanceFrame);
  }

  void _advanceFrame() {
    if (!mounted) return;

    setState(() {
      _currentIndex = (_currentIndex + 1) % widget.sequence.length;
      _currentFace = widget.sequence[_currentIndex].$1;
    });

    _scheduleNextFrame();
  }

  @override
  Widget build(BuildContext context) {
    return AsciiFace(
      expression: _currentFace,
      fontSize: widget.fontSize ?? AppSizes.fontStandard,
      color: widget.color ?? context.colorScheme.onSurface,
    );
  }
}
