import 'package:flutter/material.dart';
import '../../../design_system/theme/app_theme.dart';
import '../../../domain/chat/chat_message.dart';

class ThoughtsStream extends StatelessWidget {
  final List<MessagePart> parts;

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
        return _buildPart(context, part);
      },
    );
  }

  Widget _buildPart(BuildContext context, MessagePart part) {
    final colors = context.colorScheme;
    return part.map(
      text: (textPart) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Text(
            '> ${textPart.text ?? ""}',
            style: TextStyle(
              color: colors.onSurface.withValues(alpha: 0.6),
              fontFamily: AppFonts.headerFamily,
              fontSize: 10,
            ),
          ),
        );
      },
      reasoning: (reasoningPart) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Text(
            'THOUGHT: ${reasoningPart.text ?? ""}',
            style: TextStyle(
              color: colors.onSurface.withValues(alpha: 0.4),
              fontFamily: AppFonts.bodyFamily,
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      },
      tool: (toolPart) {
        final state = toolPart.state;
        return Container(
          margin: const EdgeInsets.only(bottom: 8.0, top: 4.0),
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.3),
            border: Border(
                left:
                    BorderSide(color: _getToolColor(context, state), width: 2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'EXEC: ${toolPart.tool.toUpperCase()}',
                    style: TextStyle(
                      color: _getToolColor(context, state),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildToolStatus(context, state),
                ],
              ),
              _buildToolPayload(context, state),
            ],
          ),
        );
      },
      file: (filePart) => Padding(
        padding: const EdgeInsets.only(bottom: 4.0),
        child: Text(
          'FILE [${filePart.mime}]: ${filePart.filename ?? filePart.url}',
          style: TextStyle(color: colors.secondary, fontSize: 10),
        ),
      ),
      stepStart: (startPart) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child:
            Divider(color: colors.onSurface.withValues(alpha: 0.1), height: 1),
      ),
      stepFinish: (finishPart) => Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Text(
          'STEP COMPLETE (${finishPart.reason})',
          style: TextStyle(
            color: colors.onSurface.withValues(alpha: 0.4),
            fontSize: 9,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  Color _getToolColor(BuildContext context, ToolState state) {
    final colors = context.colorScheme;
    final terminalColors = context.terminalColors;
    return state.map(
      pending: (_) => colors.onSurface.withValues(alpha: 0.3),
      running: (_) => colors.secondary, // Phosphor Green
      completed: (_) => colors.primary, // Vivid Green
      error: (_) => terminalColors.danger, // Danger Red
    );
  }

  Widget _buildToolStatus(BuildContext context, ToolState state) {
    String label = state.map(
      pending: (_) => '[PENDING]',
      running: (_) => '[RUNNING...]',
      completed: (_) => '[FINISHED]',
      error: (_) => '[FAILED]',
    );
    return Text(
      label,
      style: TextStyle(
        color: _getToolColor(context, state),
        fontSize: 8,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildToolPayload(BuildContext context, ToolState state) {
    final colors = context.colorScheme;
    return state.map(
      pending: (s) => _jsonText(context, s.input),
      running: (s) => _jsonText(context, s.input),
      completed: (s) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _jsonText(context, s.input),
          Divider(height: 8, color: colors.onSurface.withValues(alpha: 0.1)),
          Text(
            s.output,
            style: TextStyle(
                color: colors.secondary, fontSize: 10), // Phosphor Green
            maxLines: 15,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      error: (s) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _jsonText(context, s.input),
          Divider(height: 8, color: colors.onSurface.withValues(alpha: 0.1)),
          Text(
            s.error,
            style: TextStyle(color: colors.error, fontSize: 10),
          ),
        ],
      ),
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
