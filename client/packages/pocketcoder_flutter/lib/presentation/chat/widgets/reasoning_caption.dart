import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/chat/thinking_block.dart';

class ReasoningCaption extends StatelessWidget {
  const ReasoningCaption({
    super.key,
    required this.text,
    required this.isStreaming,
  });

  final String text;
  final bool isStreaming;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(
          left: AppSizes.space,
          right: AppSizes.space,
          top: AppSizes.space * 0.5,
        ),
        child: ThinkingBlock(
          text: text,
          isStreaming: isStreaming,
        ),
      );
}
