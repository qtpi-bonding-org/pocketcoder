import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/app_sizes.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

Future<T?> showTerminalListPicker<T>({
  required BuildContext context,
  required String title,
  required List<T> items,
  required Widget Function(BuildContext, T) itemBuilder,
  T? selected,
  String? emptyLabel,
  double? height,
  String? cancelLabel,
}) {
  assert(selected == null || items.contains(selected));
  return showDialog<T>(
    context: context,
    builder: (dialogContext) => TerminalDialog(
      title: title,
      content: SizedBox(
        width: double.maxFinite,
        height: height ?? AppSizes.pickerHeight,
        child: items.isEmpty
            ? Center(child: TerminalText(emptyLabel ?? '', alpha: 0.5))
            : ListView(
                children: [
                  for (final item in items)
                    InkWell(
                      onTap: () => Navigator.of(dialogContext).pop(item),
                      child: itemBuilder(dialogContext, item),
                    ),
                ],
              ),
      ),
      actions: cancelLabel == null
          ? const []
          : [
              TerminalButton(
                label: cancelLabel,
                isPrimary: false,
                onTap: () => Navigator.of(dialogContext).pop(),
              ),
            ],
    ),
  );
}
