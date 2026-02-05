import 'dart:async';
import 'package:flutter/material.dart';
import 'ascii_art.dart';

class PocoAnimator extends StatefulWidget {
  final double fontSize;
  final Color color;
  final List<(String, int)> sequence;

  const PocoAnimator({
    super.key,
    this.fontSize = 16,
    this.color = const Color(0xFF39FF14),
    this.sequence = const [
      (AppAscii.pocoAwake, 2000),
      (AppAscii.pocoSleepy, 150), // Blink
      (AppAscii.pocoAwake, 3000),
      (AppAscii.pocoHappy, 2000),
      (AppAscii.pocoAwake, 2500),
      (AppAscii.pocoSleepy, 150), // Blink
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
      _currentFace = AppAscii.pocoAwake;
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
      face: _currentFace,
      fontSize: widget.fontSize,
      color: widget.color,
    );
  }
}
