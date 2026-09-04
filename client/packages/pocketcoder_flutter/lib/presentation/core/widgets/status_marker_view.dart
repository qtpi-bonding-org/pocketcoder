import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/status_marker.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';

class StatusMarkerView extends StatelessWidget {
  const StatusMarkerView({super.key, required this.marker});

  final StatusMarker marker;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TerminalText('[', role: TextRole.label),
          TerminalText(marker.word, role: marker.role),
          TerminalText(']', role: TextRole.label),
        ],
      );
}
