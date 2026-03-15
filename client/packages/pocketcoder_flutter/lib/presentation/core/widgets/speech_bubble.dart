import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/message.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/thoughts_stream.dart';

class SpeechBubble extends StatefulWidget {
  final Message message;
  final bool isUser;

  const SpeechBubble({
    super.key,
    required this.message,
    this.isUser = false,
  });

  @override
  State<SpeechBubble> createState() => _SpeechBubbleState();
}

class _SpeechBubbleState extends State<SpeechBubble> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    // Default expanded for assistant messages that are still loading/fresh
    // Or we just default to collapsed for a clean look.
    // Let's default to collapsed for existing history,
    // but maybe we can improve this later.
  }

  @override
  Widget build(BuildContext context) {
    final parts = widget.message.parts ?? [];
    if (parts.isEmpty) return const SizedBox.shrink();

    final colors = context.colorScheme;
    final terminalColors = context.terminalColors;

    // Filter text parts for the main display
    final textParts =
        parts.where((p) => p is Map && p['type'] == 'text').toList();

    final hasTrace = parts.any((p) =>
        p is Map &&
        (p['type'] == 'reasoning' ||
            p['type'] == 'tool' ||
            p['type'] == 'file'));

    // For assistant, we often only want the LAST text part as the "Summary"
    // when collapsed, or all text joined.
    final String mainText =
        textParts.map((e) => (e as Map)['text'] ?? '').join('\n');

    if (mainText.trim().isEmpty && !widget.isUser && !_isExpanded) {
      // If it's just thinking and we're collapsed, show a placeholder if there's a trace
      if (hasTrace) {
        return _buildThinkingPlaceholder(context);
      }
      return const SizedBox.shrink();
    }

    // Dynamic Label
    final String label = widget.isUser ? 'COMMANDER' : 'POCO';
    final Color accentColor =
        widget.isUser ? terminalColors.user : colors.onSurface;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSizes.space * 2),
      decoration: BoxDecoration(
        color: widget.isUser
            ? terminalColors.user.withValues(alpha: 0.05)
            : colors.surface,
        border: Border(
          top: BorderSide(
            color: colors.onSurface.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                widget.isUser ? Icons.person_outline : Icons.smart_toy_outlined,
                size: 16,
                color: accentColor,
              ),
              HSpace.x1,
              Text(
                label,
                style: TextStyle(
                  color: accentColor,
                  fontSize: AppSizes.fontTiny,
                  letterSpacing: 2,
                  fontWeight: AppFonts.heavy,
                ),
              ),
              const Spacer(),
              if (!widget.isUser && hasTrace)
                GestureDetector(
                  onTap: () => setState(() => _isExpanded = !_isExpanded),
                  child: TerminalText(
                    _isExpanded ? '[-] TRACE' : '[+] TRACE',
                    size: TerminalTextSize.tiny,
                    weight: TerminalTextWeight.heavy,
                    color: colors.secondary,
                    alpha: 0.6,
                  ),
                ),
            ],
          ),
          VSpace.x1,
          if (_isExpanded && !widget.isUser) ...[
            // The "Details" view
            Container(
              margin: EdgeInsets.symmetric(vertical: AppSizes.space),
              padding: EdgeInsets.all(AppSizes.space),
              decoration: BoxDecoration(
                color: colors.onSurface.withValues(alpha: 0.02),
                border:
                    Border.all(color: colors.onSurface.withValues(alpha: 0.05)),
              ),
              // We use a Column of ThoughtsStream fragments or a simplified ThoughtsStream
              child: _buildExpandedContent(context, parts),
            ),
          ] else ...[
            // The "Main Text" view
            TerminalText(
              mainText,
              size: TerminalTextSize.base,
              color: widget.isUser ? accentColor : colors.onSurface,
              height: 1.4,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThinkingPlaceholder(BuildContext context) {
    final colors = context.colorScheme;
    return InkWell(
      onTap: () => setState(() => _isExpanded = true),
      child: Padding(
        padding: EdgeInsets.all(AppSizes.space * 2),
        child: Text(
          '[ POCO IS THINKING... CLICK TO EXPAND ]',
          style: TextStyle(
            color: colors.secondary.withValues(alpha: 0.5),
            fontSize: AppSizes.fontTiny,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedContent(BuildContext context, List<dynamic> parts) {
    // We basically reimplement the ThoughtsStream switch logic here
    // but optimized for an in-chat view.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: parts.map((part) {
        if (part is! Map<String, dynamic>) return const SizedBox.shrink();

        // We reuse the look of ThoughtsStream
        // Note: For 'text' parts in Expanded view, we might want to show them too.
        return ThoughtsStreamContent(part: part);
      }).toList(),
    );
  }
}
