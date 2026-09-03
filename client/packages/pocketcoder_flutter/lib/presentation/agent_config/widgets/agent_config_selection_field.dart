import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_row.dart';

class AgentConfigSelectionField extends StatelessWidget {
  const AgentConfigSelectionField({
    super.key,
    required this.label,
    required this.currentValue,
    required this.onTap,
  });

  final String label;
  final String currentValue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BiosRow(
      label: label,
      value: currentValue,
      variant: BiosRowVariant.expand,
      onTap: onTap,
    );
  }
}
