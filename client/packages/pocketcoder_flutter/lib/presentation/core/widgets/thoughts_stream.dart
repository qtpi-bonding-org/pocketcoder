import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

class ThoughtsStream extends StatelessWidget {
  final List<dynamic> parts;

  const ThoughtsStream({super.key, required this.parts});

  @override
  Widget build(BuildContext context) {
    if (parts.isEmpty) {
      return Center(
        child: TerminalText.tiny(
          '[NEURAL LINK ACTIVE. WAITING FOR THOUGHTS...]',
          alpha: 0.3,
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(AppSizes.space),
      itemCount: parts.length,
      reverse: true, // Auto-scroll to bottom of thoughts
      itemBuilder: (context, index) {
        // Reverse index for 'reverse: true'
        final part = parts[parts.length - 1 - index];
        if (part is! Map<String, dynamic>) return const SizedBox.shrink();
        return _buildPart(context, part);
      },
    );
  }

  Widget _buildPart(BuildContext context, Map<String, dynamic> part) {
    final colors = context.colorScheme;
    final type = part['type'] as String?;

    switch (type) {
      case 'text':
        // Full stream view uses '> ' prefix and header font
        return Padding(
          padding: EdgeInsets.only(bottom: AppSizes.space * 0.5),
          child: Text(
            '> ${part['text'] ?? ""}',
            style: TextStyle(
              color: colors.secondary,
              fontFamily: AppFonts.headerFamily,
              fontSize: AppSizes.fontTiny,
            ),
          ),
        );
      case 'reasoning':
      case 'tool':
        return ThoughtsStreamContent(part: part);
      case 'file':
        return Padding(
          padding: EdgeInsets.only(bottom: AppSizes.space * 0.5),
          child: Text(
            'FILE [${part['mime']}]: ${part['filename'] ?? part['url']}',
            style: TextStyle(
                color: colors.secondary, fontSize: AppSizes.fontTiny),
          ),
        );
      case 'step-start':
        return Padding(
          padding: EdgeInsets.symmetric(vertical: AppSizes.space * 0.5),
          child: Divider(
              color: colors.onSurface.withValues(alpha: 0.1), height: 1),
        );
      case 'step-finish':
        return Padding(
          padding: EdgeInsets.only(bottom: AppSizes.space),
          child: Text(
            'STEP COMPLETE (${part['reason']})',
            style: TextStyle(
              color: colors.secondary.withValues(alpha: 0.5),
              fontSize: AppSizes.fontTiny,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      default:
        // Handle unrecognized types by showing raw JSON summary
        return Padding(
          padding: EdgeInsets.only(bottom: AppSizes.space * 0.5),
          child: Text(
            'PROTOCOL: ${part.keys.take(3).join(', ')}...',
            style: TextStyle(
              color: colors.onSurface.withValues(alpha: 0.2),
              fontSize: AppSizes.fontTiny,
            ),
          ),
        );
    }
  }
}

/// Shared widget for rendering individual thought-stream parts (reasoning, tool, text).
/// Used by both [ThoughtsStream] (full stream view) and [SpeechBubble] (in-chat expanded view).
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
          padding: EdgeInsets.only(bottom: AppSizes.space * 0.5),
          child: TerminalText(
            part['text'] ?? "",
            size: TerminalTextSize.base,
          ),
        );
      case 'reasoning':
        return Padding(
          padding: EdgeInsets.only(bottom: AppSizes.space * 0.5),
          child: TerminalText.tiny(
            'THOUGHT: ${part['text'] ?? ""}',
            color: colors.secondary,
            alpha: 0.7,
            fontStyle: FontStyle.italic,
          ),
        );
      case 'tool':
        final toolName = (part['tool'] as String?) ?? 'unknown';
        final state = (part['state'] as Map<String, dynamic>?) ?? {};
        final status = (state['status'] as String?) ?? 'pending';
        final statusColor = getStatusColor(context, status);

        return Container(
          margin: EdgeInsets.only(
              bottom: AppSizes.space, top: AppSizes.space * 0.5),
          padding: EdgeInsets.all(AppSizes.space),
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
                      fontWeight: AppFonts.heavy,
                      fontSize: AppSizes.fontTiny,
                    ),
                  ),
                  HSpace.x1,
                  Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: AppSizes.fontTiny,
                      fontWeight: AppFonts.heavy,
                    ),
                  ),
                ],
              ),
              buildToolPayload(context, state),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  /// Returns a color for the given tool execution status.
  static Color getStatusColor(BuildContext context, String status) {
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

  /// Builds the tool input/output payload display.
  static Widget buildToolPayload(
      BuildContext context, Map<String, dynamic> state) {
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
            fontSize: AppSizes.fontTiny,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (status == 'completed' && state.containsKey('output')) ...[
          Divider(
              height: AppSizes.space,
              color: colors.onSurface.withValues(alpha: 0.1)),
          Text(
            state['output'].toString(),
            style: TextStyle(
                color: colors.secondary, fontSize: AppSizes.fontTiny),
            maxLines: 15,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (status == 'error' && state.containsKey('error')) ...[
          Divider(
              height: AppSizes.space,
              color: colors.onSurface.withValues(alpha: 0.1)),
          Text(
            state['error'].toString(),
            style: TextStyle(color: colors.error, fontSize: AppSizes.fontTiny),
          ),
        ],
      ],
    );
  }
}
