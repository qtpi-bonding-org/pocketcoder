import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/application/system/poco_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_conversation.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/poco_bubble.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

class WalkthroughConversationEntry {
  const WalkthroughConversationEntry({
    required this.speaker,
    required this.message,
    this.sequence = const [],
  });

  final TerminalConversationSpeaker speaker;
  final String message;
  final List<(String, int)> sequence;
}

class WalkthroughFaqPrompt {
  const WalkthroughFaqPrompt({required this.question, required this.answer});

  final String question;
  final String answer;
}

/// The guided, local conversation surface used during server orientation.
///
/// The adapter supplies the entries, snippet, suggestions, and callbacks. It
/// does not know about deployment or agent repositories.
class WalkthroughConversationView extends StatelessWidget {
  const WalkthroughConversationView({
    super.key,
    required this.progressLabel,
    required this.briefTitle,
    required this.entries,
    required this.snippet,
    required this.suggestions,
    required this.onSuggestionSelected,
    this.faqPrompts = const [],
    this.onFaqSelected,
    this.walkthroughBoundary,
    this.showBriefDivider = false,
    this.onPrevious,
    this.onNext,
  });

  final String progressLabel;
  final String briefTitle;
  final List<WalkthroughConversationEntry> entries;
  final Widget snippet;
  final List<String> suggestions;
  final ValueChanged<String> onSuggestionSelected;
  final List<WalkthroughFaqPrompt> faqPrompts;
  final ValueChanged<WalkthroughFaqPrompt>? onFaqSelected;
  final WalkthroughConversationBoundary? walkthroughBoundary;
  final bool showBriefDivider;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSizes.space * 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TerminalText.tiny(progressLabel, alpha: 0.65),
          if (walkthroughBoundary != null) ...[
            VSpace.x3,
            walkthroughBoundary!,
          ],
          if (showBriefDivider) ...[
            VSpace.x3,
            const WalkthroughBriefDivider(),
          ],
          VSpace.x1,
          TerminalText(
            briefTitle.toUpperCase(),
            weight: TerminalTextWeight.heavy,
          ),
          VSpace.x3,
          for (final entry in entries) ...[
            TerminalConversationTurn(
              speaker: entry.speaker,
              message: entry.message,
              sequence: entry.sequence,
            ),
            VSpace.x2,
          ],
          snippet,
          if (suggestions.isNotEmpty || faqPrompts.isNotEmpty) ...[
            VSpace.x3,
            TerminalText.tiny(context.l10n.walkthroughAskPoco, alpha: 0.65),
            VSpace.x1,
            for (final suggestion in suggestions) ...[
              TerminalPromptSuggestion(
                label: suggestion,
                onSelected: () => onSuggestionSelected(suggestion),
              ),
              VSpace.x1,
            ],
            for (final prompt in faqPrompts) ...[
              TerminalPromptSuggestion(
                label: prompt.question,
                onSelected: () => onFaqSelected?.call(prompt),
              ),
              VSpace.x1,
            ],
          ],
          VSpace.x2,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: onPrevious,
                child: Text(context.l10n.pocoProvisioningPrevious),
              ),
              TextButton(
                onPressed: onNext,
                child: Text(context.l10n.pocoProvisioningNext),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Marks the start of a new bounded walkthrough conversation.
class WalkthroughConversationBoundary extends StatelessWidget {
  const WalkthroughConversationBoundary({
    super.key,
    required this.label,
    required this.message,
  });

  final String label;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(
          height: AppSizes.borderWidth,
          color: context.colorScheme.primary.withValues(alpha: 0.35),
        ),
        VSpace.x2,
        TerminalText.label(label.toUpperCase()),
        VSpace.x2,
        PocoBubble(
          message: message,
          sequence: PocoExpressions.thinking,
          pocoSize: AppSizes.fontLarge,
        ),
      ],
    );
  }
}

/// Lightweight terminal separator between briefs in one walkthrough.
class WalkthroughBriefDivider extends StatelessWidget {
  const WalkthroughBriefDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            height: AppSizes.borderWidth,
            color: context.colorScheme.primary.withValues(alpha: 0.2),
          ),
        ),
        HSpace.x2,
        TerminalText.tiny(
          context.l10n.walkthroughBriefDivider,
          alpha: 0.55,
        ),
        HSpace.x2,
        Expanded(
          child: Divider(
            height: AppSizes.borderWidth,
            color: context.colorScheme.primary.withValues(alpha: 0.2),
          ),
        ),
      ],
    );
  }
}
