import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/searchable_picker_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

/// Shared picker field used for chat creation choices.
class ChatPickerField<T> extends StatelessWidget {
  const ChatPickerField(
      {super.key,
      required this.label,
      required this.dialogTitle,
      required this.emptyLabel,
      required this.options,
      required this.selected,
      required this.optionLabel,
      required this.onSelected,
      this.noOptionsLabel,
      this.groupLabel});

  final String label;
  final String dialogTitle;
  final String emptyLabel;
  final String? noOptionsLabel;
  final List<T> options;
  final T? selected;
  final String Function(T) optionLabel;
  final String Function(T)? groupLabel;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final selectedValue = selected;
    final currentLabel =
        selectedValue == null ? emptyLabel : optionLabel(selectedValue);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Semantics(
        label: label,
        child: TerminalText(label, role: TextRole.label),
      ),
      VSpace.x1,
      InkWell(
          onTap: () => _openPicker(context),
          borderRadius: BorderRadius.zero,
          child: Container(
              padding: EdgeInsets.all(AppSizes.space),
              decoration: BoxDecoration(
                  border: Border.all(
                      color: context.colorScheme.onSurface
                          .withValues(alpha: 0.3))),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                        child: TerminalText(currentLabel,
                            role: TextRole.body,
                            overflow: TextOverflow.ellipsis)),
                    Text(context.l10n.chatPickerFieldIndicator,
                        style: TextStyle(color: context.colorScheme.onSurface)),
                  ]))),
    ]);
  }

  Future<void> _openPicker(BuildContext context) async {
    final picked = await showDialog<T>(
      context: context,
      builder: (_) => SearchablePickerDialog<T>(
        title: dialogTitle,
        items: options,
        itemLabel: optionLabel,
        groupLabel: groupLabel,
        selectedItem: selected,
        searchLabel: context.l10n.chatPickerSearchLabel,
        searchHint: context.l10n.chatPickerSearchHint,
        emptyLabel: noOptionsLabel ?? emptyLabel,
        noMatchesLabel: context.l10n.chatPickerNoMatches,
        itemBuilder: (_, option, {required isSelected, required onTap}) =>
            InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(AppSizes.space),
            child: TerminalText(optionLabel(option), role: TextRole.body),
          ),
        ),
      ),
    );

    if (picked != null) {
      onSelected(picked);
    }
  }
}
