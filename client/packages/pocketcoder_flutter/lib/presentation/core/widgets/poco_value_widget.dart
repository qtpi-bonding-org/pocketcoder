import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'poco_bubble.dart';
import 'package:pocketcoder_flutter/design_system/primitives/poco.dart';

/// A Cubit-free Poco renderer for adapters, previews, and Widgetbook.
class PocoValueWidget extends StatelessWidget {
  const PocoValueWidget({
    super.key,
    required this.message,
    required this.sequence,
    required this.history,
    this.pocoSize,
    this.textAlign = TextAlign.start,
    required this.posture,
    this.mood,
  });

  final ValueListenable<String> message;
  final ValueListenable<List<(String, int)>> sequence;
  final ValueListenable<List<String>> history;
  final double? pocoSize;
  final TextAlign textAlign;
  final PocoPosture posture;
  final PocoMood? mood;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: message,
      builder: (context, message, _) =>
          ValueListenableBuilder<List<(String, int)>>(
        valueListenable: sequence,
        builder: (context, sequence, _) => ValueListenableBuilder<List<String>>(
          valueListenable: history,
          builder: (context, history, _) => PocoBubble(
            message: message,
            sequence: sequence,
            history: history,
            pocoSize: pocoSize,
            textAlign: textAlign,
            posture: posture,
            mood: mood,
          ),
        ),
      ),
    );
  }
}
