import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/message.dart';

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
    final String label = widget.isUser ? 'USER' : 'POCO';
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
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (!widget.isUser && hasTrace)
                GestureDetector(
                  onTap: () => setState(() => _isExpanded = !_isExpanded),
                  child: Text(
                    _isExpanded ? '[-] TRACE' : '[+] TRACE',
                    style: TextStyle(
                      color: colors.secondary.withValues(alpha: 0.6),
                      fontSize: 9,
                      fontFamily: AppFonts.bodyFamily,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          VSpace.x1,
          if (_isExpanded && !widget.isUser) ...[
            // The "Details" view
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              padding: const EdgeInsets.all(8.0),
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
            Text(
              mainText,
              style: TextStyle(
                color: widget.isUser ? accentColor : colors.onSurface,
                fontFamily: AppFonts.bodyFamily,
                fontSize: AppSizes.fontStandard,
                height: 1.4,
              ),
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
            fontSize: 10,
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

/// A version of _buildPart from ThoughtsStream exposed for reuse
class ThoughtsStreamContent extends StatelessWidget {
  final Map<String, dynamic> part;

  const ThoughtsStreamContent({super.key, required this.part});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final type = part['type'] as String?;

    switch (type) {
      case 'text':
        return Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Text(
            part['text'] ?? "",
            style: TextStyle(
              color: colors.onSurface,
              fontFamily: AppFonts.bodyFamily,
              fontSize: AppSizes.fontStandard,
              height: 1.4,
            ),
          ),
        );
      case 'reasoning':
        return Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Text(
            'THOUGHT: ${part['text'] ?? ""}',
            style: TextStyle(
              color: colors.secondary.withValues(alpha: 0.7),
              fontFamily: AppFonts.bodyFamily,
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      case 'tool':
        final toolName = (part['tool'] as String?) ?? 'unknown';
        final state = (part['state'] as Map<String, dynamic>?) ?? {};
        final status = (state['status'] as String?) ?? 'pending';
        final statusColor = _getStatusColor(context, status);

        return Container(
          margin: const EdgeInsets.only(bottom: 8.0, top: 4.0),
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.3),
            border: Border(left: BorderSide(color: statusColor, width: 2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'EXEC: ${toolName.toUpperCase()}',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              _buildToolPayload(context, state),
            ],
          ),
        );
      // Add other types as needed
      default:
        return const SizedBox.shrink();
    }
  }

  Color _getStatusColor(BuildContext context, String status) {
    final colors = context.colorScheme;
    final terminalColors = context.terminalColors;
    switch (status) {
      case 'pending':
        return colors.secondary.withValues(alpha: 0.5);
      case 'running':
        return colors.secondary;
      case 'completed':
        return colors.primary;
      case 'error':
        return terminalColors.danger;
      default:
        return colors.onSurface.withValues(alpha: 0.3);
    }
  }

  Widget _buildToolPayload(BuildContext context, Map<String, dynamic> state) {
    final colors = context.colorScheme;
    final status = state['status'] as String?;
    final input = (state['input'] as Map<String, dynamic>?) ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          input.toString(),
          style: TextStyle(
            color: colors.onSurface.withValues(alpha: 0.8),
            fontSize: 9,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (status == 'completed' && state.containsKey('output')) ...[
          Divider(height: 8, color: colors.onSurface.withValues(alpha: 0.1)),
          Text(
            state['output'].toString(),
            style: TextStyle(color: colors.secondary, fontSize: 10),
            maxLines: 15,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}
