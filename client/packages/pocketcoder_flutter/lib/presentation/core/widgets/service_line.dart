import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/spacers.dart';
import 'package:pocketcoder_flutter/design_system/primitives/status_marker.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/status_marker_view.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

class ServiceLine extends StatelessWidget {
  const ServiceLine({
    super.key,
    required this.name,
    this.detail,
    required this.status,
  });

  final String name;
  final String? detail;
  final StatusMarker status;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          HSpace.x1,
          const TerminalText('*', role: TextRole.label),
          HSpace.x1,
          TerminalText(name, role: TextRole.value),
          const Spacer(),
          if (detail != null) ...[
            TerminalText(detail!, role: TextRole.label),
            HSpace.x1,
          ],
          StatusMarkerView(marker: status),
          HSpace.x1,
        ],
      );
}