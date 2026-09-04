import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/detail_row.dart';
import 'package:pocketcoder_flutter/design_system/primitives/row_affordance.dart';

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
    return DetailRow(
      label: label,
      value: currentValue,
      affordance: RowAffordance.expand,
      onTap: onTap,
    );
  }
}
