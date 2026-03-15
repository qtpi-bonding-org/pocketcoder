import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/question.dart';
import 'terminal_button.dart';
import 'terminal_input.dart';

class QuestionPrompt extends StatefulWidget {
  final Question question;
  final Function(String reply) onAnswer;
  final VoidCallback onReject;

  const QuestionPrompt({
    super.key,
    required this.question,
    required this.onAnswer,
    required this.onReject,
  });

  @override
  State<QuestionPrompt> createState() => _QuestionPromptState();
}

class _QuestionPromptState extends State<QuestionPrompt> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final terminalColors = context.terminalColors;

    // Handle choices
    List<String> choices = [];
    if (widget.question.choices is List) {
      choices =
          (widget.question.choices as List).map((e) => e.toString()).toList();
    }

    return Container(
      margin: EdgeInsets.all(AppSizes.space),
      padding: EdgeInsets.all(AppSizes.space * 2),
      decoration: BoxDecoration(
        color: terminalColors.attention.withValues(alpha: 0.05),
        border: Border.all(
          color: terminalColors.attention.withValues(alpha: 0.3),
          width: AppSizes.borderWidth,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.help_outline,
                color: terminalColors.attention,
                size: 20,
              ),
              HSpace.x2,
              Expanded(
                child: Text(
                  context.l10n.questionIncomingTitle,
                  style: TextStyle(
                    color: terminalColors.attention,
                    fontSize: AppSizes.fontTiny,
                    fontWeight: AppFonts.heavy,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ],
          ),
          VSpace.x2,
          Text(
            context.l10n.questionPocoAsking,
            style: TextStyle(
              color: terminalColors.attention.withValues(alpha: 0.8),
              fontSize: AppSizes.fontMini,
              fontWeight: AppFonts.heavy,
            ),
          ),
          VSpace.x1,
          Text(
            widget.question.question,
            style: TextStyle(
              color: terminalColors.attention,
              fontFamily: AppFonts.bodyFamily,
              fontSize: AppSizes.fontStandard,
            ),
          ),
          VSpace.x3,
          if (choices.isNotEmpty) ...[
            Wrap(
              spacing: AppSizes.space,
              runSpacing: AppSizes.space,
              children: choices
                  .map((choice) => TerminalButton(
                        label: choice.toUpperCase(),
                        onTap: () => widget.onAnswer(choice),
                      ))
                  .toList(),
            ),
          ] else ...[
            TerminalInput(
              controller: _controller,
              onSubmitted: () => widget.onAnswer(_controller.text),
              prompt: '>',
            ),
          ],
          VSpace.x3,
          Row(
            children: [
              Expanded(
                child: TerminalButton(
                  label: 'REJECT',
                  isPrimary: false,
                  color: terminalColors.danger,
                  onTap: widget.onReject,
                ),
              ),
              if (choices.isEmpty) ...[
                HSpace.x2,
                Expanded(
                  child: TerminalButton(
                    label: context.l10n.questionSendReply,
                    onTap: () => widget.onAnswer(_controller.text),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
