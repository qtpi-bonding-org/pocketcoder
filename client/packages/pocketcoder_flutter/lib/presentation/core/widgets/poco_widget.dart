import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'poco_bubble.dart';

/// Dumb presentation widget for Poco. State orchestration belongs to callers.
class PocoWidget extends StatelessWidget {
  const PocoWidget({
    super.key,
    required this.message,
    this.sequence = const <(String, int)>[],
    this.history = const <String>[],
    this.pocoSize,
    this.textAlign = TextAlign.start,
  });

  final ValueListenable<String> message;
  final List<(String, int)> sequence;
  final List<String> history;
  final double? pocoSize;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: message,
      builder: (context, message, _) => _build(context, message),
    );
  }

  Widget _build(BuildContext context, String message) {
    return PocoBubble(
      message: message,
      sequence: sequence,
      history: history,
      pocoSize: pocoSize,
      textAlign: textAlign,
    );
  }
}
