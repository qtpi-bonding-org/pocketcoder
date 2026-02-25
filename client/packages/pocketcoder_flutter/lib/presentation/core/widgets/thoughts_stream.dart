import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

class ThoughtsStream extends StatelessWidget {
  final List<dynamic> parts;

  const ThoughtsStream({super.key, required this.parts});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    if (parts.isEmpty) {
      return Center(
        child: Text(
          '[NEURAL LINK ACTIVE. WAITING FOR THOUGHTS...]',
          style: TextStyle(
            color: colors.onSurface.withValues(alpha: 0.3),
            fontFamily: AppFonts.bodyFamily,
            fontSize: AppSizes.fontTiny,
          ),
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
        return Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Text(
            '> ${part['text'] ?? ""}',
            style: TextStyle(
              color: colors.onSurface.withValues(alpha: 0.6),
              fontFamily: AppFonts.headerFamily,
              fontSize: 10,
            ),
          ),
        );
      case 'reasoning':
        return Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Text(
            'THOUGHT: ${part['text'] ?? ""}',
            style: TextStyle(
              color: colors.onSurface.withValues(alpha: 0.4),
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

        return Container(
          margin: const EdgeInsets.only(bottom: 8.0, top: 4.0),
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.3),
            border: Border(
                left: BorderSide(
                    color: _getStatusColor(context, status), width: 2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'EXEC: ${toolName.toUpperCase()}',
                    style: TextStyle(
                      color: _getStatusColor(context, status),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildToolStatus(context, status),
                ],
              ),
              _buildToolPayload(context, state),
            ],
          ),
        );
      case 'file':
        return Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Text(
            'FILE [${part['mime']}]: ${part['filename'] ?? part['url']}',
            style: TextStyle(color: colors.secondary, fontSize: 10),
          ),
        );
      case 'step-start':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Divider(
              color: colors.onSurface.withValues(alpha: 0.1), height: 1),
        );
      case 'step-finish':
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            'STEP COMPLETE (${part['reason']})',
            style: TextStyle(
              color: colors.onSurface.withValues(alpha: 0.4),
              fontSize: 9,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      default:
        // Handle unrecognized types by showing raw JSON summary
        return Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Text(
            'PROTOCOL: ${part.keys.take(3).join(', ')}...',
            style: TextStyle(
              color: colors.onSurface.withValues(alpha: 0.2),
              fontSize: 8,
            ),
          ),
        );
    }
  }

  Color _getStatusColor(BuildContext context, String status) {
    final colors = context.colorScheme;
    final terminalColors = context.terminalColors;
    switch (status) {
      case 'pending':
        return colors.onSurface.withValues(alpha: 0.3);
      case 'running':
        return colors.secondary; // Phosphor Green
      case 'completed':
        return colors.primary; // Vivid Green
      case 'error':
        return terminalColors.danger; // Danger Red
      default:
        return colors.onSurface.withValues(alpha: 0.3);
    }
  }

  Widget _buildToolStatus(BuildContext context, String status) {
    String label = '[$status]'.toUpperCase();
    if (status == 'running') label = '[RUNNING...]';

    return Text(
      label,
      style: TextStyle(
        color: _getStatusColor(context, status),
        fontSize: 8,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildToolPayload(BuildContext context, Map<String, dynamic> state) {
    final colors = context.colorScheme;
    final status = state['status'] as String?;
    final input = (state['input'] as Map<String, dynamic>?) ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _jsonText(context, input),
        if (status == 'completed' && state.containsKey('output')) ...[
          Divider(height: 8, color: colors.onSurface.withValues(alpha: 0.1)),
          Text(
            state['output'].toString(),
            style: TextStyle(
                color: colors.secondary, fontSize: 10), // Phosphor Green
            maxLines: 15,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (status == 'error' && state.containsKey('error')) ...[
          Divider(height: 8, color: colors.onSurface.withValues(alpha: 0.1)),
          Text(
            state['error'].toString(),
            style: TextStyle(color: colors.error, fontSize: 10),
          ),
        ],
      ],
    );
  }

  Widget _jsonText(BuildContext context, Map<String, dynamic> json) {
    final colors = context.colorScheme;
    return Text(
      json.toString(),
      style: TextStyle(
        color: colors.onSurface.withValues(alpha: 0.8),
        fontSize: 9,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
