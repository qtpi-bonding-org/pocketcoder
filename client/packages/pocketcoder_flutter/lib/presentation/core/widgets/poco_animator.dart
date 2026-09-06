import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/poco.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'ascii_art.dart';
import 'poco_posture_scope.dart';

const _idleFrameDuration = Duration(milliseconds: 2000);

class PocoAnimator extends StatefulWidget {
  final double? fontSize;
  final Color? color;
  final PocoMood? mood;
  final PocoPosture? posture;

  /// Empty means random idle cycling, not "no animation."
  final List<(String, int)> sequence;
  const PocoAnimator({
    super.key,
    this.fontSize,
    this.color,
    this.mood,
    this.posture,
    this.sequence = const [],
  });
  @override
  State<PocoAnimator> createState() => _PocoAnimatorState();
}

class _PocoAnimatorState extends State<PocoAnimator> {
  late String _currentFace;
  Timer? _timer;
  int _currentIndex = 0;
  final _random = Random();

  bool get _isRandomIdle => widget.sequence.isEmpty;

  @override
  void initState() {
    super.initState();
    if (_isRandomIdle) {
      _currentFace = _randomGreenHappyFace();
    } else {
      _currentFace = widget.sequence[0].$1;
    }
    _scheduleNextFrame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _randomGreenHappyFace() => PocoExpression
      .greenHappy[_random.nextInt(PocoExpression.greenHappy.length)];

  void _scheduleNextFrame() {
    final delay =
        _isRandomIdle ? _idleFrameDuration : Duration(
            milliseconds: widget.sequence[_currentIndex].$2);
    _timer = Timer(delay, _advanceFrame);
  }

  void _advanceFrame() {
    if (!mounted) return;
    setState(() {
      if (_isRandomIdle) {
        _currentFace = _randomGreenHappyFace();
      } else {
        _currentIndex = (_currentIndex + 1) % widget.sequence.length;
        _currentFace = widget.sequence[_currentIndex].$1;
      }
    });
    _scheduleNextFrame();
  }

  @override
  Widget build(BuildContext context) => AsciiFace(
      expression: _currentFace,
      fontSize: widget.fontSize ?? AppSizes.fontPoco,
      color: widget.color,
      mood: widget.mood,
      posture: widget.posture ?? PocoPostureScope.of(context));
}
