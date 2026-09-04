import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/server_control/widgets/copy_button.dart';

class DetailRow extends StatelessWidget {
  const DetailRow(
      {super.key, required this.label, required this.value, this.action});

  final String label;
  final String value;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: AppSizes.space),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text('$label\n$value')),
            action ?? CopyButton(value: value),
          ],
        ),
      );
}
