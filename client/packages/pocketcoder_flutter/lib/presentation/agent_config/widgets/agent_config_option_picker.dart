import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/agent_config/widgets/agent_config_selection_field.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_list_picker_dialog.dart';

class AgentConfigOptionPicker<T> extends StatelessWidget {
  const AgentConfigOptionPicker({
    super.key,
    required this.items,
    required this.selectedId,
    required this.label,
    required this.selectTitle,
    required this.emptyLabel,
    required this.itemId,
    required this.itemLabel,
    required this.itemBuilder,
    required this.onSelected,
  });

  final List<T> items;
  final String? selectedId;
  final String label;
  final String selectTitle;
  final String emptyLabel;
  final String Function(T item) itemId;
  final String Function(T item) itemLabel;
  final Widget Function(BuildContext context, T item, T? selected) itemBuilder;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final selected =
        items.where((item) => itemId(item) == selectedId).firstOrNull;
    return AgentConfigSelectionField(
      label: label,
      currentValue: selected == null
          ? selectTitle.toUpperCase()
          : itemLabel(selected).toUpperCase(),
      onTap: () async {
        final picked = await showTerminalListPicker<T>(
          context: context,
          title: selectTitle,
          emptyLabel: emptyLabel,
          items: items,
          selected: selected,
          cancelLabel: context.l10n.actionCancel,
          itemBuilder: (context, item) => itemBuilder(context, item, selected),
        );
        if (picked != null) onSelected(itemId(picked));
      },
    );
  }
}
