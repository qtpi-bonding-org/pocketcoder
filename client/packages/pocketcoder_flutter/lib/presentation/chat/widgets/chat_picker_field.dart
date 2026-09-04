import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_list_picker_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

/// Shared picker field used for chat creation choices.
class ChatPickerField<T> extends StatelessWidget {
  const ChatPickerField({
    super.key,
    required this.label,
    required this.dialogTitle,
    required this.emptyLabel,
    required this.options,
    required this.selected,
    required this.optionLabel,
    required this.onSelected,
    this.noOptionsLabel});

  final String label;
  final String dialogTitle;
  final String emptyLabel;
  final String? noOptionsLabel;
  final List<T> options;
  final T? selected;
  final String Function(T) optionLabel;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final selectedValue = selected;
    final currentLabel =
        selectedValue == null ? emptyLabel : optionLabel(selectedValue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: label,
          child: TerminalText(label.toUpperCase(), role: TextRole.label),
        ),
        VSpace.x1,
        InkWell(
          onTap: () => _openPicker(context),
          borderRadius: BorderRadius.zero,
          child: Container(
            padding: EdgeInsets.all(AppSizes.space),
            decoration: BoxDecoration(
              border: Border.all(
                color: context.colorScheme.onSurface.withValues(alpha: 0.3))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: TerminalText(
                    currentLabel,
                    role: TextRole.body,
                    overflow: TextOverflow.ellipsis)),
                Text(context.l10n.chatPickerFieldIndicator,
                    style: TextStyle(color: context.colorScheme.onSurface)),
              ]))),
      ]);
  }

  Future<void> _openPicker(BuildContext context) async {
    final picked = await showTerminalListPicker<T>(
      context: context,
      title: dialogTitle,
      items: options,
      emptyLabel: noOptionsLabel ?? emptyLabel,
      cancelLabel: context.l10n.newChatCancel,
      itemBuilder: (_, option) => Padding(
        padding: EdgeInsets.all(AppSizes.space),
        child: TerminalText(optionLabel(option), role: TextRole.body)),
    );

    if (picked != null) {
      onSelected(picked);
    }
  }
}
