import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/poco.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'ascii_art.dart';
import 'poco_gaze_scope.dart';
import 'poco_posture_scope.dart';

const _gazeThreshold = 40.0;

const _idleFrameDuration = Duration(milliseconds: 2000);

class PocoAnimator extends StatefulWidget {
  final double? fontSize;
  final Color? color;
  final PocoMood? mood;
  final PocoPosture? posture;

  /// Empty means random idle cycling, not "no animation."
  final List<(String, int)> sequence;

  /// Null means [sequence] governs the face instead.
  final bool? isAgentTurn;
  const PocoAnimator({
    super.key,
    this.fontSize,
    this.color,
    this.mood,
    this.posture,
    this.sequence = const [],
    this.isAgentTurn,
  });
  @override
  State<PocoAnimator> createState() => _PocoAnimatorState();
}

class _PocoAnimatorState extends State<PocoAnimator> {
  late String _currentFace;
  Timer? _timer;
  int _currentIndex = 0;
  final _random = Random();
  final _faceKey = GlobalKey();

  bool get _isTurnDriven => widget.isAgentTurn != null;
  bool get _isRandomIdle => !_isTurnDriven && widget.sequence.isEmpty;

  @override
  void initState() {
    super.initState();
    if (_isTurnDriven) {
      _currentFace = widget.isAgentTurn!
          ? PocoExpression.thinking
          : _randomGreenHappyFace();
    } else if (_isRandomIdle) {
      _currentFace = _randomGreenHappyFace();
    } else {
      _currentFace = widget.sequence[0].$1;
    }
    if (!_isTurnDriven) _scheduleNextFrame();
  }

  @override
  void didUpdateWidget(covariant PocoAnimator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isTurnDriven && widget.isAgentTurn != oldWidget.isAgentTurn) {
      _timer?.cancel();
      setState(() {
        _currentFace = widget.isAgentTurn!
            ? PocoExpression.thinking
            : _randomGreenHappyFace();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _randomGreenHappyFace() => PocoExpression
      .greenHappy[_random.nextInt(PocoExpression.greenHappy.length)];

  void _scheduleNextFrame() {
    final delay = _isRandomIdle
        ? _idleFrameDuration
        : Duration(milliseconds: widget.sequence[_currentIndex].$2);
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

  /// Mood travels with the glyph since `lookUp`'s glyph collides with `happy`.
  (String, PocoMood)? _gazeLookFor(Offset? tapPosition) {
    if (tapPosition == null) return null;
    final box = _faceKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final center = box.localToGlobal(box.size.center(Offset.zero));
    final dx = tapPosition.dx - center.dx;
    final dy = tapPosition.dy - center.dy;
    if (dx.abs() < _gazeThreshold && dy.abs() < _gazeThreshold) {
      return (PocoExpression.awake, PocoMood.awake);
    }
    if (dx.abs() >= dy.abs()) {
      return dx > 0
          ? (PocoExpression.lookRight, PocoMood.lookRight)
          : (PocoExpression.lookLeft, PocoMood.lookLeft);
    }
    return dy > 0
        ? (PocoExpression.lookDown, PocoMood.lookDown)
        : (PocoExpression.lookUp, PocoMood.lookUp);
  }

  Widget _buildFace(BuildContext context, Offset? tapPosition) {
    // A tap-look only ever replaces the idle filler face -- it must never
    // hide the "thinking" status or step on a scripted onboarding beat.
    final gazeLook = _isRandomIdle ? _gazeLookFor(tapPosition) : null;
    return AsciiFace(
        key: _faceKey,
        expression: gazeLook?.$1 ?? _currentFace,
        fontSize: widget.fontSize ?? AppSizes.fontPoco,
        color: widget.color,
        mood: widget.mood ??
            gazeLook?.$2 ??
            (_isTurnDriven && widget.isAgentTurn! ? PocoMood.thinking : null),
        posture: widget.posture ?? PocoPostureScope.of(context));
  }

  @override
  Widget build(BuildContext context) {
    final gaze = PocoGazeScope.maybeOf(context);
    if (gaze == null) return _buildFace(context, null);
    return ValueListenableBuilder<Offset?>(
      valueListenable: gaze,
      builder: (context, tapPosition, _) => _buildFace(context, tapPosition),
    );
  }
}
