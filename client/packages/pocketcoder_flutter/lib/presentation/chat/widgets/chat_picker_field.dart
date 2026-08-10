import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
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
    this.noOptionsLabel,
  });

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
          child: TerminalText.tiny(label.toUpperCase(),
              color: context.colorScheme.onSurface),
        ),
        VSpace.x1,
        InkWell(
          onTap: () => _openPicker(context),
          borderRadius: BorderRadius.zero,
          child: Container(
            padding: EdgeInsets.all(AppSizes.space),
            decoration: BoxDecoration(
              border: Border.all(
                color: context.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: TerminalText(
                    currentLabel,
                    color: context.colorScheme.onSurface,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.arrow_drop_down,
                    color: context.colorScheme.onSurface),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final picked = await showDialog<T>(
      context: context,
      builder: (dialogContext) => TerminalDialog(
        title: dialogTitle,
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: options.isEmpty
              ? Center(
                  child: TerminalText(
                    noOptionsLabel ?? emptyLabel,
                    alpha: 0.5,
                  ),
                )
              : ListView(
                  children: [
                    for (final option in options)
                      InkWell(
                        onTap: () => Navigator.of(dialogContext).pop(option),
                        child: Padding(
                          padding: EdgeInsets.all(AppSizes.space),
                          child: TerminalText(optionLabel(option)),
                        ),
                      ),
                  ],
                ),
        ),
        actions: [
          TerminalButton(
            label: context.l10n.newChatCancel,
            isPrimary: false,
            onTap: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );

    if (picked != null) {
      onSelected(picked);
    }
  }
}
