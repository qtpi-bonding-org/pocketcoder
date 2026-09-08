import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'decision_frame.dart';
import 'grid_wrap.dart';

class TerminalDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget> actions;

  const TerminalDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.all(AppSizes.space * 2),
      child: DecisionFrame(
        title: title,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(AppSizes.space * 2),
                child: content,
              ),
            ),
            VSpace.x2,
            Padding(
              padding: EdgeInsets.all(AppSizes.space * 2),
              child: GridWrap(
                alignment: WrapAlignment.end,
                spacing: AppSizes.space * 2,
                runSpacing: AppSizes.space,
                children: actions,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
