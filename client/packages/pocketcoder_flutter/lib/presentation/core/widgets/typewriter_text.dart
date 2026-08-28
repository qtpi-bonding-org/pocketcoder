import 'dart:async';
import 'package:flutter/material.dart';

class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration speed;
  final VoidCallback? onComplete;

  /// When true, skips the incremental reveal entirely: [text] renders in
  /// full on the first frame and [onComplete] fires once, synchronously.
  /// For a message the caller already knows has been shown before (e.g. a
  /// list item recycled back into view on scrollback), so it doesn't replay
  /// the animation as if it were appearing for the first time.
  final bool instant;

  const TypewriterText({
    super.key,
    required this.text,
    this.style,
    this.speed = const Duration(milliseconds: 10),
    this.onComplete,
    this.instant = false,
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  String _displayedText = '';
  Timer? _timer;
  int _currentIndex = 0;
  int _elapsedMicros = 0;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  @override
  void didUpdateWidget(TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.instant != widget.instant) {
      _startTyping();
    }
  }

  void _startTyping() {
    _timer?.cancel();

    if (widget.instant) {
      setState(() {
        _displayedText = widget.text;
        _currentIndex = widget.text.length;
        _elapsedMicros = 0;
      });
      widget.onComplete?.call();
      return;
    }

    _displayedText = '';
    _currentIndex = 0;
    _elapsedMicros = 0;

    // Flutter can only paint at frame rate. Scheduling a setState for every
    // character (especially at 1 ms) overloads the UI thread and can feel
    // slower than a larger delay. Sample at frame cadence and reveal all
    // characters that should have appeared since the last frame instead.
    _timer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) return;

      _elapsedMicros += const Duration(milliseconds: 16).inMicroseconds;
      final speedMicros = widget.speed.inMicroseconds.clamp(1, 1 << 30);
      final targetIndex = (_elapsedMicros / speedMicros)
          .floor()
          .clamp(0, widget.text.length)
          .toInt();

      if (_currentIndex < targetIndex) {
        setState(() {
          _currentIndex = targetIndex;
          _displayedText = widget.text.substring(0, _currentIndex);
        });
      }

      if (_currentIndex >= widget.text.length) {
        timer.cancel();
        widget.onComplete?.call();
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
    return Text(
      _displayedText,
      style: widget.style,
      softWrap: true,
    );
  }
}
